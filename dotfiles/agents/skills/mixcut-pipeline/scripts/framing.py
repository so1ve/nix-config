"""Text-safe framing: keep burned-in subtitles (bottom ~12% of the picture) and corner lyrics (top ~9%, music-video
operator stories) out of the 2.39 band.  Usage: python3 -I $S/framing.py <edl.json>...   (rewrites clips in place)"""
import json, sys

import os
# sources whose picture carries text at the top as well as subtitles at the bottom (music videos with lyrics):
# one id per line in catalog/top_text.txt
TOP_TEXT = {l.split("#")[0].strip() for l in open("catalog/top_text.txt")} - {""} if os.path.exists("catalog/top_text.txt") else set()
BOTTOM, TOP = 0.12, 0.09
_meta, _ratio = {}, {}

def _load(src):
    if src not in _meta:
        _meta[src] = json.load(open(f"analysis/shots/{src}.json"))
        tp = f"analysis/tags/{src}.json"
        if not os.path.exists(tp):                     # untagged: assume burned-in subtitles and keep them out
            _ratio[src] = 1.0; return
        u = [t for t in json.load(open(tp))["shots"] if t.get("use")]
        _ratio[src] = sum(t.get("text") in ("subtitle", "small") for t in u) / max(1, len(u))

def text_safe(c):
    """Adjust c['zoom'] / c['pos_y'] in place; return True if changed."""
    src = c["src"]; _load(src)
    cw, ch = _meta[src]["crop"][:2]
    wide = cw / ch > 2.2                            # already ~2.39: cropping needs zoom
    sixteen_nine = cw / ch < 1.9                    # 16:9: the crop is free (no zoom), so apply it everywhere
    if _ratio[src] < 0.02 and not sixteen_nine and src not in TOP_TEXT:
        return False                                # text-free non-16:9 source: leave untouched
    base_h = max(1920 / cw, 804 / ch) * ch
    both = src in TOP_TEXT
    def cuts(z, py):
        hs = base_h * z; y0 = (hs - 804) * py
        return y0 / hs, 1 - (y0 + 804) / hs
    if both:
        py = TOP / (TOP + BOTTOM)                   # split the crop between both edges
    else:
        py = min(c.get("pos_y", 0.5), 0.2 if not wide else 0.05)
    z = 1.0
    while z < 1.35:
        top, bot = cuts(z, py)
        if bot >= BOTTOM and (not both or top >= TOP): break
        z = round(z + 0.01, 2)
    new = (round(z, 2), round(py, 3))
    old = (c.get("zoom", 1.0), c.get("pos_y", 0.5))
    if new == old: return False
    c["zoom"], c["pos_y"] = new
    return True

if __name__ == "__main__":
    for p in sys.argv[1:]:
        d = json.load(open(p))
        n = sum(text_safe(c) for c in d["clips"])
        json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
        print(f"{p}: reframed {n}/{len(d['clips'])} clips")
