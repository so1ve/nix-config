#!/bin/sh
# Build, check and render one cut from its beat spec (run from the project root):
#   make_cut.sh <spec.json> <out.mp4> [render.py flags: --draft, --clips-only]
# spec -> part (build_part.py) -> text-safe framing -> grid / bounds / banned / reuse check -> duplicate report
# -> render EDL next to the part (<part>.render.json, with the spec's "music") -> render.py
set -e
S=$(dirname "$0")
spec=$1; out=$2; shift 2
part=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["out"])' "$spec")
music=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["music"])' "$spec")
python3 -I "$S/build_part.py" "$spec"
python3 -I "$S/framing.py" "$part"
python3 -I "$S/edl_check.py" "$part"
python3 -I "$S/dupes.py" "$part" | tail -5
python3 -I "$S/assemble.py" "${part%.json}.render.json" "$music" "$part"
python3 -I "$S/render.py" "${part%.json}.render.json" "$out" "$@"
