"""Read a source quickly: group its detected shots into scenes and find footage it shares with other sources.
Usage: python3 -I $S/scenes.py <id>...   (needs analysis/shots, analysis/thumbs and analysis/phash.json)
Writes analysis/scenes/<id>.json and sheets analysis/scenes/<id>_NN.jpg, one row per scene (the middle frame of each
shot, at most ten). When catalog/scenes/<id>.md does not exist yet it writes a skeleton there, one row per scene with
the time range and the marks below; scene, people and the verdict are filled in after looking at the sheets.
Marks:
  黑场 / 白闪          the shot is (nearly) a black or white frame: separator, logo card or flash
  #i 同 <src>#<j>      near-identical frames in another source or in a non-adjacent shot of this one: trailers reuse
                       cutscenes, cutscenes replay their opening. Using both shows the same picture twice.
Scenes are a hint: adjacent shots join while their colour stays close to one of the scene's last three shots.
Subtitles and interface graphics are too small to detect on thumbnails; look for them on the sheets."""
import json, os, subprocess, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

SAME_SCENE = 0.62     # Bhattacharyya distance between HSV histograms (start, middle and end thumbnails)
TW = 384              # thumbnail width (shots.py)

footage = {l.split("\t")[0]: l.rstrip("\n").split("\t")[3] for l in open("catalog/footage.tsv")
           if l.strip() and not l.startswith("#")}
hashes = json.load(open("analysis/phash.json"))
owners = [(v, int(i)) for v in hashes for i in hashes[v] for _ in hashes[v][i]]
keys = sorted(set(owners)); key_n = {k: n for n, k in enumerate(keys)}
owner = np.array([key_n[k] for k in owners])
def bits(h): return np.frombuffer(int(h[0]).to_bytes(32, "big"), np.uint8)
all_bits = np.stack([bits(h) for v in hashes for i in hashes[v] for h in hashes[v][i]])
all_rgb = np.array([h[1] for v in hashes for i in hashes[v] for h in hashes[v][i]])
INFO = 48             # a hash with fewer set bits is a flat frame (dark, white, fog) that looks like every other one
all_info = np.unpackbits(all_bits, axis=1).sum(1) >= INFO

def same_footage(vid, i):
    """Shots elsewhere showing the same picture: candidates have two close thumbnail hashes (the dupes.py rule), and a
    candidate counts when the greyscale pictures themselves correlate (as findframe.py compares)."""
    count = np.zeros(len(keys), int)
    for h in hashes[vid][str(i)]:
        if bin(h[0]).count("1") < INFO:
            continue
        close = all_info & (np.unpackbits(all_bits ^ bits(h), axis=1).sum(1) <= 40) & (np.abs(all_rgb - h[1]).sum(1) <= 60)
        np.add.at(count, owner[close], 1)
    mine = bands(vid, i)
    return [keys[n] for n in np.flatnonzero(count >= 2) if (keys[n][0] != vid or abs(keys[n][1] - i) > 2)
            and max(float((a * b).mean()) for a in mine for b in bands(*keys[n])) >= 0.8]

metas = {}
def bands(vid, i):
    """Normalised greyscale centre band of each thumbnail of shot i: letterbox and grade barely matter."""
    meta = metas.setdefault(vid, json.load(open(f"analysis/shots/{vid}.json")))
    out = []
    for t in thumbs(vid, meta, i):
        h, w = t.shape[:2]; bh = min(h, round(w / 2.39)); y = (h - bh) // 2
        g = cv2.resize(cv2.cvtColor(t[y:y + bh], cv2.COLOR_BGR2GRAY), (96, 40), interpolation=cv2.INTER_AREA).astype(np.float32)
        out.append((g - g.mean()) / (g.std() + 1e-6))
    return out

def thumbs(vid, meta, i):
    """Start, middle and end thumbnails of shot i, cut to the active picture."""
    k = TW / meta["width"]; cw, ch, cx, cy = meta["crop"]
    cw, ch = min(cw, meta["width"] - cx), min(ch, meta["height"] - cy)
    x0, y0 = round(cx * k), round(cy * k)
    return [cv2.imread(f"analysis/thumbs/{vid}/s{i:04d}{t}.jpg")[y0:y0 + round(ch * k), x0:x0 + round(cw * k)] for t in "amz"]

def hist(th):
    h = cv2.calcHist([cv2.cvtColor(t, cv2.COLOR_BGR2HSV) for t in th], [0, 1, 2], None, [16, 4, 4], [0, 180, 0, 256, 0, 256])
    return cv2.normalize(h, None).astype(np.float32)

font = ImageFont.truetype(subprocess.check_output(["fc-match", "Noto Sans CJK SC", "-f", "%{file}"]).decode(), 13, index=2)
for vid in sys.argv[1:]:
    meta = json.load(open(f"analysis/shots/{vid}.json"))
    shots = []
    for s in meta["shots"]:
        th = thumbs(vid, meta, s["i"])
        g = [cv2.cvtColor(t, cv2.COLOR_BGR2GRAY) for t in th]
        mark = "黑场" if max(x.mean() for x in g) < 14 else "白闪" if min(x.mean() for x in g) > 215 else ""
        shots.append(dict(i=s["i"], start=s["start"], end=s["end"], mark=mark,
                          same=[f"{v}#{j}" for v, j in same_footage(vid, s["i"])], hist=hist(th), mid=th[1]))
    scenes = []
    for s in shots:
        cur = scenes[-1] if scenes else None
        if cur and not s["mark"] and not cur[0]["mark"] and \
                min(cv2.compareHist(s["hist"], o["hist"], cv2.HISTCMP_BHATTACHARYYA) for o in cur[-3:]) < SAME_SCENE:
            cur.append(s)
        else:
            scenes.append([s])
    def note(sc):
        return "；".join(([sc[0]["mark"]] if sc[0]["mark"] else []) + [f"#{s['i']} 同 {'、'.join(s['same'])}" for s in sc if s["same"]])
    rows = [dict(start=sc[0]["start"], end=sc[-1]["end"], shots=[s["i"] for s in sc], note=note(sc)) for sc in scenes]
    os.makedirs("analysis/scenes", exist_ok=True)
    json.dump(dict(id=vid, scenes=rows), open(f"analysis/scenes/{vid}.json", "w"), ensure_ascii=False, indent=1)

    CW, PER = 150, 20                                         # cell width, scenes per sheet
    ch = round(CW * shots[0]["mid"].shape[0] / shots[0]["mid"].shape[1])
    for p in range(0, len(scenes), PER):
        part = list(zip(scenes[p:p + PER], rows[p:p + PER]))
        sheet = Image.new("RGB", (10 * CW, len(part) * (ch + 18)), (20, 20, 20)); d = ImageDraw.Draw(sheet)
        for q, (sc, r) in enumerate(part):
            pick = [sc[round(j * (len(sc) - 1) / 9)] for j in range(10)] if len(sc) > 10 else sc
            y = q * (ch + 18)
            for k, s in enumerate(pick):
                sheet.paste(Image.fromarray(cv2.cvtColor(s["mid"], cv2.COLOR_BGR2RGB)).resize((CW, ch)), (k * CW, y + 18))
            d.text((3, y + 1), f"S{p + q}  {r['start']:.2f}–{r['end']:.2f}  #{r['shots'][0]}–#{r['shots'][-1]}  {r['note']}",
                   fill=(255, 220, 0), font=font)
        sheet.save(f"analysis/scenes/{vid}_{p // PER:02d}.jpg", quality=82)

    md = f"catalog/scenes/{vid}.md"
    if not os.path.exists(md):
        os.makedirs("catalog/scenes", exist_ok=True)
        lines = [f"# {vid} · {footage.get(vid, '')}", "",
                 f"{meta['duration']:.1f} s，{meta['fps']:g} fps 文件。（补：真实帧率、字幕和界面图形、主线还是角色剧情）", "",
                 "| 时间 | 场景 | 人物 | 可用性 |", "|---|---|---|---|"]
        lines += [f"| {r['start']:.2f}–{r['end']:.2f} |  |  | {r['note']} |" for r in rows]
        open(md, "w").write("\n".join(lines) + "\n")
    print(f"{vid}: {len(shots)} shots -> {len(rows)} scenes, {sum(bool(s['same']) for s in shots)} shots with shared footage")
