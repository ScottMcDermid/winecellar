#!/usr/bin/env bash
# Shared helpers sourced by the other scripts in this directory.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAMES_DIR="$ROOT_DIR/games"

# --- styling -----------------------------------------------------------
# Colors/icons are only used on an interactive terminal that isn't "dumb",
# and only if the caller hasn't opted out via NO_COLOR (https://no-color.org).
if [ -t 1 ] && [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

bold() { printf '%s%s%s' "$C_BOLD" "$1" "$C_RESET"; }
dim() { printf '%s%s%s' "$C_DIM" "$1" "$C_RESET"; }

# log_* helpers all take the message as "$*" so callers don't need to quote.
log_info() { printf '%s➜%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_step() { printf '%s▸%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
log_success() { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf '%s⚠ %swarning:%s %s\n' "$C_YELLOW" "$C_BOLD" "$C_RESET$C_YELLOW" "$*$C_RESET" >&2; }
log_error() { printf '%s✗ %serror:%s %s\n' "$C_RED" "$C_BOLD" "$C_RESET$C_RED" "$*$C_RESET" >&2; }
die() {
  log_error "$*"
  exit 1
}

require_wine() {
  if ! command -v wine >/dev/null 2>&1; then
    die "'wine' is not installed or not on PATH."
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    die "'jq' is not installed or not on PATH (needed to read/write config.json)."
  fi
}

require_game_name() {
  if [ -z "${1:-}" ]; then
    die "missing <game_name> argument."
  fi
}

game_dir() { echo "$GAMES_DIR/$1"; }
prefix_dir() { echo "$GAMES_DIR/$1/prefix"; }
config_file() { echo "$GAMES_DIR/$1/config.json"; }

# Per-game options live in games/<game_name>/config.json, a small
# JSON object keyed by option name (e.g. "launch", "gamescope_args").
# These helpers are the only thing that should read or write it.

config_get() {
  local game="$1" key="$2" default="${3:-}"
  local file
  file="$(config_file "$game")"
  if [ -f "$file" ]; then
    local value
    value="$(jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null)"
    if [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
  fi
  echo "$default"
}

config_set() {
  local game="$1" key="$2" value="$3"
  local file
  file="$(config_file "$game")"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    echo '{}' >"$file"
  fi
  local tmp
  tmp="$(mktemp)"
  jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$file" >"$tmp" && mv "$tmp" "$file"
}
