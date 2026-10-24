#!/usr/bin/env bash
# Launch the game previously recorded by `make install`, nested inside
# gamescope by default. Optionally launch a different executable inside the
# same prefix instead (without touching the recorded launch target); that
# case defaults to gamescope OFF, since a one-off exe is usually a tool or
# installer rather than the game itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
EXE_OVERRIDE="${2:-}"
require_game_name "$GAME_NAME"
check_deps wine jq

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

if [ -n "$EXE_OVERRIDE" ]; then
  if [ ! -f "$EXE_OVERRIDE" ]; then
    die "executable not found: $EXE_OVERRIDE"
  fi
  LAUNCH_EXE="$(cd "$(dirname "$EXE_OVERRIDE")" && pwd)/$(basename "$EXE_OVERRIDE")"
  # An explicit exe (e.g. `make run <game> <file>`) is usually a one-off
  # tool/installer rather than the game itself, so gamescope defaults OFF;
  # override with NO_GAMESCOPE=0.
  DEFAULT_NO_GAMESCOPE=1
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

  # The recorded launch target (`make run <game>`) gets gamescope on by
  # default; override with NO_GAMESCOPE=1.
  DEFAULT_NO_GAMESCOPE=0
fi

launch_exe "$GAME_NAME" "$LAUNCH_EXE" "$DEFAULT_NO_GAMESCOPE" "$(bold "$GAME_NAME")" run
