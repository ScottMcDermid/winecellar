#!/usr/bin/env bash
# Remove games: either one specific game's directory (prefix, launch target,
# and settings), or every game's directory.
# Always asks for confirmation before deleting anything.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"

confirm() {
  local reply=""
  printf '%s%s%s (y/n) ' "$C_BOLD" "$1" "$C_RESET"
  if [ -r /dev/tty ] && { read -r reply </dev/tty; } 2>/dev/null; then
    :
  else
    read -r reply || reply=""
  fi
  case "$reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -n "$GAME_NAME" ]; then
  GAME_DIR="$(game_dir "$GAME_NAME")"

  if [ ! -d "$GAME_DIR" ]; then
    log_info "No game directory found for $(bold "$GAME_NAME") at:"
    echo "    $(dim "$GAME_DIR")"
    exit 0
  fi

  log_warn "This will permanently delete the game directory for $(bold "$GAME_NAME") (its wine prefix and all settings):"
  echo "    $GAME_DIR"
  if ! confirm "Continue?"; then
    log_info "Aborted."
    exit 1
  fi

  rm -rf "$GAME_DIR"
  log_success "Removed $(bold "$GAME_NAME")."
  exit 0
fi

if [ ! -d "$GAMES_DIR" ]; then
  log_info "No games directory found; nothing to clean."
  exit 0
fi

mapfile -t GAME_DIRS < <(find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

if [ "${#GAME_DIRS[@]}" -eq 0 ]; then
  log_info "No games found; nothing to clean."
  exit 0
fi

log_warn "This will permanently delete ALL games (prefixes and all settings):"
for d in "${GAME_DIRS[@]}"; do
  echo "    $d"
done
if ! confirm "Continue?"; then
  log_info "Aborted."
  exit 1
fi

for d in "${GAME_DIRS[@]}"; do
  rm -rf "$d"
done
log_success "Removed ${#GAME_DIRS[@]} game(s)."
