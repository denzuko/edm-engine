#!/bin/sh
set -e
pkill -9 -f Xvfb 2>/dev/null || true
pkill -9 -f ffmpeg 2>/dev/null || true
sleep 1
rm -f /tmp/.X11-unix/X99 /tmp/.X99-lock

setsid Xvfb :99 -screen 0 1024x768x24 +extension XKEYBOARD > /home/claude/scratch/xvfb-run.log 2>&1 < /dev/null &
sleep 2

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1

# $1 = lisp script to run, $2 = window title to wait for, $3 = output webm path
LISP_SCRIPT="$1"
WINDOW_TITLE="$2"
OUT_WEBM="$3"

setsid sbcl --non-interactive \
  --load /home/claude/quicklisp/setup.lisp \
  --load "$LISP_SCRIPT" \
  > /home/claude/scratch/record-run.log 2>&1 < /dev/null &
SBCL_PID=$!

echo "waiting for window..."
i=0
while [ $i -lt 60 ]; do
  if xdotool search --name "$WINDOW_TITLE" > /dev/null 2>&1; then
    echo "window found after ${i}s"
    break
  fi
  sleep 1
  i=$((i+1))
done

echo "starting ffmpeg recording (no fixed duration)"
setsid ffmpeg -y -f x11grab -video_size 1024x768 -framerate 20 -i :99.0 \
  -c:v libvpx -crf 24 -b:v 1200k "$OUT_WEBM" \
  > /home/claude/scratch/ffmpeg-run.log 2>&1 < /dev/null &
FFMPEG_PID=$!

# event-based stop: wait for the actual sbcl process to exit (window closed /
# script finished), THEN signal ffmpeg to finalize — not a guessed duration
wait $SBCL_PID 2>/dev/null || true
echo "sbcl finished — stopping ffmpeg"
kill -INT $FFMPEG_PID 2>/dev/null || true
wait $FFMPEG_PID 2>/dev/null || true
echo "done"
ls -la "$OUT_WEBM"
# Usage: tools/record-playthrough.sh <lisp-script> <window-title> <output.webm>
# Requires Xvfb, xdotool, ffmpeg installed. See docs/render-smoke-test.md
# for the raylib/GLX setup this depends on.
