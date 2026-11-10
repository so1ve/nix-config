"""Compact contact sheet: one mid frame per shot, from analysis/thumbs. Usage: python3 -I $S/shotsheet.py out_dir src [src...]
-> out_dir/<src>_NN.jpg, 6 columns x 8 rows, label '#i start dur' (red label = tagged unusable)."""
import json, sys, os
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]; font = ImageFont.load_default(size=15)
CW, CH, LH, COLS, ROWS = 320, 134, 18, 6, 8
for src in sys.argv[2:]:
    shots = json.load(open(f"analysis/shots/{src}.json"))["shots"]
    tp = f"analysis/tags/{src}.json"                   # optional vision tags; untagged shots count as usable
    tags = {t["i"]: t for t in json.load(open(tp))["shots"]} if os.path.exists(tp) else {}
    per = COLS * ROWS
    for p in range(0, len(shots), per):
        chunk = shots[p:p + per]; rows = (len(chunk) + COLS - 1) // COLS
        sheet = Image.new("RGB", (COLS * CW, rows * (CH + LH)), (24, 24, 24)); d = ImageDraw.Draw(sheet)
        for q, s in enumerate(chunk):
            x, y = (q % COLS) * CW, (q // COLS) * (CH + LH)
            im = Image.open(f"analysis/thumbs/{src}/s{s['i']:04d}m.jpg").convert("RGB")
            w, h = im.size; th = round(w / 2.39)
            im = im.crop((0, (h - th) // 2, w, (h - th) // 2 + th)).resize((CW - 4, CH - 2))
            sheet.paste(im, (x + 2, y + LH))
            ok = tags.get(s["i"], {}).get("use", True)
            d.text((x + 3, y + 1), f"#{s['i']} {s['start']:.1f}s {s['dur']:.1f}", fill=(255, 220, 0) if ok else (255, 90, 90), font=font)
        sheet.save(f"{out}/{src}_{p // per:02d}.jpg", quality=82)
        print(f"{out}/{src}_{p // per:02d}.jpg")
