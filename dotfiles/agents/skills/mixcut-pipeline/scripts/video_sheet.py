"""Storyboard a rendered video: one frame from the middle of every EDL clip, labelled with clip index, time and group.
Usage: python3 -I $S/video_sheet.py <video.mp4> <edl.json> [prefix] -> build/preview/<prefix>_NN.jpg (40 clips per sheet)"""
import json, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont

video, edl = sys.argv[1:3]
prefix = sys.argv[3] if len(sys.argv) > 3 else "render"
clips = json.load(open(edl))["clips"]
CW, CH = 384, 216
def grab(k):
    c = clips[k]; t = (c["start"] + c["end"]) / 2
    out = f"build/preview/frames/{prefix}_{k:04d}.jpg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.3f}", "-i", video, "-frames:v", "1",
                    "-vf", f"scale={CW}:{CH}", out], check=True)
    return out
with ThreadPoolExecutor(8) as ex:
    paths = list(ex.map(grab, range(len(clips))))
font = ImageFont.load_default(size=14)
per, cols = 40, 5
for p in range(0, len(clips), per):
    chunk = range(p, min(p + per, len(clips)))
    rows = (len(chunk) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (CW + 6), rows * (CH + 20)), (30, 30, 30)); d = ImageDraw.Draw(sheet)
    for q, k in enumerate(chunk):
        c = clips[k]; x, y = (q % cols) * (CW + 6), (q // cols) * (CH + 20)
        sheet.paste(Image.open(paths[k]), (x, y + 20))
        d.text((x + 3, y + 3), f"{k} {c.get('group', '')} @{c['start']:.2f} {c['end'] - c['start']:.2f}s {c['src'][:6]}#{c['shot']}",
               fill=(255, 226, 0), font=font)
    out = f"build/preview/{prefix}_{p // per:02d}.jpg"; sheet.save(out, quality=85); print(out)
