"""Find a person across sources from reference boxes: a colour match narrows thousands of shots to a few dozen
candidates, laid out beside the references for a visual check. Colour cannot tell apart people who dress alike, so a
hit is a candidate, never an identification.
Usage: python3 -I $S/whois.py "<name>" out.jpg [src...]   [TOP=48]   (needs analysis/shots and analysis/thumbs)
References: in catalog/characters.md, under the person's heading (a "## " line containing <name>), lines
  - ref: <src> <time> <x>,<y>,<w>,<h>     a box in fractions of the source's active picture (face and hair work best)
Score: the box's Lab colour histogram is back-projected (Swain-Ballard colour ratio) onto every thumbnail; at the
strongest windows of the box's width (x0.6, x1, x1.6 of the picture width it covers) the window's histogram is
intersected with the reference's; a shot scores its best thumbnail. Prints the ranking and draws the references
(top row) and the candidates with their best window."""
import glob, json, os, re, subprocess, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

name, out = sys.argv[1], sys.argv[2]
srcs = sys.argv[3:] or sorted(os.path.basename(p)[:-5] for p in glob.glob("analysis/shots/*.json"))
TOP, TW, BINS = int(os.environ.get("TOP", 48)), 384, (4, 8, 8)     # thumbnail width (shots.py), Lab bins
NB = BINS[0] * BINS[1] * BINS[2]

def bins(img):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.int32)
    return ((lab[..., 0] * BINS[0] // 256) * BINS[1] + lab[..., 1] * BINS[1] // 256) * BINS[2] + lab[..., 2] * BINS[2] // 256

def hist(idx):
    h = np.bincount(idx.ravel(), minlength=NB).astype(np.float64)
    return h / max(1.0, h.sum())

metas = {}
def active(src):
    """Shot list and the active picture (x, y, w, h) in thumbnail pixels."""
    m = metas.setdefault(src, json.load(open(f"analysis/shots/{src}.json")))
    k = TW / m["width"]; cw, ch, cx, cy = m["crop"]
    return m, (round(cx * k), round(cy * k), round(min(cw, m["width"] - cx) * k), round(min(ch, m["height"] - cy) * k))

text = open("catalog/characters.md").read()
sec = re.search(rf"^## [^\n]*{re.escape(name)}[^\n]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
if not sec:
    raise SystemExit(f"no '## ...{name}...' heading in catalog/characters.md")
refs = []
for src, t, *box in re.findall(r"^- ref: (\S+) ([\d.]+) ([\d.]+),([\d.]+),([\d.]+),([\d.]+)", sec.group(1), re.M):
    m, (ax, ay, aw, ah) = active(src)
    th = round(m["height"] * TW / m["width"] / 2) * 2
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", t, "-i", f"src/{src}.mkv", "-frames:v", "1", "-vf", f"scale={TW}:{th}",
                          "-f", "rawvideo", "-pix_fmt", "bgr24", "-"], capture_output=True, check=True).stdout
    pic = np.frombuffer(raw, np.uint8).reshape(th, TW, 3)[ay:ay + ah, ax:ax + aw]
    x, y, w, h = map(float, box)
    crop = pic[round(y * ah):round((y + h) * ah), round(x * aw):round((x + w) * aw)]
    refs.append(dict(src=src, t=float(t), crop=crop, hist=hist(bins(crop)), w=w, aspect=crop.shape[0] / crop.shape[1]))
if not refs:
    raise SystemExit(f"no '- ref: <src> <time> <x>,<y>,<w>,<h>' lines under {name}")

def match(img, r):
    """Best (score, window) of reference r in img."""
    idx = bins(img); bp = np.minimum(r["hist"] / np.maximum(hist(idx), 1e-9), 1.0)[idx].astype(np.float32)
    best = (0.0, None)
    for s in (0.6, 1.0, 1.6):
        ww = max(8, min(img.shape[1], round(r["w"] * s * img.shape[1]))); wh = max(8, min(img.shape[0], round(ww * r["aspect"])))
        dens = cv2.boxFilter(bp, -1, (ww, wh), borderType=cv2.BORDER_CONSTANT)
        for _ in range(3):                                   # the three strongest windows at this size
            cy, cx = np.unravel_index(np.argmax(dens), dens.shape)
            x0, y0 = min(max(0, cx - ww // 2), img.shape[1] - ww), min(max(0, cy - wh // 2), img.shape[0] - wh)
            sc = float(np.minimum(hist(idx[y0:y0 + wh, x0:x0 + ww]), r["hist"]).sum())
            if sc > best[0]: best = (sc, (x0, y0, ww, wh))
            dens[max(0, cy - wh // 2):cy + wh // 2 + 1, max(0, cx - ww // 2):cx + ww // 2 + 1] = 0
    return best

hits = []
for src in srcs:
    m, (ax, ay, aw, ah) = active(src)
    for s in m["shots"]:
        for tag, t in (("a", s["start"] + s["dur"] / 6), ("m", (s["start"] + s["end"]) / 2), ("z", s["end"] - s["dur"] / 6)):
            img = cv2.imread(f"analysis/thumbs/{src}/s{s['i']:04d}{tag}.jpg")[ay:ay + ah, ax:ax + aw]
            sc, win = max((match(img, r) for r in refs), key=lambda b: b[0])
            hits.append((sc, src, s["i"], t, tag, win))
best = {}
for h in hits:                                               # a shot scores its best thumbnail
    if h[0] > best.get((h[1], h[2]), (0,))[0]: best[h[1], h[2]] = h
ranked = sorted(best.values(), reverse=True)[:TOP]
for sc, src, i, t, _, _ in ranked:
    print(f"{sc:.3f}  {src}#{i}  {t:.2f}s")

CW, COLS = 240, 8
font = ImageFont.load_default(size=12)
rh = 120; rw = [round(r["crop"].shape[1] * rh / r["crop"].shape[0]) for r in refs]
ch = round(CW * 9 / 21.5)
sheet = Image.new("RGB", (COLS * CW, rh + 18 + (len(ranked) + COLS - 1) // COLS * (ch + 16)), (20, 20, 20)); d = ImageDraw.Draw(sheet)
x = 0
for r, w in zip(refs, rw):
    sheet.paste(Image.fromarray(cv2.cvtColor(r["crop"], cv2.COLOR_BGR2RGB)).resize((w, rh)), (x, 16))
    d.text((x + 2, 2), f"ref {r['src'][:6]} {r['t']:.1f}", fill=(120, 220, 255), font=font); x += w + 8
for q, (sc, src, i, t, tag, (wx, wy, ww, wh)) in enumerate(ranked):
    m, (ax, ay, aw, ah) = active(src)
    img = Image.open(f"analysis/thumbs/{src}/s{i:04d}{tag}.jpg").crop((ax, ay, ax + aw, ay + ah))
    k = CW / aw; img = img.resize((CW, round(ah * k)))
    cell = Image.new("RGB", (CW, ch), (0, 0, 0)); cell.paste(img, (0, (ch - img.height) // 2))
    ImageDraw.Draw(cell).rectangle((wx * k, wy * k + (ch - img.height) // 2, (wx + ww) * k, (wy + wh) * k + (ch - img.height) // 2), outline=(255, 60, 60), width=2)
    px, py = q % COLS * CW, rh + 18 + q // COLS * (ch + 16)
    sheet.paste(cell, (px, py + 14)); d.text((px + 2, py), f"{q} {src[:6]}#{i} {t:.1f}s {sc:.2f}", fill=(255, 220, 0), font=font)
sheet.save(out, quality=82)
print(out)
