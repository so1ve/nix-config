"""Render an edit decision list (EDL) to the final video.
Usage: python3 -I $S/render.py <edl.json> <out.mp4> [--draft] [--clips-only]

EDL: {"music": path, "clips": [clip, ...]}; the music fades over the last 0.4 s so a hard end does not click
clip keys (only src, in, start, end are required):
  start, end   output timeline (s); cut frames are round(t * FPS), so every cut lands on its beat
  in, speed    source time at `start` and playback rate; ramp {"at": s after start, "to": rate} switches rate there
  pos_y, zoom  vertical framing of the 2.39 window (0 top .. 1 bottom) and extra zoom (1 = fill)
  look         colour grade (a LOOKS key); every clip also gets the shared finish (glow, vignette, grain)
  punch        zoom that starts at 1 + punch and snaps back over 0.25 s (a hit)
  push         slow zoom over the whole clip: + zooms in to 1 + push, - starts at 1 - push and pulls out
  shake        {"amp": px, "decay": s}: decaying camera shake from the clip start
  impact       {"n": frames, "mode": "negate" | "white" | "mono"}: the first frames as an impact frame
  rgb          {"amp": px, "n": frames}: chromatic split at the clip start that decays over n frames
  freeze       {"at": s after start, "push": z}: the picture holds from `at`, flashes, desaturates and pushes in
  open         seconds for the picture to open from a horizontal slit at the clip start
  flash, flash_out / fade_in, fade_out    fade from / to white / black (s)
Every cut is a hard cut."""
import hashlib, json, os, subprocess, sys
import numpy as np
from concurrent.futures import ThreadPoolExecutor

FPS, W, H, PIC_H = 60, 1920, 1080, 804          # 2.39:1 picture inside 16:9 frame
LOOKS = {                                        # applied after framing, before the shared finish
    "neutral": "",
    "memory": "colorbalance=rs=.06:bs=-.04:rm=.05:bm=-.05:rh=.04:bh=-.06,eq=saturation=.72:contrast=.96",
    "steel": "colorbalance=rs=-.03:bs=.05:rm=-.02:bm=.03,eq=saturation=.9:contrast=1.08",
    "tide": "colorbalance=rs=-.05:gs=.02:bs=.06:rh=-.02:bh=.03,eq=saturation=1.02:contrast=1.06",
    "abyss": "colorbalance=rs=.02:bs=.07:rm=.01:gm=-.03:bm=.05,eq=saturation=1.0:contrast=1.12:gamma=.95",
    "frost": "colorbalance=rs=-.04:bs=.07:rm=-.03:bm=.05:rh=-.02:bh=.04,eq=saturation=.88:contrast=1.08",
    "ink": "colorbalance=rs=.02:bs=-.02:rh=.03:bh=-.03,eq=saturation=.62:contrast=1.14",
    "gold": "colorbalance=rs=.03:gs=.01:bs=-.06:rm=.05:bm=-.06:rh=.06:bh=-.05,eq=saturation=1.04:contrast=1.06",
    "redkey": "colorhold=color=0xc8281e:similarity=0.30:blend=0.20,eq=contrast=1.12:saturation=1.2",   # grey world, reds kept
}
# shared finish: highlight glow (luma only), soft vignette, fine temporal grain
FINISH = ("split[f0][f1];[f1]scale=480:201,lutyuv=y='clip((val-150)*2.4,0,255)',gblur=sigma=6,scale={W}:{PIC_H}[g];"
          "[f0][g]blend=c0_mode=screen:c0_opacity=.32,vignette=angle=.42,"   # chroma: normal mode at opacity 1 keeps [f0]
          "noise=c0s=5:c0f=t").format(W=W, PIC_H=PIC_H)

edl_path, out = sys.argv[1:3]
draft = "--draft" in sys.argv
edl = json.load(open(edl_path))
os.makedirs("build/clips", exist_ok=True)
meta, dbl_cache = {}, {}

def src_meta(src):
    if src not in meta:
        m = json.load(open(f"analysis/shots/{src}.json"))
        cw, ch, cx, cy = m["crop"]
        cw, ch = min(cw, m["width"] - cx), min(ch, m["height"] - cy)
        e = 4                                        # trim a few px of soft letterbox edge
        meta[src] = (m["fps"], (cw - 2 * e, ch - 2 * e, cx + e, cy + e), [x["end"] for x in m["shots"]])
    return meta[src]

def doubled(c):
    """True when clip c's source range is half-rate content with every frame stored twice, as official 60 fps
    uploads of 30 fps CG are; one upload can mix both, so this is measured on the clip's own frames."""
    if src_meta(c["src"])[0] < 50:
        return False
    t0, t1 = c["in"], src_at(c, c["end"])
    if (c["src"], t0, t1) in dbl_cache:
        return dbl_cache[c["src"], t0, t1]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t0:.3f}", "-i", f"src/{c['src']}.mkv", "-t", f"{max(t1 - t0, 0.2):.3f}",
                          "-vf", "scale=160:90,format=gray", "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    f = np.frombuffer(raw, np.uint8)[:len(raw) // 14400 * 14400].reshape(-1, 90, 160).astype(np.int16)
    held = np.abs(np.diff(f, axis=0)).mean(axis=(1, 2)) < 0.3   # the copies are near-identical after re-encoding
    dbl_cache[c["src"], t0, t1] = len(held) > 4 and held.mean() > 0.4
    return dbl_cache[c["src"], t0, t1]

def src_at(c, t):
    """Source time shown at timeline time t."""
    s, r, u = c.get("speed", 1.0), c.get("ramp"), t - c["start"]
    if r and u > r["at"]:
        return c["in"] + s * r["at"] + r["to"] * (u - r["at"])
    return c["in"] + s * u

def frame_chain(c, f0, n):
    """Filters turning clip c's source (seeked to the frame at timeline frame f0) into n framed, graded frames."""
    fps, (cw, ch, cx, cy), ends = src_meta(c["src"])
    # feed only this shot's frames: interpolation and frame-rate conversion read a frame past the clip's last one,
    # which at a shot end would blend in the next shot (the true cut can sit 1/60 s before the detected end)
    feed = ends[c["shot"]] - 1 / 60 - src_at(c, f0 / FPS) - 0.001
    dbl = doubled(c)
    if dbl:
        fps /= 2
    c0 = round(c["start"] * FPS)                     # clip-relative frame j = piece frame + (f0 - c0)
    j0 = f0 - c0
    s, r = c.get("speed", 1.0), c.get("ramp")
    a = r["at"] - j0 / FPS if r else 0                # ramp point, seconds into this piece
    if r and a <= 0:
        s, r = r["to"], None
    if r and a < n / FPS:                            # piecewise playback rate, in source seconds X since the seek
        A = a * s
        pts = f"setpts='if(lt((PTS-STARTPTS)*TB,{A:.4f}),(PTS-STARTPTS)/{s},({A:.4f}/{s}+((PTS-STARTPTS)*TB-{A:.4f})/{r['to']})/TB)'"
        slowest = min(s, r["to"])
    else:
        pts, slowest = f"setpts=(PTS-STARTPTS)/{s}", s
    # slow motion gets motion-compensated in-betweens, not repeats; content at its own speed keeps its native cadence
    interp = slowest < 1 and fps * slowest < 50
    zoom = c.get("zoom", 1.0) * (1.04 if c.get("shake") else 1.0)
    py = c.get("pos_y", 0.5)
    vf = [f"crop={cw}:{ch}:{cx}:{cy}", "setpts=PTS-STARTPTS", f"trim=end={feed:.4f}"] + (["decimate=cycle=2"] if dbl else []) + [pts]
    hold = "tpad=stop_mode=clone:stop_duration=0.2"   # a clip ending at its shot end holds its last frame
    if not interp:
        vf += [f"fps={FPS}", hold]
    vf += [f"scale=w='max({W}/iw,{PIC_H}/ih)*iw*{zoom}':h='max({W}/iw,{PIC_H}/ih)*ih*{zoom}':flags=lanczos", "setsar=1"]
    if c.get("shake"):                               # decaying shake, two incommensurate frequencies per axis
        A, k = c["shake"]["amp"], c["shake"]["decay"]
        u = f"max(0,t+{j0 / FPS:.4f})"               # seconds since the clip start
        env = f"{A}*exp(-{u}/{k})"
        vf.append(f"crop={W}:{PIC_H}:x='clip((iw-{W})/2+{env}*sin({u}*71),0,iw-{W})'"
                  f":y='clip((ih-{PIC_H})*{py}+{env}*0.7*sin({u}*53+1),0,ih-{PIC_H})'")
    else:
        vf.append(f"crop={W}:{PIC_H}:(iw-{W})/2:(ih-{PIC_H})*{py}")
    if interp:
        vf += [f"minterpolate=fps={FPS}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1", hold]
    fz = c.get("freeze")
    K = round(fz["at"] * FPS) - j0 if fz else None   # freeze frame, piece-relative
    if fz and 0 <= K < n:
        vf.append(f"trim=end_frame={K + 1},tpad=stop={n - K - 1}:stop_mode=clone")
    if LOOKS[c.get("look", "neutral")]:
        vf.append(LOOKS[c.get("look", "neutral")])
    N = round(c["end"] * FPS) - c0                   # clip length in frames
    z = ["1"]                                        # zoom terms in the clip-relative frame index J
    J = f"max(0,on+{j0})"
    if c.get("punch"):
        z.append(f"{c['punch']}*pow(max(0,1-{J}/{int(FPS * 0.25)}),2)")
    if c.get("push"):
        p = c["push"]
        z.append(f"{p}*{J}/{N}" if p > 0 else f"{-p}*(1-{J}/{N})")
    if fz and fz.get("push"):
        Kc = round(fz["at"] * FPS)
        z.append(f"{fz['push']}*pow(max(0,{J}-{Kc})/{max(1, N - Kc)},0.6)")
    if len(z) > 1:
        vf.append(f"zoompan=z='{'+'.join(z)}':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s={W}x{PIC_H}:fps={FPS}")
    if fz and 0 <= K < n:                            # the held frame: a two-frame white hit, then drained colour
        vf.append(f"hue=s=0.3:enable='gte(n,{K})'")
        vf.append(f"curves=all='0/0 0.5/0.9 1/1':enable='between(n,{K},{K + 1})'")
    if j0 == 0 and c.get("impact"):
        m, k = c["impact"].get("mode", "negate"), c["impact"]["n"]
        en = f"enable='lt(n,{k})'"
        vf.append({"negate": f"negate={en}", "white": f"curves=all='0/0.85 1/1':{en}",
                   "mono": f"hue=s=0:{en},eq=contrast=2.2:brightness=0.05:{en}"}[m])
    if j0 == 0 and c.get("rgb"):                     # chromatic split, three decaying steps
        A, k = c["rgb"]["amp"], c["rgb"]["n"]
        for q, f in enumerate((1.0, 0.55, 0.25)):
            a0, a1 = q * k // 3, (q + 1) * k // 3 - 1
            px = max(1, round(A * f))
            vf.append(f"rgbashift=rh={px}:bh={-px}:rv={px // 3}:bv={-(px // 3)}:edge=smear:enable='between(n,{a0},{a1})'")
    vf += ["format=yuv420p", "settb=1/60", "setpts=N"]
    return ",".join(vf)

def slit_open(d):
    """Letterbox plates sliding off the picture over d seconds, eased."""
    e = f"(1-pow(1-min(t/{d},1),3))"
    return (f"split[o0][o1];[o1]drawbox=c=black:t=fill,split[top][bot];"
            f"[o0][top]overlay=x=0:y='-{PIC_H // 2}-{PIC_H // 2}*{e}'[o2];[o2][bot]overlay=x=0:y='{PIC_H // 2}+{PIC_H // 2}*{e}'")

def edge_fx(c, n):
    """Effects timed from the start or end of clip c (n frames)."""
    vf = []
    if c.get("open"):
        vf.append(slit_open(c["open"]))
    if c.get("flash"):
        vf.append(f"fade=t=in:st=0:d={c['flash']}:color=white")
    if c.get("fade_in"):
        vf.append(f"fade=t=in:st=0:d={c['fade_in']}")
    if c.get("flash_out"):
        d = c["flash_out"]; vf.append(f"fade=t=out:st={n / FPS - d:.4f}:d={d}:color=white")
    if c.get("fade_out"):
        d = c["fade_out"]; vf.append(f"fade=t=out:st={n / FPS - d:.4f}:d={d}")
    return vf

def render_clip(c):
    """Render clip c to its frames on the output timeline; returns the path."""
    f0 = round(c["start"] * FPS); n = round(c["end"] * FPS) - f0
    inputs = ["-ss", f"{src_at(c, f0 / FPS):.4f}", "-i", f"src/{c['src']}.mkv"]
    post = [FINISH] + edge_fx(c, n) + [f"pad={W}:{H}:0:{(H - PIC_H) // 2}:black", "format=yuv420p"]
    fc = f"[0:v]{frame_chain(c, f0, n)}[a];[a]" + ",".join(post) + "[out]"
    key = hashlib.md5(json.dumps([inputs, fc, n]).encode()).hexdigest()[:12]
    path = f"build/clips/{key}.mp4"                 # content-addressed: reused across EDL revisions
    if not os.path.exists(path):
        cmd = ["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", fc, "-map", "[out]", "-frames:v", str(n),
               "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "12", "-r", str(FPS), path + ".tmp.mp4"]
        subprocess.run(cmd, check=True)
        got = int(subprocess.check_output(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0",
              "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", path + ".tmp.mp4"]).strip())
        if got != n:
            raise SystemExit(f"clip at frame {f0} ({c['src']}#{c.get('shot')}): got {got} frames, need {n}")
        os.rename(path + ".tmp.mp4", path)
    return path

clips = sorted(edl["clips"], key=lambda c: c["start"])
for a, b in zip(clips, clips[1:]):
    assert round(a["end"] * FPS) == round(b["start"] * FPS), f"gap/overlap at {a['end']} -> {b['start']}"
with ThreadPoolExecutor(max_workers=6) as ex:
    paths = list(ex.map(render_clip, clips))
if "--clips-only" in sys.argv:
    print(f"rendered {len(paths)} clips"); sys.exit(0)
with open("build/concat.txt", "w") as f:
    f.writelines(f"file '{os.path.abspath(p)}'\n" for p in paths)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", "build/concat.txt",
                "-c", "copy", "build/video.mp4"], check=True)

# final pass: music, delivery encode
t0 = clips[0]["start"]; dur = clips[-1]["end"] - t0
venc = ["-c:v", "libx264", "-preset", "veryfast" if draft else "slow", "-crf", "26" if draft else "16",
        "-maxrate", "25M", "-bufsize", "50M", "-pix_fmt", "yuv420p", "-profile:v", "high", "-r", str(FPS)]
cmd = ["ffmpeg", "-v", "error", "-y", "-i", "build/video.mp4", "-ss", f"{t0:.4f}", "-i", edl["music"],
       "-map", "0:v", "-map", "1:a", *venc, "-af", f"afade=t=out:st={dur - 0.4:.4f}:d=0.4", "-c:a", "aac", "-b:a", "320k", "-movflags", "+faststart",
       "-t", f"{dur:.4f}", out]
subprocess.run(cmd, check=True)
print(f"rendered {out}: {len(clips)} clips, {dur:.2f}s")
