"""Per-bar loudness and band energies of a song on its fixed beat grid, to find intro / verse / chorus / break / drop
and where the music actually dies away. Usage: python3 -I $S/song_energy.py music/warriors.wav analysis/grid_warriors.json"""
import json, sys
import numpy as np, librosa
y, sr = librosa.load(sys.argv[1], sr=22050, mono=True)
g = json.load(open(sys.argv[2]))
hop = 512
S = np.abs(librosa.stft(y, hop_length=hop)) ** 2
f = librosa.fft_frequencies(sr=sr)
t = librosa.frames_to_time(np.arange(S.shape[1]), sr=sr, hop_length=hop)
bands = {"sub": (20, 120), "low": (120, 500), "voc": (500, 3000), "hi": (3000, 10000)}
bars = g["bars"] + [g["duration"]]
pre = [0.0] + [g["bars"][0]]
rows = []
edges = [0.0] + bars
for a, b in zip(edges, edges[1:]):
    m = (t >= a) & (t < b)
    tot = 10 * np.log10(S[:, m].sum(axis=0).mean() + 1e-9)
    e = {k: 10 * np.log10(S[(f >= lo) & (f < hi)][:, m].sum(axis=0).mean() + 1e-9) for k, (lo, hi) in bands.items()}
    rows.append((a, b, tot, e))
ref = max(r[2] for r in rows)
for i, (a, b, tot, e) in enumerate(rows):
    bar = "#" * int(max(0, tot - ref + 30))
    print(f"bar{i - 1:3d} {a:7.2f}-{b:7.2f} {tot - ref:6.1f}dB sub{e['sub'] - ref:6.1f} voc{e['voc'] - ref:6.1f} hi{e['hi'] - ref:6.1f} {bar}")
