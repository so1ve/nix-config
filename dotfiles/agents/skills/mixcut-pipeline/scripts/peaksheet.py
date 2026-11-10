"""Contact sheet of candidate shots at their motion peak (needs analysis/motion).
Usage: [COLS=6] [CW=320] python3 -I $S/peaksheet.py out.jpg src:shot,shot,... ...
Each cell: the frame at the shot's smoothed motion peak (2.39 crop). Label: src#shot dur, peak offset, peak speed,
mean motion direction around the peak (arrow), luma."""
import json, math, os, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont
out, specs = sys.argv[1], sys.argv[2:]
cells = []
for sp in specs:
    src, ids = sp.split(":")
    shots = json.load(open(f"analysis/shots/{src}.json"))["shots"]
    m = json.load(open(f"analysis/motion/{src}.json"))
    for i in map(int, ids.split(",")):
        s = shots[i]; a, b = math.ceil(s["start"] * 30) + 2, int(s["end"] * 30) - 2
        if b <= a: a, b = int(s["start"] * 30), max(int(s["start"] * 30), int(s["end"] * 30) - 1)
        mag = m["mag"][a:b + 1]
        sm = [sum(mag[max(0, j - 1):j + 2]) / len(mag[max(0, j - 1):j + 2]) for j in range(len(mag))]
        k = max(range(len(sm)), key=sm.__getitem__)
        lo, hi = max(0, k - 3), min(len(mag), k + 4)
        dx = sum(m["dx"][a + lo:a + hi]) / (hi - lo); dy = sum(m["dy"][a + lo:a + hi]) / (hi - lo)
        cells.append((src, i, s, (a + k) / 30, sm[k], dx, dy, m["luma"][a + k]))
COLS, CW, CH, LH = int(os.environ.get("COLS", 6)), int(os.environ.get("CW", 320)), round(int(os.environ.get("CW", 320)) / 2.39), 16
tmp = tempfile.mkdtemp(prefix="peaksheet.")
def grab(c):
    src, i, s, t, *_ = c
    meta = json.load(open(f"analysis/shots/{src}.json")); cw, ch, cx, cy = meta["crop"]
    cw, ch = min(cw, meta["width"] - cx), min(ch, meta["height"] - cy); ph = min(ch, round(cw / 2.39))
    p = f"{tmp}/{src}_{i}.jpg"
    subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.3f}", "-i", f"src/{src}.mkv", "-frames:v", "1", "-vf",
                    f"crop={cw}:{ph}:{cx}:{cy + (ch - ph) // 2},scale={CW}:{CH}", p], check=True)
    return p
with ThreadPoolExecutor(8) as ex: paths = list(ex.map(grab, cells))
rows = (len(cells) + COLS - 1) // COLS
sheet = Image.new("RGB", (COLS * CW, rows * (CH + LH)), (22, 22, 22)); d = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=12)
arrows = "→↘↓↙←↖↑↗"
for q, (c, p) in enumerate(zip(cells, paths)):
    src, i, s, t, mg, dx, dy, lu = c
    x, y = (q % COLS) * CW, (q // COLS) * (CH + LH)
    sheet.paste(Image.open(p), (x, y + LH))
    ang = math.atan2(dy, dx); arr = arrows[round(ang / (math.pi / 4)) % 8] if math.hypot(dx, dy) > 0.4 else "·"
    d.text((x + 2, y + 1), f"{src[:6]}#{i} {s['dur']:.1f}s pk+{t - s['start']:.2f} v{mg:.1f}{arr} L{lu:.0f}", fill=(255, 220, 0), font=font)
sheet.save(out, quality=82); print(out, len(cells))
