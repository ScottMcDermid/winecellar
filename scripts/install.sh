#!/usr/bin/env bash
# Run an installer (or a portable game exe) inside a game's wine prefix,
# and remember which executable `make run` should launch afterwards.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
EXE_PATH="${2:-}"
LAUNCH_OVERRIDE="${3:-}"

require_game_name "$GAME_NAME"
require_wine
require_jq

if [ -z "$EXE_PATH" ]; then
  echo "error: missing <path-to-exe> argument." >&2
  echo "usage: make install <game_name> <path-to-exe> [launch-exe]" >&2
  exit 1
fi

if [ ! -f "$EXE_PATH" ]; then
  echo "error: file not found: $EXE_PATH" >&2
  exit 1
fi

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

if [ ! -d "$PREFIX_DIR" ]; then
  echo "No prefix found for '$GAME_NAME' yet, creating one first..."
  "$SCRIPT_DIR/init.sh" "$GAME_NAME"
fi

EXE_ABS="$(cd "$(dirname "$EXE_PATH")" && pwd)/$(basename "$EXE_PATH")"

# Snapshot "now" so we can spot executables that show up during install.
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

echo "Running '$EXE_ABS' in the '$GAME_NAME' prefix..."
WINEPREFIX="$PREFIX_DIR" wine "$EXE_ABS"

LAUNCH_EXE=""

if [ -n "$LAUNCH_OVERRIDE" ]; then
  if [ ! -f "$LAUNCH_OVERRIDE" ]; then
    echo "error: launch override not found: $LAUNCH_OVERRIDE" >&2
    exit 1
  fi
  LAUNCH_EXE="$(cd "$(dirname "$LAUNCH_OVERRIDE")" && pwd)/$(basename "$LAUNCH_OVERRIDE")"
else
  mapfile -t CANDIDATES < <(
    find "$PREFIX_DIR/drive_c" -iname '*.exe' -newer "$MARKER" \
      -not -ipath '*/windows/*' 2>/dev/null
  )

  if [ "${#CANDIDATES[@]}" -eq 1 ]; then
    LAUNCH_EXE="${CANDIDATES[0]}"
  elif [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo
    echo "Multiple new executables appeared for '$GAME_NAME':"
    printf '  %s\n' "${CANDIDATES[@]}"
    echo
    echo "Re-run install naming the one to launch, e.g.:"
    echo "  make install $GAME_NAME $EXE_PATH '${CANDIDATES[0]}'"
    exit 1
  else
    echo "No new executable detected inside the prefix;"
    echo "treating '$EXE_ABS' itself as the game to launch."
    LAUNCH_EXE="$EXE_ABS"
  fi
fi

config_set "$GAME_NAME" launch "$LAUNCH_EXE"
echo
echo "Install complete for '$GAME_NAME'."
echo "Launch target saved: $LAUNCH_EXE"
echo "Run it with: make run $GAME_NAME"
