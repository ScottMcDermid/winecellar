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
  echo "error: no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME" >&2
  exit 1
fi

if [ -n "$EXE_OVERRIDE" ]; then
  if [ ! -f "$EXE_OVERRIDE" ]; then
    echo "error: executable not found: $EXE_OVERRIDE" >&2
    exit 1
  fi
  LAUNCH_EXE="$(cd "$(dirname "$EXE_OVERRIDE")" && pwd)/$(basename "$EXE_OVERRIDE")"
else
  LAUNCH_EXE="$(config_get "$GAME_NAME" launch)"

  if [ -z "$LAUNCH_EXE" ]; then
    echo "error: no launch target recorded for '$GAME_NAME'." >&2
    echo "Run: make install $GAME_NAME <path-to-exe>" >&2
    exit 1
  fi

  if [ ! -f "$LAUNCH_EXE" ]; then
    echo "error: recorded launch executable is missing: $LAUNCH_EXE" >&2
    exit 1
  fi
fi

# gamescope options: $GAMESCOPE_ARGS wins if set, otherwise fall back to a
# per-game default stored in games/<game_name>/config.json under the
# "gamescope_args" key (one line of flags, e.g. "-W 1920 -H 1080 -f").
GAMESCOPE_DEFAULTS="$(config_get "$GAME_NAME" gamescope_args)"
read -r -a GAMESCOPE_ARGS_ARR <<< "${GAMESCOPE_ARGS:-$GAMESCOPE_DEFAULTS}"

export WINEPREFIX="$PREFIX_DIR"
cd "$(dirname "$LAUNCH_EXE")"

if [ "${NO_GAMESCOPE:-0}" = "1" ]; then
  echo "Launching '$GAME_NAME' (gamescope disabled): $LAUNCH_EXE"
  exec wine "$LAUNCH_EXE"
fi

if ! command -v gamescope >/dev/null 2>&1; then
  echo "warning: 'gamescope' not found on PATH; launching without it." >&2
  echo "Launching '$GAME_NAME': $LAUNCH_EXE"
  exec wine "$LAUNCH_EXE"
fi

echo "Launching '$GAME_NAME' in gamescope: $LAUNCH_EXE"
exec gamescope "${GAMESCOPE_ARGS_ARR[@]}" -- wine "$LAUNCH_EXE"
