"""Perceptual (difference) hashes of every shot's start/mid/end thumbnails -> analysis/phash.json
Two shots are visual duplicates when any of their frames are within a small Hamming distance."""
import glob, json, os
from PIL import Image
def dhash(path, n=16):
    im = Image.open(path).convert("L").resize((n + 1, n))
    px = list(im.get_flattened_data()); bits = 0
    for r in range(n):
        for c in range(n):
            bits = bits << 1 | (px[r * (n + 1) + c] > px[r * (n + 1) + c + 1])
    rgb = Image.open(path).convert("RGB").resize((1, 1)).getpixel((0, 0))
    return [bits, list(rgb)]
out = {}
for d in sorted(glob.glob("analysis/thumbs/*")):
    vid = os.path.basename(d)
    for f in sorted(glob.glob(f"{d}/s*.jpg")):
        name = os.path.basename(f)[1:-4]                     # NNNNa / NNNNm / NNNNz
        out.setdefault(vid, {}).setdefault(str(int(name[:4])), []).append(dhash(f))
json.dump(out, open("analysis/phash.json", "w"))
print(sum(len(v) for v in out.values()), "shots hashed")
