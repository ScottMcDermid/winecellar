#!/usr/bin/env bash
# Remove wine prefixes: either one specific game's prefix, or all of them.
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
  PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

  if [ ! -d "$PREFIX_DIR" ]; then
    echo "No prefix found for '$GAME_NAME' at:"
    echo "  $PREFIX_DIR"
    exit 0
  fi

  echo "This will permanently delete the wine prefix for '$GAME_NAME':"
  echo "  $PREFIX_DIR"
  if ! confirm "Continue?"; then
    echo "Aborted."
    exit 1
  fi

  rm -rf "$PREFIX_DIR"
  echo "Removed prefix for '$GAME_NAME'."
  exit 0
fi

if [ ! -d "$GAMES_DIR" ]; then
  echo "No games directory found; nothing to clean."
  exit 0
fi

mapfile -t PREFIXES < <(find "$GAMES_DIR" -mindepth 2 -maxdepth 2 -type d -name prefix 2>/dev/null)

if [ "${#PREFIXES[@]}" -eq 0 ]; then
  echo "No prefixes found; nothing to clean."
  exit 0
fi

echo "This will permanently delete ALL wine prefixes:"
for p in "${PREFIXES[@]}"; do
  echo "  $p"
done
if ! confirm "Continue?"; then
  echo "Aborted."
  exit 1
fi

for p in "${PREFIXES[@]}"; do
  rm -rf "$p"
done
echo "Removed ${#PREFIXES[@]} prefix(es)."
