#!/usr/bin/env bash
# Force-kill a stuck game session: gamescope, wine, wineserver, and any
# other processes tied to a game's wine prefix.
#
# `make run`/`make tool` watch for this automatically now (a background
# watcher force-kills a gamescope session that outlives the game it was
# wrapping - see watch_stuck_gamescope in common.sh), so this is mostly a
# manual fallback: for a session started before that existed, one the
# watcher didn't catch, or any other case where you just want everything
# for a game torn down right now.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
require_game_name "$GAME_NAME"

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"
if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

force_kill_game "$GAME_NAME"
