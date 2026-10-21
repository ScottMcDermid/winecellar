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
  printf '%s (y/n) ' "$1"
  if [ -r /dev/tty ] && { read -r reply </dev/tty; } 2>/dev/null; then
    :
  else
    read -r reply || reply=""
  fi
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -n "$GAME_NAME" ]; then
  GAME_DIR="$(game_dir "$GAME_NAME")"

  if [ ! -d "$GAME_DIR" ]; then
    echo "No game directory found for '$GAME_NAME' at:"
    echo "  $GAME_DIR"
    exit 0
  fi

  echo "This will permanently delete the game directory for '$GAME_NAME' (its wine prefix and all settings):"
  echo "  $GAME_DIR"
  if ! confirm "Continue?"; then
    echo "Aborted."
    exit 1
  fi

  rm -rf "$GAME_DIR"
  echo "Removed '$GAME_NAME'."
  exit 0
fi

if [ ! -d "$GAMES_DIR" ]; then
  echo "No games directory found; nothing to clean."
  exit 0
fi

mapfile -t GAME_DIRS < <(find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

if [ "${#GAME_DIRS[@]}" -eq 0 ]; then
  echo "No games found; nothing to clean."
  exit 0
fi

echo "This will permanently delete ALL games (prefixes and all settings):"
for d in "${GAME_DIRS[@]}"; do
  echo "  $d"
done
if ! confirm "Continue?"; then
  echo "Aborted."
  exit 1
fi

for d in "${GAME_DIRS[@]}"; do
  rm -rf "$d"
done
echo "Removed ${#GAME_DIRS[@]} game(s)."
