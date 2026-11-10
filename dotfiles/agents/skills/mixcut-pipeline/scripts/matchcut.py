"""Find match-cut candidates between two pools of shots, from analysis/motion profiles.
Usage: python3 -I $S/matchcut.py out.jpg "A-src,A-src:shot+shot..." "B-src,..." [n]   (needs analysis/motion)
For every usable outgoing frame (A) and incoming frame (B) it scores continuity across a cut at that point:
same motion direction and speed, subject (motion centroid) at the same screen x, similar brightness.
Prints the best distinct shot pairs as  A-src#shot @ta  ->  B-src#shot @tb  and draws them side by side
(two frames before the cut | the cut | two frames after)."""
import json, math, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

out, A, B = sys.argv[1], sys.argv[2].split(","), sys.argv[3].split(",")
N = int(sys.argv[4]) if len(sys.argv) > 4 else 12
ban = {}
for l in open("catalog/banned.tsv"):
    if l.strip() and not l.startswith("#"):
        s, i, _ = l.split("\t", 2); ban.setdefault(s, set()).add(i)

def frames(srcs, side):
    rows = []
    for tok in srcs:                                 # "src" or "src:shot+shot+..."
        src, _, only = tok.partition(":"); only = {int(x) for x in only.split("+") if x}
        if "*" in ban.get(src, ()):
            continue
        m = json.load(open(f"analysis/motion/{src}.json")); fps = m["fps"]
        tp = f"analysis/tags/{src}.json"               # optional vision tags
        tags = {t["i"]: t for t in json.load(open(tp))["shots"]} if os.path.exists(tp) else {}
        sm = lambda k: np.convolve(np.array(m[k], float), np.ones(3) / 3, "same")
        mag, dx, dy, cx, lu = sm("mag"), sm("dx"), sm("dy"), np.array(m["cx"], float), sm("luma")
        for s in json.load(open(f"analysis/shots/{src}.json"))["shots"]:
            t = tags.get(s["i"], {})
            if (only and s["i"] not in only) or t.get("use") is False or t.get("text") == "big" or str(s["i"]) in ban.get(src, ()):
                continue
            lo, hi = (s["start"] + 0.45, s["end"] - 0.06) if side == "A" else (s["start"] + 0.04, s["end"] - 0.45)
            for f in range(math.ceil(lo * fps), int(hi * fps) + 1, 2):
                if f < len(mag):
                    rows.append((src, s["i"], f / fps, mag[f], dx[f], dy[f], cx[f], lu[f]))
    return rows

ra, rb = frames(A, "A"), frames(B, "B")
fa = np.array([r[3:] for r in ra], np.float32); fb = np.array([r[3:] for r in rb], np.float32)
ma, mb = fa[:, 0:1], fb[None, :, 0]
na = np.hypot(fa[:, 1:2], fa[:, 2:3]) + 1e-6; nb = np.hypot(fb[None, :, 1], fb[None, :, 2]) + 1e-6
cos = (fa[:, 1:2] * fb[None, :, 1] + fa[:, 2:3] * fb[None, :, 2]) / (na * nb)
moving = (na > 0.8) & (nb > 0.8)
direction = np.where(moving, cos, -0.5)                              # both must travel, the same way
speed = 1 - np.minimum(1, np.abs(np.log((ma + 0.5) / (mb + 0.5))))
position = 1 - 2 * np.abs(fa[:, 3:4] - fb[None, :, 3])
light = 1 - np.abs(fa[:, 4:5] - fb[None, :, 4]) / 80
score = 2 * direction + speed + 1.5 * position + light
order = np.argsort(score, axis=None)[::-1]
picked, seen = [], set()
for k in order:
    i, j = divmod(int(k), score.shape[1])
    key = (ra[i][0], ra[i][1], rb[j][0], rb[j][1])
    if key in seen or any(p[0][:2] == ra[i][:2] for p in picked) or sum(p[1][:2] == rb[j][:2] for p in picked) >= 2:
        continue
    seen.add(key); picked.append((ra[i], rb[j], float(score[i, j])))
    if len(picked) == N:
        break

tmp = tempfile.mkdtemp(prefix="matchcut.")
CW, CH = 240, 100
def grab(src, t, p):
    meta = json.load(open(f"analysis/shots/{src}.json")); cw, ch, x0, y0 = meta["crop"]
    cw, ch = min(cw, meta["width"] - x0), min(ch, meta["height"] - y0); ph = min(ch, round(cw / 2.39))
    subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{max(0, t):.3f}", "-i", f"src/{src}.mkv", "-frames:v", "1",
                    "-vf", f"crop={cw}:{ph}:{x0}:{y0 + (ch - ph) // 2},scale={CW}:{CH}", p], check=True)
    return p
font = ImageFont.load_default(size=12)
sheet = Image.new("RGB", (4 * CW + 12, len(picked) * (CH + 16)), (22, 22, 22)); d = ImageDraw.Draw(sheet)
for q, (a, b, sc) in enumerate(picked):
    y = q * (CH + 16)
    ims = [grab(a[0], a[2] - 0.25, f"{tmp}/{q}a0.jpg"), grab(a[0], a[2], f"{tmp}/{q}a1.jpg"),
           grab(b[0], b[2], f"{tmp}/{q}b0.jpg"), grab(b[0], b[2] + 0.25, f"{tmp}/{q}b1.jpg")]
    for k, p in enumerate(ims):
        sheet.paste(Image.open(p), (k * CW + (12 if k > 1 else 0), y + 16))
    lab = f"{q}  {a[0]}#{a[1]} @{a[2]:.2f} (v{a[3]:.1f} x{a[6]:.2f})  ->  {b[0]}#{b[1]} @{b[2]:.2f} (v{b[3]:.1f} x{b[6]:.2f})  s{sc:.2f}"
    d.text((3, y + 1), lab, fill=(255, 220, 0), font=font); print(lab)
sheet.save(out, quality=82)
