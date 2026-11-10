"""Detect shots in a source video and render labelled contact sheets.
Usage: python3 -I $S/shots.py <src.mkv> <out_dir>
Writes <out_dir>/shots/<id>.json, <out_dir>/thumbs/<id>/sNNNN.jpg, <out_dir>/sheets/<id>_NN.jpg"""
import json, os, subprocess, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1:3]
vid = os.path.basename(SRC).split(".")[0]
W, FPS = 384, 30
CUT_T, MIN_LEN = 26.0, 6            # HSV mean-abs-diff threshold, min shot length in frames

probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                   "stream=width,height,r_frame_rate:format=duration", "-of", "json", SRC]))
sw, sh = probe["streams"][0]["width"], probe["streams"][0]["height"]
src_fps = eval(probe["streams"][0]["r_frame_rate"])
H = int(round(sh * W / sw / 2) * 2)
proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", SRC, "-vf", f"fps={FPS},scale={W}:{H}",
                         "-f", "rawvideo", "-pix_fmt", "bgr24", "-"], stdout=subprocess.PIPE)
fsize = W * H * 3
scores, motion, luma, sat, frames = [], [], [], [], []
row_max = np.zeros(H); col_max = np.zeros(W); prev_hsv = prev_g = None
while True:
    buf = proc.stdout.read(fsize)
    if len(buf) < fsize: break
    f = np.frombuffer(buf, np.uint8).reshape(H, W, 3)
    hsv = cv2.cvtColor(f, cv2.COLOR_BGR2HSV).astype(np.int16)
    g = cv2.cvtColor(f, cv2.COLOR_BGR2GRAY).astype(np.int16)
    scores.append(0.0 if prev_hsv is None else float(np.abs(hsv - prev_hsv).mean(axis=(0, 1)).mean()))
    motion.append(0.0 if prev_g is None else float(np.abs(g - prev_g).mean()))
    luma.append(float(g.mean())); sat.append(float(hsv[..., 1].mean()))
    row_max = np.maximum(row_max, (g > 24).mean(axis=1)); col_max = np.maximum(col_max, (g > 24).mean(axis=0))
    frames.append(cv2.imencode(".jpg", f, [cv2.IMWRITE_JPEG_QUALITY, 80])[1])
    prev_hsv, prev_g = hsv, g
proc.wait()
n = len(scores); s = np.array(scores)
# adaptive cut: absolute threshold and well above local median (rejects fast-motion false positives)
cuts = [0]
for i in range(1, n):
    lo, hi = max(1, i - 15), min(n, i + 16)
    local = np.median(np.r_[s[lo:i], s[i + 1:hi]]) if hi - lo > 2 else 0
    if s[i] > CUT_T and s[i] > 2.5 * local + 8 and i - cuts[-1] >= MIN_LEN:
        cuts.append(i)
cuts.append(n)
# active picture (letterbox) in source pixels
rows = np.where(row_max > 0.02)[0]; cols = np.where(col_max > 0.02)[0]
y0, y1 = (rows[0], rows[-1] + 1) if len(rows) else (0, H)
x0, x1 = (cols[0], cols[-1] + 1) if len(cols) else (0, W)
k = sh / H
crop = [int(round((x1 - x0) * k)), int(round((y1 - y0) * k)), int(round(x0 * k)), int(round(y0 * k))]
os.makedirs(f"{OUT}/shots", exist_ok=True); os.makedirs(f"{OUT}/thumbs/{vid}", exist_ok=True)
os.makedirs(f"{OUT}/sheets", exist_ok=True)
shots = []
mot = np.array(motion)
for j in range(len(cuts) - 1):
    a, b = cuts[j], cuts[j + 1]
    inner = mot[a + 1:b] if b - a > 1 else mot[a:b]
    shots.append(dict(i=j, start=round(a / FPS, 3), end=round(b / FPS, 3), dur=round((b - a) / FPS, 3),
                      motion=round(float(inner.mean()), 2), motion_max=round(float(inner.max()), 2),
                      luma=round(float(np.mean(luma[a:b])), 1), sat=round(float(np.mean(sat[a:b])), 1)))
    for tag, fr in (("a", a + (b - a) // 6), ("m", (a + b) // 2), ("z", b - 1 - (b - a) // 6)):
        open(f"{OUT}/thumbs/{vid}/s{j:04d}{tag}.jpg", "wb").write(frames[fr].tobytes())
json.dump(dict(id=vid, width=sw, height=sh, fps=src_fps, duration=n / FPS, crop=crop, shots=shots),
          open(f"{OUT}/shots/{vid}.json", "w"), indent=0)

# contact sheets: one row per shot cell = [start | middle | end] frames, 2 cells per row, 12 rows per sheet
font = ImageFont.load_default(size=15)
cw = 3 * 200; ch = int(200 * H / W) + 20
per = 24
for p in range(0, len(shots), per):
    sheet = Image.new("RGB", (2 * cw + 10, 12 * ch), (40, 40, 40))
    for q, shot in enumerate(shots[p:p + per]):
        x, y = (q % 2) * (cw + 10), (q // 2) * ch
        for c, tag in enumerate("amz"):
            im = Image.open(f"{OUT}/thumbs/{vid}/s{shot['i']:04d}{tag}.jpg").resize((200, ch - 20))
            sheet.paste(im, (x + c * 200, y + 20))
        d = ImageDraw.Draw(sheet)
        d.text((x + 4, y + 2), f"#{shot['i']}  {shot['start']:.2f}-{shot['end']:.2f}s ({shot['dur']:.1f}s)  mot {shot['motion']:.1f}",
               fill=(255, 230, 0), font=font)
    sheet.save(f"{OUT}/sheets/{vid}_{p // per:02d}.jpg", quality=82)
print(f"{vid}: {len(shots)} shots, {n / FPS:.1f}s, src {sw}x{sh}@{src_fps:.2f}, active {crop}")
