#!/usr/bin/env bash
# Launch the game previously recorded by `make install`, nested inside
# gamescope. Optionally launch a different executable inside the same
# prefix instead, without touching the recorded launch target.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
EXE_OVERRIDE="${2:-}"
require_game_name "$GAME_NAME"
require_wine
require_jq

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

if [ -n "$EXE_OVERRIDE" ]; then
  if [ ! -f "$EXE_OVERRIDE" ]; then
    die "executable not found: $EXE_OVERRIDE"
  fi
  LAUNCH_EXE="$(cd "$(dirname "$EXE_OVERRIDE")" && pwd)/$(basename "$EXE_OVERRIDE")"
else
  LAUNCH_EXE="$(config_get "$GAME_NAME" launch)"

  if [ -z "$LAUNCH_EXE" ]; then
    log_error "no launch target recorded for '$GAME_NAME'."
    echo "Run: make install $GAME_NAME <path-to-exe>" >&2
    exit 1
  fi

  if [ ! -f "$LAUNCH_EXE" ]; then
    die "recorded launch executable is missing: $LAUNCH_EXE"
  fi
fi

# Games get gamescope on by default; override with NO_GAMESCOPE=1.
launch_exe "$GAME_NAME" "$LAUNCH_EXE" 0 "$(bold "$GAME_NAME")"
