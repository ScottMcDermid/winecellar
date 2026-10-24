#!/usr/bin/env bash
# Print (or list, or tail) a game's gamescope/wine logs, written by
# launch_exe to games/<game_name>/logs/ - see scripts/common.sh.
#   scripts/logs.sh <game_name>            print the main run log
#   scripts/logs.sh <game_name> <name>     print a specific log (e.g. a tool's)
#   FOLLOW=1 scripts/logs.sh <game_name> [name]   tail -f instead of printing once
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
LOG_NAME="${2:-run}"

require_game_name "$GAME_NAME"

LOG_DIR="$(game_dir "$GAME_NAME")/logs"
LOG_FILE="$LOG_DIR/$LOG_NAME.log"

if [ ! -f "$LOG_FILE" ]; then
  mapfile -t AVAILABLE < <(
    [ -d "$LOG_DIR" ] && find "$LOG_DIR" -maxdepth 1 -name '*.log' -printf '%f\n' 2>/dev/null | sed 's/\.log$//' | sort
  )

  if [ "${#AVAILABLE[@]}" -eq 0 ]; then
    log_info "No logs yet for $(bold "$GAME_NAME"). Run $(bold "make run $GAME_NAME") first."
    exit 0
  fi

  log_error "no log named '$LOG_NAME' for '$GAME_NAME'. Available:"
  for name in "${AVAILABLE[@]}"; do
    echo "    $name" >&2
  done
  exit 1
fi

if [ "${FOLLOW:-0}" = "1" ]; then
  exec tail -f "$LOG_FILE"
fi

cat "$LOG_FILE"
