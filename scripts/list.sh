#!/usr/bin/env bash
# List known games, with their recorded launch target if any.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
check_deps jq

mapfile -t GAME_DIRS < <(
  [ -d "$GAMES_DIR" ] && find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
)

if [ "${#GAME_DIRS[@]}" -eq 0 ]; then
  log_info "No games yet. Run $(bold "make init <game_name>") first."
  exit 0
fi

echo "$(bold "Games") $(dim "(${#GAME_DIRS[@]})")"
for name in "${GAME_DIRS[@]}"; do
  LAUNCH="$(config_get "$name" launch)"
  if [ -n "$LAUNCH" ]; then
    printf '  %s●%s %-20s %s\n' "$C_GREEN" "$C_RESET" "$name" "$(dim "$LAUNCH")"
  else
    printf '  %s●%s %-20s %s\n' "$C_YELLOW" "$C_RESET" "$name" "$(dim "no launch target - run: make install $name <path-to-exe>")"
  fi
done
