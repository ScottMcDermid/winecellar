#!/usr/bin/env bash
# Launch the game previously recorded by `make install`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
require_game_name "$GAME_NAME"
require_wine

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"
LAUNCH_FILE="$(launch_file "$GAME_NAME")"

if [ ! -d "$PREFIX_DIR" ]; then
  echo "error: no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME" >&2
  exit 1
fi

if [ ! -f "$LAUNCH_FILE" ]; then
  echo "error: no launch target recorded for '$GAME_NAME'." >&2
  echo "Run: make install $GAME_NAME <path-to-exe>" >&2
  exit 1
fi

LAUNCH_EXE="$(cat "$LAUNCH_FILE")"

if [ ! -f "$LAUNCH_EXE" ]; then
  echo "error: recorded launch executable is missing: $LAUNCH_EXE" >&2
  exit 1
fi

echo "Launching '$GAME_NAME': $LAUNCH_EXE"
cd "$(dirname "$LAUNCH_EXE")"
WINEPREFIX="$PREFIX_DIR" wine "$LAUNCH_EXE"
