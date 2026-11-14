#!/usr/bin/env bash
# Plays one whole mission by itself, from the launch pad to the report, and prints each screen and the result.
#   bash tools/dev/e2e.sh <dest> <task 0|1|2> <out.png> [timeout_s]
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd -W 2>/dev/null || pwd)"
dest="$1"; task="$2"; out="$3"; to="${4:-240}"
timeout "$to" "$GODOT" --audio-driver Dummy --path "$PROJ" --position -4000,-4000 --resolution 640x360 -- screen=launch dest="$dest" task="$task" auto=1 shot="$out" 2>&1 \
  | grep -E "^SCREEN|^RESULT|SCRIPT ERROR|Parse Error|^ERROR|^   at: .*\.gd" | grep -v "resources still in use\|ObjectDB instances" | tr '\n' '|'
echo " [$dest $task exit ${PIPESTATUS[0]}]"
