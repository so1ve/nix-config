"""Build an EDL part from a beat-length spec.  Usage: python3 -I $S/build_part.py <spec.json>
Spec: {"group": "cut", "grid": "analysis/grid_song.json", "out": "edl/cut.json", "music": "music/song.wav",
       "start_beat": 0, "start", "end", "clips": [[beats, src, shot, off, speed, {fx}], ...]}
grid is the song's beat grid (beatgrid.py), out the part file to write; music is read by make_cut.sh; banned lists
extra ban files for this cut on top of catalog/banned.tsv (checked by edl_check.py); start / end
override the first clip's start and the last clip's end. beats may be fractional (down to 1/8 beat for a rapid montage).
off places the clip in its shot: seconds from the shot start, or, with shot null, an absolute source time (read off
a strip; the shot containing it is looked up); "peak" puts the shot's strongest motion and "flash" its
brightest frame (analysis/motion) at `land` beats into the clip (fx key, default 0: on the cut); null centres the
clip in the shot. fx are render.py clip keys plus note and land. The source range is kept inside the shot."""
import json, math, sys
spec = json.load(open(sys.argv[1]))
grid = json.load(open(spec["grid"]))
PERIOD, PHASE = grid["period"], grid["phase"]
def t(b): return round(PHASE + PERIOD * b, 4)
def src_len(speed, fx, dur):                         # source seconds a clip of this length consumes
    r, fz = fx.get("ramp"), fx.get("freeze")
    assert not (r and fz), "ramp cannot combine with freeze"
    if fz: dur = fz["at"]
    return speed * min(dur, r["at"]) + r["to"] * max(0.0, dur - r["at"]) if r else speed * dur
def peak_time(src, s, kind):
    """Seconds from the shot start of its strongest motion (or brightest frame), smoothed over 3 samples."""
    m = json.load(open(f"analysis/motion/{src}.json"))
    a, b = math.ceil(s["start"] * m["fps"]) + 2, int(s["end"] * m["fps"]) - 2
    v = m["mag" if kind == "peak" else "luma"][a:b + 1]
    if not v: return s["dur"] / 2
    sm = [sum(v[max(0, i - 1):i + 2]) / len(v[max(0, i - 1):i + 2]) for i in range(len(v))]
    return (a + max(range(len(sm)), key=sm.__getitem__)) / m["fps"] - s["start"]
rows = [(r[:5], r[5] if len(r) > 5 else {}) for r in spec["clips"]]
clips, b = [], spec["start_beat"]
for k, ((beats, src, shot, off, speed), fx) in enumerate(rows):
    shots = json.load(open(f"analysis/shots/{src}.json"))["shots"]
    if shot is None:                                 # off is an absolute source time
        shot = next(x["i"] for x in shots if x["start"] <= off < x["end"])
        off -= shots[shot]["start"]
    s = shots[shot]
    start, end = t(b), t(b + beats)
    if k == 0: start = spec.get("start", start)
    if k == len(rows) - 1: end = spec.get("end", end)
    need = src_len(speed, fx, end - start)
    if off in ("peak", "flash"):
        off = peak_time(src, s, off) - src_len(speed, {k: v for k, v in fx.items() if k == "ramp"}, fx.get("land", 0) * PERIOD)
    elif off is None:
        off = (s["dur"] - need) / 2
    lo, hi = 0.0, s["dur"] - 1 / 60 - need
    if hi < lo:
        raise SystemExit(f"{spec['group']} clip {k} {src}#{shot}: needs {need:.3f}s of a {s['dur']:.3f}s shot")
    off = min(max(off, lo), hi)
    c = {"start": start, "end": end, "src": src, "shot": shot, "in": math.floor((s["start"] + off) * 1000) / 1000, "speed": speed}
    c.update({k: v for k, v in fx.items() if k != "land"})
    c.setdefault("note", "")
    clips.append(c); b += beats
part = {"group": spec["group"], "start": clips[0]["start"], "end": clips[-1]["end"], "period": PERIOD, "phase": PHASE,
        "banned": spec.get("banned", []),
        "clips": clips}
out = spec["out"]
json.dump(part, open(out, "w"), ensure_ascii=False, indent=1)
print(f"{spec['group']}: {len(clips)} clips, beats {spec['start_beat']}..{b}, {part['start']}-{part['end']} -> {out}")
