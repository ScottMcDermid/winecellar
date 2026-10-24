#!/usr/bin/env bash
# Launch wine's registry editor inside a game's prefix, e.g. to hand-edit
# keys that winecfg/`make config` don't expose.
#   scripts/regedit.sh <game_name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
require_game_name "$GAME_NAME"
check_deps wine

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"
if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

export WINEPREFIX="$PREFIX_DIR"
log_step "Launching regedit for $(bold "$GAME_NAME")..."
exec wine regedit
