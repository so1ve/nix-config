"""Validate EDL part(s) against the beat grid (1/8-beat steps), shot bounds, banned shots and sources, and reuse
(the same source frames shown twice, within a part or across the parts of one cut).
Bans (src, shot, reason; shot "*" bans a whole source) come from catalog/banned.tsv, which applies to every cut, plus
the lists a part names under "banned" (cut-specific rules, e.g. "main story only").
Usage: python3 -I $S/edl_check.py <part.json>...   (exit 1 on errors)"""
import glob, json, os, sys

FPS, EPS = 60, 0.0015
def bans(path):
    return {(l.split("\t")[0], l.split("\t")[1]): l.rstrip("\n").split("\t")[2]
            for l in open(path) if l.strip() and not l.startswith("#")}
GLOBAL_BANS = bans("catalog/banned.tsv") if os.path.exists("catalog/banned.tsv") else {}
fixed = {0.0}                                        # part starts and ends may sit off the grid
def on_grid(t, PERIOD, PHASE):
    k = (t - PHASE) / (PERIOD / 8)
    return abs(k - round(k)) * PERIOD / 8 < EPS or any(abs(t - f) < EPS for f in fixed)
shots_cache, tags_cache = {}, {}
def shot(src, i):
    if src not in shots_cache:
        shots_cache[src] = json.load(open(f"analysis/shots/{src}.json"))["shots"]
        tp = f"analysis/tags/{src}.json"               # optional vision tags
        tags_cache[src] = {t["i"]: t for t in json.load(open(tp))["shots"]} if os.path.exists(tp) else {}
    return shots_cache[src][i], tags_cache[src].get(i, {})

def span(c):
    """Source seconds clip c plays: (in, end)."""
    sp, r, dur = c.get("speed", 1.0), c.get("ramp"), c["end"] - c["start"]
    played = c["freeze"]["at"] if c.get("freeze") else dur
    return c["in"], c["in"] + (sp * r["at"] + r["to"] * (played - r["at"]) if r else played * sp)
def overlap(a, b): return min(a[1], b[1]) - max(a[0], b[0]) > 0.05

errors, warns = [], []
others = {}
for p in glob.glob(os.path.join(os.path.dirname(sys.argv[1]), "*.json")):   # reuse check within the same cut
    if p in sys.argv[1:]: continue
    try:
        g = json.load(open(p))
        if not isinstance(g, dict) or g.get("group") in {json.load(open(a)).get("group") for a in sys.argv[1:]}:
            continue                                # cards list or an assembled copy of the same cut
        for c in g["clips"]: others.setdefault(c["src"], []).append((span(c), g.get("group")))
    except (ValueError, KeyError, TypeError):
        print(f"WARN  {p} is unreadable (being written?) - skipped for reuse check")
for path in sys.argv[1:]:
    part = json.load(open(path)); clips = part["clips"]; g = part.get("group", path)
    grid = dict(PERIOD=part["period"], PHASE=part["phase"])   # written by build_part.py
    BANNED = dict(GLOBAL_BANS)
    for b in part.get("banned", []):              # a listed file must exist
        BANNED.update(bans(b))
    fixed |= {round(part["start"], 4), round(part["end"], 4)}
    if abs(clips[0]["start"] - part["start"]) > EPS: errors.append(f"{g}: first clip starts {clips[0]['start']} != part start {part['start']}")
    if abs(clips[-1]["end"] - part["end"]) > EPS: errors.append(f"{g}: last clip ends {clips[-1]['end']} != part end {part['end']}")
    seen = {}
    for k, c in enumerate(clips):
        tag = f"{g} clip {k} ({c['start']:.4f}-{c['end']:.4f} {c['src']}#{c['shot']})"
        if k and abs(c["start"] - clips[k - 1]["end"]) > EPS: errors.append(f"{tag}: not contiguous with previous end {clips[k-1]['end']}")
        for t in (c["start"], c["end"]):
            if not on_grid(t, **grid): errors.append(f"{tag}: {t} is not on the 1/8-beat grid")
        dur = c["end"] - c["start"]
        if dur < grid["PERIOD"] / 8 - EPS: errors.append(f"{tag}: shorter than 1/8 beat")
        sp = c.get("speed", 1.0)
        if not 0.25 <= sp <= 2.0: errors.append(f"{tag}: speed {sp} outside 0.25-2.0")
        try:
            s, t = shot(c["src"], c["shot"])
        except (FileNotFoundError, IndexError):
            errors.append(f"{tag}: unknown source/shot"); continue
        if t.get("use") is False: warns.append(f"{tag}: tagged use=false ({t.get('why')})")
        # shots were detected on 30 fps samples of 60 fps sources: the detected start is always inside the new shot,
        # the true next cut can be up to 1/60 s before the detected end
        lo, hi = s["start"] - 0.001, s["end"] - 1 / 60 + 0.001
        rng = span(c); src_end = rng[1]
        if c["in"] < lo - 1e-6 or src_end > hi + 1e-6:
            errors.append(f"{tag}: source range {c['in']:.3f}-{src_end:.3f} leaves shot "
                          f"[{s['start']:.3f},{s['end']:.3f}] (usable {lo:.3f}-{hi:.3f})")
        why = BANNED.get((c["src"], str(c["shot"]))) or BANNED.get((c["src"], "*"))
        if why: errors.append(f"{tag}: banned ({why})")
        if not 0 <= c.get("pos_y", 0.5) <= 1: errors.append(f"{tag}: pos_y out of range")
        if c.get("punch", 0) > 0.15 or c.get("flash", 0) > 0.5: errors.append(f"{tag}: punch/flash too strong")
        again = [j for j, r2 in seen.get(c["src"], []) if overlap(rng, r2)]
        if again: errors.append(f"{tag}: source frames already shown by clip {again[0]}")
        seen.setdefault(c["src"], []).append((k, rng))
        used = [grp for r2, grp in others.get(c["src"], []) if overlap(rng, r2)]
        if used: errors.append(f"{tag}: source frames already used by group {used[0]}")
        if t.get("text") == "big": warns.append(f"{tag}: shot has big on-screen text")
    n = len(clips); length = part["end"] - part["start"]
    print(f"{g}: {n} clips over {length:.2f}s (avg {length/n:.2f}s)")
for w in warns: print("WARN ", w)
for e in errors: print("ERROR", e)
print("OK" if not errors else f"{len(errors)} error(s)")
sys.exit(1 if errors else 0)
