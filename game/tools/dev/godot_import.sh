#!/usr/bin/env bash
# Import new or changed assets (PNG, WAV, shaders) into the project.
# Several agents share this project: the lock makes sure only one import runs at a time.
#   bash tools/dev/godot_import.sh
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd -W 2>/dev/null || pwd)"
LOCK="${TMPDIR:-/tmp}/astropixel.import.lock"
for i in $(seq 1 240); do
  if mkdir "$LOCK" 2>/dev/null; then break; fi
  # a lock older than 4 minutes is stale (its owner died)
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +4 2>/dev/null)" ]; then rmdir "$LOCK" 2>/dev/null; fi
  sleep 1
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
"$GODOT" --headless --path "$PROJ" --import 2>&1 | grep -iE "^ERROR|SCRIPT ERROR|Parse Error" | grep -v "resources still in use" | head -20
echo "import done"
