#!/usr/bin/env bash
# Force-kill a stuck game session: gamescope, wine, wineserver, and any
# other processes tied to a game's wine prefix.
#
# Normally quitting a game should just end `make run`/`make tool` on its
# own. But gamescope has a long-standing upstream bug where it hangs around
# after the wrapped game exits normally instead of releasing the terminal -
# https://github.com/ValveSoftware/gamescope/issues/777 - and even Ctrl+C
# doesn't help, since gamescope's own shutdown path is what's stuck. This is
# the escape hatch for that: run it from another terminal to clean up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
require_game_name "$GAME_NAME"

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"
if [ ! -d "$PREFIX_DIR" ]; then
  die "no prefix found for '$GAME_NAME'. Run: make init $GAME_NAME"
fi

# launch_exe exports WINEPREFIX="$PREFIX_DIR" before exec'ing gamescope (or
# wine directly), so every process in that tree - gamescope, wine,
# wineserver, and whatever else wine spawns - inherits it verbatim. Scanning
# /proc/*/environ for an exact match finds the whole tree regardless of how
# it's nested, with no need to guess at command lines or parent/child
# relationships.
find_pids() {
  local pid env_file
  for env_file in /proc/[0-9]*/environ; do
    pid="${env_file#/proc/}"
    pid="${pid%/environ}"
    [ "$pid" = "$$" ] && continue
    grep -Fxzqs -- "WINEPREFIX=$PREFIX_DIR" "$env_file" 2>/dev/null && echo "$pid"
  done
}

mapfile -t PIDS < <(find_pids)

if [ "${#PIDS[@]}" -eq 0 ]; then
  log_info "No running processes found for $(bold "$GAME_NAME")."
  exit 0
fi

log_step "Found ${#PIDS[@]} process(es) for $(bold "$GAME_NAME") $(dim "(${PIDS[*]})")"

log_step "Sending SIGTERM..."
kill "${PIDS[@]}" 2>/dev/null || true

alive() {
  local pid
  for pid in "${PIDS[@]}"; do
    kill -0 "$pid" 2>/dev/null && echo "$pid"
  done
}

mapfile -t REMAINING < <(alive)
for _ in $(seq 1 10); do
  [ "${#REMAINING[@]}" -eq 0 ] && break
  sleep 0.3
  mapfile -t REMAINING < <(alive)
done

if [ "${#REMAINING[@]}" -gt 0 ]; then
  log_warn "${#REMAINING[@]} process(es) still alive after SIGTERM, sending SIGKILL $(dim "(${REMAINING[*]})")"
  kill -9 "${REMAINING[@]}" 2>/dev/null || true
fi

# Belt-and-braces: wineserver can outlive the processes that were using it
# (or never show up in the WINEPREFIX scan if it was inherited from a
# differently-cased/symlinked path), so explicitly tell it to shut down too.
if command -v wineserver >/dev/null 2>&1; then
  WINEPREFIX="$PREFIX_DIR" wineserver -k 2>/dev/null || true
fi

log_success "Cleaned up $(bold "$GAME_NAME")."
