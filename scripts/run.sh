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

# gamescope options: $GAMESCOPE_ARGS wins if set, otherwise fall back to a
# per-game default stored in games/<game_name>/config.json under the
# "gamescope_args" key (one line of flags, e.g. "-W 1920 -H 1080 -f").
GAMESCOPE_DEFAULTS="$(config_get "$GAME_NAME" gamescope_args)"
read -r -a GAMESCOPE_ARGS_ARR <<< "${GAMESCOPE_ARGS:-$GAMESCOPE_DEFAULTS}"

# gamescope's default cursor handling flips between confined and free
# depending on whether the game currently hides its cursor, which guesses
# wrong for a lot of wine games (the cursor escapes the window, or mouse
# look stops tracking). --force-grab-cursor pins it to relative mode
# instead, so we always pass it unless explicitly disabled.
if [ "${GAMESCOPE_FORCE_GRAB_CURSOR:-1}" = "1" ]; then
  GAMESCOPE_ARGS_ARR=(--force-grab-cursor "${GAMESCOPE_ARGS_ARR[@]}")
fi

export WINEPREFIX="$PREFIX_DIR"
cd "$(dirname "$LAUNCH_EXE")"

if [ "${NO_GAMESCOPE:-0}" = "1" ]; then
  log_step "Launching $(bold "$GAME_NAME") $(dim "(gamescope disabled)"): $LAUNCH_EXE"
  exec wine "$LAUNCH_EXE"
fi

if ! command -v gamescope >/dev/null 2>&1; then
  log_warn "'gamescope' not found on PATH; launching without it."
  log_step "Launching $(bold "$GAME_NAME"): $LAUNCH_EXE"
  exec wine "$LAUNCH_EXE"
fi

log_step "Launching $(bold "$GAME_NAME") $(dim "in gamescope"): $LAUNCH_EXE"
exec gamescope "${GAMESCOPE_ARGS_ARR[@]}" -- wine "$LAUNCH_EXE"
