#!/usr/bin/env bash
# Run one screen of the game off-screen and save a 640x360 screenshot.
#   bash tools/dev/shot.sh <screen> <dest> <out.png> [wait_seconds] [extra key=value args...]
# screen: menu | builder | flight | landing | surface | probe | report      dest: moon | mars | saturn
# extra args are passed to the game's debug hook (scripts/main.gd), e.g.  call=debug_night  mode=home
# Prints script errors if there are any. Imports new assets first (locked, safe to call in parallel).
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
screen="$1"; dest="$2"; out="$3"; wait="${4:-1.5}"; shift 4 2>/dev/null
bash "$PROJ/tools/dev/godot_import.sh" >/dev/null
"$GODOT" --audio-driver Dummy --path "$PROJ" --position -4000,-4000 --resolution 640x360 -- screen="$screen" dest="$dest" shot="$out" wait="$wait" "$@" 2>&1 \
  | grep -E "SCRIPT ERROR|Parse Error|^ERROR|^   at: .*\.gd" | grep -v "resources still in use\|ObjectDB instances" | head -20
[ -f "$out" ] && echo "saved $out" || echo "NO SCREENSHOT (the game did not reach the capture point)"
