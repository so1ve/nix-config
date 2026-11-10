#!/bin/sh
# Usage: $S/env.sh <cmd...>  — runs cmd with ffmpeg, yt-dlp, deno and python(librosa, opencv)
exec nix shell --impure --expr 'with import <nixpkgs> {}; [ yt-dlp ffmpeg-full deno (python3.withPackages (p: [p.librosa p.numpy p.scipy p.opencv4 p.pillow p.matplotlib])) ]' -c "$@"
