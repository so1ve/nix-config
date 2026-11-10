#!/bin/sh
# Run shot detection on every downloaded source not yet analyzed (4 at a time).
for f in src/*.mkv; do id=$(basename "$f" .mkv); [ -f "analysis/shots/$id.json" ] || echo "$f"; done |
  xargs -P 4 -n 1 -I{} python3 -I "$(dirname "$0")/shots.py" {} analysis
