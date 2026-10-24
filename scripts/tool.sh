#!/usr/bin/env bash
# Record and launch auxiliary executables that live inside a game's wine
# prefix but aren't the game itself - e.g. a mod manager like Wrye Bash that
# needs to run alongside the game (same prefix, same Data folder) without
# disturbing the recorded `launch` target that `make run` uses.
#
#   scripts/tool.sh <game_name>                       list recorded tools
#   scripts/tool.sh <game_name> <tool_name>            launch a recorded tool
#   scripts/tool.sh <game_name> <tool_name> <exe>      record <exe> as <tool_name>, then launch it
#
# Unlike `make run`, these default to gamescope OFF (NO_GAMESCOPE=1), since
# tools like mod managers are usually windowed GUI apps rather than games.
# Set NO_GAMESCOPE=0 to force gamescope for a particular tool/run anyway.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
TOOL_NAME="${2:-}"
EXE_PATH="${3:-}"

require_game_name "$GAME_NAME"
check_deps wine jq

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"
if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

if [ -z "$TOOL_NAME" ]; then
  mapfile -t TOOL_NAMES < <(
    jq -r 'keys[] | select(startswith("tool_")) | sub("^tool_"; "")' \
      "$(config_file "$GAME_NAME")" 2>/dev/null | sort
  )

  if [ "${#TOOL_NAMES[@]}" -eq 0 ]; then
    log_info "No tools recorded for $(bold "$GAME_NAME")."
    echo "  Record one with: $(bold "make tool $GAME_NAME <name> <path-to-exe>")"
    exit 0
  fi

  echo "$(bold "Tools for $GAME_NAME") $(dim "(${#TOOL_NAMES[@]})")"
  for name in "${TOOL_NAMES[@]}"; do
    printf '  %s●%s %-20s %s\n' "$C_GREEN" "$C_RESET" "$name" "$(dim "$(config_get "$GAME_NAME" "tool_$name")")"
  done
  exit 0
fi

CONFIG_KEY="tool_$TOOL_NAME"

if [ -n "$EXE_PATH" ]; then
  if [ ! -f "$EXE_PATH" ]; then
    die "file not found: $EXE_PATH"
  fi
  TOOL_EXE="$(cd "$(dirname "$EXE_PATH")" && pwd)/$(basename "$EXE_PATH")"
  config_set "$GAME_NAME" "$CONFIG_KEY" "$TOOL_EXE"
  log_success "Recorded tool $(bold "$TOOL_NAME") for $(bold "$GAME_NAME"): $(dim "$TOOL_EXE")"
else
  TOOL_EXE="$(config_get "$GAME_NAME" "$CONFIG_KEY")"

  if [ -z "$TOOL_EXE" ]; then
    log_error "no path recorded for tool '$TOOL_NAME' on '$GAME_NAME'."
    echo "Run: make tool $GAME_NAME $TOOL_NAME <path-to-exe>" >&2
    exit 1
  fi

  if [ ! -f "$TOOL_EXE" ]; then
    die "recorded tool executable is missing: $TOOL_EXE"
  fi
fi

# Tools default to gamescope OFF; override with NO_GAMESCOPE=0.
launch_exe "$GAME_NAME" "$TOOL_EXE" 1 "$(bold "$GAME_NAME") $(dim "tool: $TOOL_NAME")" "tool-$TOOL_NAME"
