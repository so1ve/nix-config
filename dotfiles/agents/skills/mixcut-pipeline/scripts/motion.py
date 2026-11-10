"""Per-frame motion profile of a source video (inside its active picture), for choosing cut points.
Usage: python3 -I $S/motion.py <src-id>...  -> analysis/motion/<id>.json
Sampled at 30 fps on a 2.39 centre crop at 240 px wide: for every frame t, mag (mean optical-flow speed, px/frame),
dx / dy (mean flow, + = right / down), cx (x of the motion-weighted centroid, 0..1) and luma (0..255).
A cut feels motivated when the incoming clip's motion continues the outgoing one's (direction, screen position),
and an action lands on the beat when the clip is placed so its mag or luma peak sits on the hit."""
import json, os, subprocess, sys
import numpy as np, cv2

W, FPS = 240, 30
H = round(W / 2.39)
os.makedirs("analysis/motion", exist_ok=True)
for src in sys.argv[1:]:
    meta = json.load(open(f"analysis/shots/{src}.json"))
    cw, ch, cx, cy = meta["crop"]
    cw, ch = min(cw, meta["width"] - cx), min(ch, meta["height"] - cy)
    ph = min(ch, round(cw / 2.39))                   # centre 2.39 window of the active picture
    vf = f"crop={cw}:{ph}:{cx}:{cy + (ch - ph) // 2},fps={FPS},scale={W}:{H}:flags=area,format=gray"
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-threads", "2", "-i", f"src/{src}.mkv", "-vf", vf,
                          "-f", "rawvideo", "-"], stdout=subprocess.PIPE)
    prev, rows = None, []
    xs = np.linspace(0, 1, W)[None, :]
    while True:
        buf = p.stdout.read(W * H)
        if len(buf) < W * H:
            break
        f = np.frombuffer(buf, np.uint8).reshape(H, W)
        if prev is None:
            rows.append((0.0, 0.0, 0.0, 0.5, float(f.mean())))
        else:
            fl = cv2.calcOpticalFlowFarneback(prev, f, None, 0.5, 3, 15, 3, 5, 1.2, 0)
            m = np.hypot(fl[..., 0], fl[..., 1])
            s = m.sum()
            rows.append((float(m.mean()), float(fl[..., 0].mean()), float(fl[..., 1].mean()),
                         float((m * xs).sum() / s) if s > 1e-6 else 0.5, float(f.mean())))
        prev = f
    if p.wait():
        raise SystemExit(f"ffmpeg failed on {src}")
    a = np.array(rows).round(3)
    json.dump(dict(id=src, fps=FPS, mag=a[:, 0].tolist(), dx=a[:, 1].tolist(), dy=a[:, 2].tolist(),
                   cx=a[:, 3].tolist(), luma=a[:, 4].round(1).tolist()), open(f"analysis/motion/{src}.json", "w"))
    print(f"{src}: {len(rows)} frames")
