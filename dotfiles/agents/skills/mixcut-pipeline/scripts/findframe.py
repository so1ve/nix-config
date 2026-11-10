"""Find where a reference still (a screenshot from the user, a frame of the cut) occurs in videos.
Usage: python3 -I $S/findframe.py ref.png video...   -> best 4 matches per video as  time:score  (NCC, 1 = identical)
Compares the 2.39 centre band in greyscale at 4 fps, so letterbox and colour grade barely matter. Scores above ~0.85
are the same shot; below ~0.7 nothing in that video matches."""
import subprocess, sys
import numpy as np, cv2

W, H = 192, 80

def band(img):
    h, w = img.shape[:2]; bh = int(w / 2.39); y = (h - bh) // 2
    g = cv2.cvtColor(img[y:y + bh], cv2.COLOR_BGR2GRAY)
    g = cv2.resize(g, (W, H), interpolation=cv2.INTER_AREA).astype(np.float32)
    return (g - g.mean()) / (g.std() + 1e-6)

ref = band(cv2.imread(sys.argv[1]))
for v in sys.argv[2:]:
    w0, h0 = map(int, subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                               "stream=width,height", "-of", "csv=p=0", v]).decode().split(","))
    hh = round(h0 * 640 / w0 / 2) * 2
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-i", v, "-vf", f"fps=4,scale=640:{hh}", "-f", "rawvideo",
                          "-pix_fmt", "bgr24", "-"], stdout=subprocess.PIPE)
    res, i = [], 0
    while True:
        buf = p.stdout.read(640 * hh * 3)
        if len(buf) < 640 * hh * 3:
            break
        res.append((float((band(np.frombuffer(buf, np.uint8).reshape(hh, 640, 3)) * ref).mean()), i / 4)); i += 1
    res.sort(reverse=True)
    print(v.split("/")[-1], " ".join(f"{t:.2f}s:{s:.2f}" for s, t in res[:4]))
