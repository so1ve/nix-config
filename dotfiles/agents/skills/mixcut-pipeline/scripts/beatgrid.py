"""Build the bar/phrase grid for the BGM from a fixed-tempo fit.
Usage: python3 -I $S/beatgrid.py <audio> <out.json> [period phase]
Without period / phase (seconds) it searches constant grids at several multiples of the tracked tempo (1/2 .. 2x),
prints each candidate's onset score, keeps the best and writes <out>.click.wav (the song with a click on every beat).
Tempo multiples (78 vs 117 BPM, 110 vs 73) cannot be told apart reliably from onsets: have someone listen to the click
track, then rerun with the right period / phase."""
import json, sys
import numpy as np, librosa

audio, out = sys.argv[1:3]
y, sr = librosa.load(audio, sr=22050, mono=True)
if len(sys.argv) > 4:
    PERIOD, PHASE = float(sys.argv[3]), float(sys.argv[4])
else:                                                # comb search: the constant grid whose beats hit the most onset energy
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=128); efps = sr / 128
    def score(period, phase):
        n = int((len(env) / efps - phase) / period)
        idx = np.clip(np.round((phase + period * np.arange(n)) * efps).astype(int), 0, len(env) - 1)
        return env[idx].mean() / env.mean()
    def comb(p0):
        best = max((score(p, ph), p, ph) for p in np.arange(p0 * 0.97, p0 * 1.03, 0.0005) for ph in np.arange(0, p, 0.005))
        _, p1, ph1 = best
        return max([best] + [(score(p, ph), p, ph) for p in np.arange(p1 - 0.0006, p1 + 0.0006, 0.00002)
                             for ph in np.arange(ph1 - 0.006, ph1 + 0.006, 0.0005)])
    tempo = float(np.atleast_1d(librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=128)[0])[0])
    cands = sorted({round(tempo * r, 1) for r in (0.5, 2 / 3, 0.75, 1, 4 / 3, 1.5, 2) if 60 <= tempo * r <= 180})
    results = [(comb(60 / bpm), bpm) for bpm in cands]
    for (sc, p, ph), bpm in results:
        print(f"  tracker x {bpm / tempo:.2f}: {60 / p:7.2f} BPM, phase {ph % p:.3f}, onset on grid {sc:.2f}x mean")
    (_, PERIOD, PHASE), _ = max(results)
    PHASE %= PERIOD
    print(f"fitted {60 / PERIOD:.2f} BPM (period {PERIOD:.6f}, phase {PHASE:.3f})")
    from scipy.io import wavfile
    ticks = PHASE + PERIOD * np.arange(int((len(y) / sr - PHASE) / PERIOD) + 1)
    mixdown = 0.6 * y + 0.5 * librosa.clicks(times=ticks, sr=sr, length=len(y), click_freq=1500)
    click = out.rsplit(".", 1)[0] + ".click.wav"
    wavfile.write(click, sr, (np.clip(mixdown, -1, 1) * 32767).astype(np.int16))
    print(f"click track for checking by ear: {click}")
hop = 128; fps = sr / hop
S = np.abs(librosa.stft(y, hop_length=hop))
freqs = librosa.fft_frequencies(sr=sr)
low = librosa.onset.onset_strength(S=librosa.amplitude_to_db(S[freqs < 150]), sr=sr, hop_length=hop)
full = librosa.onset.onset_strength(S=librosa.amplitude_to_db(S), sr=sr, hop_length=hop)
dur = len(y) / sr
beats = PHASE + PERIOD * np.arange(int((dur - PHASE) / PERIOD) + 1)
def at(env, ts):
    fr = np.clip(np.round(ts * fps).astype(int), 0, len(env) - 1)
    return np.array([env[max(f-2, 0):f+3].max() for f in fr])
lo, fu = at(low, beats), at(full, beats)
drums = beats > (38 if PERIOD < 0.6 else 30)
bar_phase = int(np.argmax([lo[drums][(np.arange(len(beats))[drums] % 4) == p].mean() for p in range(4)]))
print("bar phase scores", [round(lo[drums][(np.arange(len(beats))[drums] % 4) == p].mean(), 3) for p in range(4)], "->", bar_phase)
# phrase phase (32 beats): crash/novelty on section starts -> chroma novelty between consecutive bars
chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=512)
mf = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=20, hop_length=512)
F = np.vstack([librosa.util.normalize(chroma, axis=0), librosa.util.normalize(mf, axis=1)])
bar_starts = beats[bar_phase::4]
bf = librosa.time_to_frames(bar_starts, sr=sr, hop_length=512)
B = librosa.util.sync(F, bf, aggregate=np.mean)[:, 1:len(bar_starts)]
nov = np.r_[0, np.linalg.norm(np.diff(B, axis=1), axis=0)]
ph8 = int(np.argmax([nov[p::8][3:40].mean() for p in range(8)]))
print("phrase phase scores", [round(nov[p::8][3:40].mean(), 3) for p in range(8)], "->", ph8)
phrases = bar_starts[ph8::8]
print("phrase starts:", [round(t, 2) for t in phrases])
json.dump(dict(period=PERIOD, phase=PHASE, bpm=60/PERIOD, duration=dur,
               beats=[round(float(t), 4) for t in beats], beat_low=[round(float(v), 3) for v in lo],
               beat_onset=[round(float(v), 3) for v in fu], bar_phase=bar_phase,
               bars=[round(float(t), 4) for t in bar_starts], phrase_bar_phase=ph8,
               phrases=[round(float(t), 4) for t in phrases], bar_novelty=[round(float(v), 3) for v in nov]),
          open(out, "w"), indent=0)
