#!/bin/sh
# Download one official video (YouTube id) at <=1920px wide, 60fps preferred, into src/<id>.mkv
exec yt-dlp -q --no-progress -S "fps,vcodec:vp9" -f "bv*[width<=1920]+ba/b[width<=1920]" \
  --merge-output-format mkv -o "src/%(id)s.%(ext)s" --download-archive catalog/downloaded.txt \
  "https://www.youtube.com/watch?v=$1"
