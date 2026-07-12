#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_STORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCREENSHOTS_DIR="$APP_STORE_DIR/Screenshots"
OUTPUT="$SCRIPT_DIR/Pomo-App-Preview-6.9.mp4"
FFMPEG="${FFMPEG:-/Users/art/.local/bin/ffmpeg}"

# App Store Connect accepts 886 x 1920 for a portrait 6.9-inch App Preview.
# Four six-second scenes with 0.65-second crossfades produce a 22.05-second film.
"$FFMPEG" -y \
  -loop 1 -framerate 30 -t 6 -i "$SCREENSHOTS_DIR/01-focus-with-intention.png" \
  -loop 1 -framerate 30 -t 6 -i "$SCREENSHOTS_DIR/02-make-time-yours.png" \
  -loop 1 -framerate 30 -t 6 -i "$SCREENSHOTS_DIR/03-momentum-in-view.png" \
  -loop 1 -framerate 30 -t 6 -i "$SCREENSHOTS_DIR/04-build-your-rhythm.png" \
  -f lavfi -t 22.05 -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
  -filter_complex "\
    [0:v]crop=1320:2860:0:4,zoompan=z='1+0.012*on/179':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=886x1920:fps=30,fps=30,settb=AVTB,format=yuv420p[v0];\
    [1:v]crop=1320:2860:0:4,zoompan=z='1.012-0.012*on/179':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=886x1920:fps=30,fps=30,settb=AVTB,format=yuv420p[v1];\
    [2:v]crop=1320:2860:0:4,zoompan=z='1+0.012*on/179':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=886x1920:fps=30,fps=30,settb=AVTB,format=yuv420p[v2];\
    [3:v]crop=1320:2860:0:4,zoompan=z='1.012-0.012*on/179':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=886x1920:fps=30,fps=30,settb=AVTB,format=yuv420p[v3];\
    [v0][v1]xfade=transition=fade:duration=0.65:offset=5.35[x1];\
    [x1][v2]xfade=transition=fade:duration=0.65:offset=10.70[x2];\
    [x2][v3]xfade=transition=fade:duration=0.65:offset=16.05,format=yuv420p[v]" \
  -map "[v]" -map 4:a \
  -c:v libx264 -preset slow -profile:v high -level:v 4.0 \
  -b:v 10M -maxrate 12M -bufsize 20M -r 30 \
  -c:a aac -b:a 256k -ar 48000 -ac 2 \
  -t 22.05 -movflags +faststart \
  "$OUTPUT"

echo "$OUTPUT"
