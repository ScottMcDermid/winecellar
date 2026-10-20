#!/usr/bin/env bash
# Create a wine prefix nested under games/<game_name>/prefix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
require_game_name "$GAME_NAME"
require_wine

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

if [ -d "$PREFIX_DIR" ]; then
  echo "Wine prefix for '$GAME_NAME' already exists at:"
  echo "  $PREFIX_DIR"
  exit 0
fi

mkdir -p "$PREFIX_DIR"

echo "Initializing wine prefix for '$GAME_NAME'..."
echo "  prefix: $PREFIX_DIR"
echo "  arch:   ${WINEARCH:-win64}"

WINEPREFIX="$PREFIX_DIR" WINEARCH="${WINEARCH:-win64}" wineboot --init

echo "Done. Prefix ready for '$GAME_NAME'."
