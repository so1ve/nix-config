"""Tile frames of a rendered video at given times, to check cuts in the actual output.
Usage: python3 -I $S/framesheet.py video.mp4 out.jpg cols t1 t2 ...
For a cut at time T, sample T-0.25, T-0.05, T+0.02, T+0.25: the last frames of the outgoing shot and the first of
the incoming one must show the matched gesture, movement or flash."""
import subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

video, out, cols, times = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:]
CW = 320
tmp = tempfile.mkdtemp(prefix="framesheet.")
cells = []
for k, t in enumerate(times):
    p = f"{tmp}/{k}.png"
    subprocess.run(["ffmpeg", "-v", "error", "-ss", t, "-i", video, "-frames:v", "1", "-vf", f"scale={CW}:-2", p], check=True)
    cells.append((t, Image.open(p)))
CH = cells[0][1].height
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cols * CW, rows * (CH + 16)), (20, 20, 20)); d = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=13)
for k, (t, im) in enumerate(cells):
    x, y = (k % cols) * CW, (k // cols) * (CH + 16)
    sheet.paste(im, (x, y + 16)); d.text((x + 3, y + 1), t, fill=(255, 220, 0), font=font)
sheet.save(out, quality=82)
print(out)
