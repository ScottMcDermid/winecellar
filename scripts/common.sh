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

require_game_name() {
  if [ -z "${1:-}" ]; then
    echo "error: missing <game_name> argument." >&2
    exit 1
  fi
}

game_dir() { echo "$GAMES_DIR/$1"; }
prefix_dir() { echo "$GAMES_DIR/$1/prefix"; }
launch_file() { echo "$GAMES_DIR/$1/launch.txt"; }
gamescope_conf() { echo "$GAMES_DIR/$1/gamescope.conf"; }
