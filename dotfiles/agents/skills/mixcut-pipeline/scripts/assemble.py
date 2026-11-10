"""Join one or more parts (build_part.py output, contiguous on the timeline) into the render EDL for render.py.
Usage: python3 -I $S/assemble.py <out.json> <music.wav> <part.json>...
No titles, labels or lyrics: the story is carried by the footage."""
import json, sys

out, music, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
parts = sorted((json.load(open(p)) for p in paths), key=lambda p: p["start"])
clips = [dict(c, group=p["group"]) for p in parts for c in p["clips"]]
for a, b in zip(clips, clips[1:]):
    assert abs(a["end"] - b["start"]) < 1.5e-3, f"gap or overlap between {a['group']} and {b['group']} at {a['end']}"
    b["start"] = a["end"]                          # make boundaries bit-identical
json.dump(dict(group=parts[0]["group"], music=music, clips=clips), open(out, "w"), ensure_ascii=False, indent=1)
print(f"{out}: {len(clips)} clips, {clips[0]['start']:.1f}-{clips[-1]['end']:.1f}s")
