"""Frame strips for choosing exact cut points: one row per spec, n frames evenly spaced, labelled with source time.
Usage: python3 -I $S/strips.py out.jpg n spec...
  src:shot           the whole detected shot
  src:t0:t1          a source range in seconds
  src:all            the whole video, n seconds per row (about one frame a second): read a source's story
  part.json:a-b      clips a..b of a built part, one row each from in to out: check every clip before rendering
Detected shots often hide internal cuts and dissolves; check the strip before trusting a shot's start or end."""
import json, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont

out, n, specs = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
CW, CH = 200, 84
tmp = tempfile.mkdtemp(prefix="strips.")
rows = []                                            # (label, src, t0, t1)
for sp in specs:
    head, _, rest = sp.partition(":")
    if head.endswith(".json"):
        clips = json.load(open(head))["clips"]; a, b = map(int, rest.split("-"))
        for k in range(a, min(b, len(clips) - 1) + 1):
            c = clips[k]; t1 = c["in"] + (c["end"] - c["start"]) * c.get("speed", 1.0)
            rows.append((f"#{k} ", c["src"], c["in"] + 0.02, t1 - 0.02))
        continue
    shots = json.load(open(f"analysis/shots/{head}.json"))["shots"]
    if rest == "all":
        end = shots[-1]["end"]
        rows += [("", head, t, min(t + n - 1, end - 0.05)) for t in range(0, int(end), n)]
    elif rest.count(":") == 0:
        s = shots[int(rest)]; rows.append(("", head, s["start"] + 0.02, s["end"] - 0.03))
    else:
        t0, t1 = rest.split(":"); rows.append(("", head, float(t0), float(t1)))
jobs = []
for r, (label, src, t0, t1) in enumerate(rows):
    meta = json.load(open(f"analysis/shots/{src}.json"))
    cw, ch, x0, y0 = meta["crop"]
    cw, ch = min(cw, meta["width"] - x0), min(ch, meta["height"] - y0); ph = min(ch, round(cw / 2.39))
    vf = f"crop={cw}:{ph}:{x0}:{y0 + (ch - ph) // 2},scale={CW}:{CH}"
    jobs += [(r, q, src, t0 + (t1 - t0) * q / (n - 1), vf, label if q == 0 else "") for q in range(n)]

def grab(j):
    r, q, src, t, vf, _ = j; p = f"{tmp}/{r}-{q}.jpg"
    subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.3f}", "-i", f"src/{src}.mkv", "-frames:v", "1", "-vf", vf, p], check=True)
    return p

with ThreadPoolExecutor(8) as ex:
    paths = list(ex.map(grab, jobs))
sheet = Image.new("RGB", (n * CW, len(rows) * (CH + 13)), (20, 20, 20)); d = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=11)
for (r, q, src, t, _, label), p in zip(jobs, paths):
    x, y = q * CW, r * (CH + 13)
    sheet.paste(Image.open(p), (x, y + 13)); d.text((x + 2, y), f"{label}{src[:6]} {t:.2f}", fill=(255, 220, 0), font=font)
sheet.save(out, quality=80)
print(out)
