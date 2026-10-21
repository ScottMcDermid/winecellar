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
  log_info "Wine prefix for $(bold "$GAME_NAME") already exists at:"
  echo "    $(dim "$PREFIX_DIR")"
  exit 0
fi

mkdir -p "$PREFIX_DIR"

log_step "Initializing wine prefix for $(bold "$GAME_NAME")..."
printf '    %s %s\n' "$(dim "prefix:")" "$PREFIX_DIR"
printf '    %s %s\n' "$(dim "arch:  ")" "${WINEARCH:-win64}"

WINEPREFIX="$PREFIX_DIR" WINEARCH="${WINEARCH:-win64}" wineboot --init

log_success "Prefix ready for $(bold "$GAME_NAME")."
