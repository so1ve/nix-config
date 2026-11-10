"""Analyze the BGM: tempo, beats, downbeats, energy, structural sections.
Usage: python3 -I $S/music_analysis.py <audio> <out.json> <plot.png>"""
import json, sys
import numpy as np, librosa
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

path, out_json, out_png = sys.argv[1:4]
y, sr = librosa.load(path, sr=22050, mono=True)
dur = len(y) / sr
hop = 512

onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
tempo, beats = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr, hop_length=hop, units="frames")
beat_t = librosa.frames_to_time(beats, sr=sr, hop_length=hop)

# Downbeat phase: the beat-phase (mod 4) with the strongest low-frequency onset energy.
S = np.abs(librosa.stft(y, hop_length=hop))
low = librosa.onset.onset_strength(S=librosa.amplitude_to_db(S[:40]), sr=sr)
phase_score = [low[beats[p::4]].mean() for p in range(4)]
phase = int(np.argmax(phase_score))
downbeats = beat_t[phase::4]

rms = librosa.feature.rms(y=y, hop_length=hop)[0]
rms_t = librosa.frames_to_time(np.arange(len(rms)), sr=sr, hop_length=hop)
# Per-beat energy (dB) and onset strength
beat_rms = [float(20*np.log10(rms[b:b+int(sr/hop*0.5)].mean()+1e-9)) for b in beats]
beat_onset = [float(onset_env[b]) for b in beats]

# Structural segmentation on beat-synchronous chroma+mfcc
chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop)
mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, hop_length=hop)
feat = np.vstack([librosa.util.normalize(chroma), librosa.util.normalize(mfcc)])
sync = librosa.util.sync(feat, beats, aggregate=np.median)
k = max(6, int(dur // 20))
bounds = librosa.segment.agglomerative(sync, k)
bound_t = [float(beat_t[min(b, len(beat_t)-1)]) for b in bounds]

# Strong hits: onsets well above local median
peaks = librosa.util.peak_pick(onset_env, pre_max=8, post_max=8, pre_avg=40, post_avg=40, delta=onset_env.std()*1.2, wait=20)
hits = [float(t) for t in librosa.frames_to_time(peaks, sr=sr, hop_length=hop)]

res = dict(duration=dur, tempo=float(np.atleast_1d(tempo)[0]), beats=[float(t) for t in beat_t],
           downbeat_phase=phase, downbeats=[float(t) for t in downbeats], beat_db=beat_rms,
           beat_onset=beat_onset, sections=bound_t, hits=hits)
json.dump(res, open(out_json, "w"), indent=1)

fig, ax = plt.subplots(2, 1, figsize=(22, 7), sharex=True)
sm = np.convolve(rms, np.ones(80)/80, mode="same")
ax[0].plot(rms_t, 20*np.log10(sm+1e-9), lw=0.8)
ax[0].set_ylabel("RMS dB (smoothed)")
for t in bound_t: ax[0].axvline(t, color="r", lw=1)
ax[1].plot(librosa.frames_to_time(np.arange(len(onset_env)), sr=sr, hop_length=hop), onset_env, lw=0.4)
for t in hits: ax[1].axvline(t, color="g", lw=0.5, alpha=0.6)
for t in bound_t: ax[1].axvline(t, color="r", lw=1)
ax[1].set_xticks(np.arange(0, dur, 10)); ax[1].grid(axis="x", alpha=0.3)
ax[0].set_xticks(np.arange(0, dur, 10)); ax[0].grid(axis="x", alpha=0.3)
plt.tight_layout(); plt.savefig(out_png, dpi=80)
print(f"dur={dur:.2f}s tempo={res['tempo']:.2f} beats={len(beat_t)} phase={phase} scores={np.round(phase_score,2)}")
print("sections:", [round(t,1) for t in bound_t])
print("median beat interval:", np.median(np.diff(beat_t)))
