#!/usr/bin/env bash
# Shared helpers sourced by the other scripts in this directory.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAMES_DIR="$ROOT_DIR/games"

require_wine() {
  if ! command -v wine >/dev/null 2>&1; then
    echo "error: 'wine' is not installed or not on PATH." >&2
    exit 1
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: 'jq' is not installed or not on PATH (needed to read/write config.json)." >&2
    exit 1
  fi
}

require_game_name() {
  if [ -z "${1:-}" ]; then
    echo "error: missing <game_name> argument." >&2
    exit 1
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
