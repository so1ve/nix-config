"""Textless video cover from one source frame. The picture is cut into upright panels with dark gutters and small
vertical offsets; the panel holding the subject keeps its colour, the others are pressed into a two-colour duotone,
and one gutter carries a thin accent seam. Shared finish: split-tone grade, highlight glow, vignette, fine grain.
Usage (from the project root; reads src/<id>.mkv and the letterbox crop in analysis/shots/<id>.json):
  python3 -I $C/cover.py <src-id> <time> <out.png> [--at 0.5,0.45] [--zoom 1.08] [--cuts 0.28,0.72]
         [--shift -36,0,30] [--tone 110,200,196] [--accent 214,40,48] [--seam 2] [--size 1920x1080]
--at is the subject (the eyes) in the source picture, 0..1; it lands at the cover's centre, 45% down."""
import argparse, json, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

def rgb(s): return tuple(int(v) for v in s.split(","))
def floats(s): return [float(v) for v in s.split(",")]
ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("time", type=float); ap.add_argument("out")
ap.add_argument("--at", type=floats, default=[0.5, 0.45], help="subject x,y in the source picture (0..1)")
ap.add_argument("--zoom", type=float, default=1.08, help="crop tighter than the cover-filling scale")
ap.add_argument("--cuts", type=floats, default=[0.28, 0.72], help="panel edges as fractions of the cover width")
ap.add_argument("--shift", type=floats, help="vertical offset in px per panel (default -36,0,30 pattern)")
ap.add_argument("--tone", type=rgb, default=(110, 200, 196), help="duotone highlight colour of the side panels")
ap.add_argument("--accent", type=rgb, default=(214, 40, 48), help="seam colour")
ap.add_argument("--seam", type=int, help="gutter (1 = leftmost) that carries the seam; 0 for none")
ap.add_argument("--size", default="1920x1080")
a = ap.parse_args()
W, H = map(int, a.size.split("x"))
INK, GUT = (8, 12, 18), 14

frame = tempfile.mktemp(suffix=".png", prefix="cover.")
subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{a.time}", "-i", f"src/{a.src}.mkv", "-frames:v", "1", frame], check=True)
m = json.load(open(f"analysis/shots/{a.src}.json"))
cw, ch, x0, y0 = m["crop"]; cw, ch = min(cw, m["width"] - x0), min(ch, m["height"] - y0)
pic = Image.open(frame).convert("RGB").crop((x0, y0, x0 + cw, y0 + ch))       # letterbox removed
s = max(W / cw, H / ch) * a.zoom
pic = pic.resize((round(cw * s), round(ch * s)), Image.LANCZOS)
cx = min(max(round(a.at[0] * pic.width - W / 2), 0), pic.width - W)
cy = min(max(round(a.at[1] * pic.height - H * 0.45), 0), pic.height - H)
pic = pic.crop((cx, cy, cx + W, cy + H))

# split tone: shadows lean teal, highlights warm white, then contrast and saturation
f = np.asarray(pic).astype(np.float32) / 255
t = (f @ [0.299, 0.587, 0.114])[..., None]
tint = np.array([0.02, 0.10, 0.14]) * (1 - t) + np.array([1.0, 0.97, 0.93]) * t
f *= 0.82 + 0.18 * tint / np.maximum(tint.mean(-1, keepdims=True), 1e-3)
pic = Image.fromarray(np.clip(f * 255, 0, 255).astype(np.uint8))
pic = ImageEnhance.Color(ImageEnhance.Contrast(pic).enhance(1.1)).enhance(1.08)

def duotone(p):
    g = np.asarray(p.convert("L")).astype(np.float32)[..., None] / 255
    return Image.fromarray(np.clip(np.array(INK) * (1 - g) + np.array(a.tone) * 0.9 * g, 0, 255).astype(np.uint8))

edges = [0] + [round(W * c) for c in a.cuts] + [W]
n = len(edges) - 1
shift = a.shift or [(-36, 0, 30)[k % 3] if n == 3 else (-30 if k % 2 == 0 else 26) for k in range(n)]
assert len(shift) == n, f"--shift needs {n} values"
hero = next(k for k in range(n) if edges[k] <= W / 2 < edges[k + 1])        # the panel at the subject
cover = Image.new("RGB", (W, H), INK)
for k in range(n):
    l, r = edges[k] + (GUT // 2 if k else 0), edges[k + 1] - (GUT // 2 if k < n - 1 else 0)
    dy = round(shift[k])
    p = pic.crop((l, max(0, -dy), r, H - max(0, dy)))
    cover.paste(p if k == hero else duotone(p), (l, max(0, dy)))
seam = hero + 1 if a.seam is None else a.seam                                 # default: the gutter right of the subject
if 0 < seam < n:
    x = edges[seam] - GUT // 2 + 3
    ImageDraw.Draw(cover).rectangle((x, round(H * 0.16), x + 7, round(H * 0.58)), fill=a.accent)

# finish: highlight glow (screen blend), vignette, grain
f = np.asarray(cover).astype(np.float32)
hi = np.clip((f.mean(-1, keepdims=True) - 170) * 3, 0, 255).repeat(3, -1).astype(np.uint8)
g = np.asarray(Image.fromarray(hi).filter(ImageFilter.GaussianBlur(28))).astype(np.float32)
f = 255 - (255 - f) * (255 - g * 0.28) / 255
yy, xx = np.mgrid[0:H, 0:W]
r = np.hypot((xx - W / 2) / (W * 0.62), (yy - H / 2) / (H * 0.62))
f *= (1 - 0.3 * np.clip(r - 0.45, 0, 1) ** 1.5)[..., None]
f += np.random.default_rng(1).normal(0, 6, (H, W, 1))
Image.fromarray(np.clip(f, 0, 255).astype(np.uint8)).save(a.out)
print(a.out, (W, H))
