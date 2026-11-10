"""Report visually near-identical clips in an EDL (across all its clips).  Usage: python3 -I $S/dupes.py <edl.json>... """
import json, sys
H = json.load(open("analysis/phash.json"))
def close(a, b, thr=40):          # 256-bit dHash distance and mean-colour distance
    return bin(a[0] ^ b[0]).count("1") <= thr and sum(abs(x - y) for x, y in zip(a[1], b[1])) <= 60
def similar(k1, k2):
    h1, h2 = H[k1[0]][str(k1[1])], H[k2[0]][str(k2[1])]
    return sum(close(a, b) for a in h1 for b in h2) >= 2
clips = []
for p in sys.argv[1:]:
    part = json.load(open(p))
    clips += [(part.get("group", p), k, c) for k, c in enumerate(part["clips"])]
n = 0
for x in range(len(clips)):
    for y in range(x + 1, len(clips)):
        (g1, i1, a), (g2, i2, b) = clips[x], clips[y]
        k1, k2 = (a["src"], a["shot"]), (b["src"], b["shot"])
        if k1 != k2 and similar(k1, k2):
            print(f"DUP {g1}#{i1} {k1} ~ {g2}#{i2} {k2}"); n += 1
print(n, "near-duplicate pair(s)")
