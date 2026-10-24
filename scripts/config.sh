#!/usr/bin/env bash
# View or edit a game's games/<game_name>/config.json.
#   scripts/config.sh <game_name>                 print the whole config
#   scripts/config.sh <game_name> <key>            print one value
#   scripts/config.sh <game_name> <key> <value>    set one value
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
KEY="${2:-}"
VALUE="${3:-}"

require_game_name "$GAME_NAME"
check_deps jq

CONFIG_FILE="$(config_file "$GAME_NAME")"

JQ_COLOR_FLAG=()
if [ -n "$C_RESET" ]; then
  JQ_COLOR_FLAG=(-C)
fi

if [ -z "$KEY" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    jq "${JQ_COLOR_FLAG[@]}" '.' "$CONFIG_FILE"
  else
    echo '{}'
  fi
  exit 0
fi

if [ "$#" -ge 3 ]; then
  config_set "$GAME_NAME" "$KEY" "$VALUE"
  log_success "Set $(bold "$KEY") = $(bold "$VALUE") for $(bold "$GAME_NAME")."
  exit 0
fi

VALUE="$(config_get "$GAME_NAME" "$KEY")"
if [ -z "$VALUE" ]; then
  dim "(not set)"
  echo
else
  echo "$VALUE"
fi
