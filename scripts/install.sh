#!/usr/bin/env bash
# Run an installer (or a portable game exe) inside a game's wine prefix,
# and remember which executable `make run` should launch afterwards.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

GAME_NAME="${1:-}"
EXE_PATH="${2:-}"
LAUNCH_OVERRIDE="${3:-}"

require_game_name "$GAME_NAME"
require_wine
require_jq

if [ -z "$EXE_PATH" ]; then
  log_error "missing <path-to-exe> argument."
  echo "usage: make install <game_name> <path-to-exe> [launch-exe]" >&2
  exit 1
fi

if [ ! -f "$EXE_PATH" ]; then
  die "file not found: $EXE_PATH"
fi

PREFIX_DIR="$(prefix_dir "$GAME_NAME")"

if [ ! -d "$PREFIX_DIR" ]; then
  log_info "No prefix found for $(bold "$GAME_NAME") yet, creating one first..."
  "$SCRIPT_DIR/init.sh" "$GAME_NAME"
fi

EXE_ABS="$(cd "$(dirname "$EXE_PATH")" && pwd)/$(basename "$EXE_PATH")"

# Snapshot "now" so we can spot executables that show up during install.
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

log_step "Running $(bold "$EXE_ABS") in the $(bold "$GAME_NAME") prefix..."
WINEPREFIX="$PREFIX_DIR" wine "$EXE_ABS"

LAUNCH_EXE=""

if [ -n "$LAUNCH_OVERRIDE" ]; then
  if [ ! -f "$LAUNCH_OVERRIDE" ]; then
    die "launch override not found: $LAUNCH_OVERRIDE"
  fi
  LAUNCH_EXE="$(cd "$(dirname "$LAUNCH_OVERRIDE")" && pwd)/$(basename "$LAUNCH_OVERRIDE")"
else
  mapfile -t CANDIDATES < <(
    find "$PREFIX_DIR/drive_c" -iname '*.exe' -newer "$MARKER" \
      -not -ipath '*/windows/*' 2>/dev/null
  )

  if [ "${#CANDIDATES[@]}" -eq 1 ]; then
    LAUNCH_EXE="${CANDIDATES[0]}"
  elif [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo
    log_info "Multiple new executables appeared for $(bold "$GAME_NAME"):"
    echo
    for i in "${!CANDIDATES[@]}"; do
      printf '    %s%2d)%s %s\n' "$C_CYAN" "$((i + 1))" "$C_RESET" "${CANDIDATES[$i]}"
    done
    echo

    # Open a fd on the controlling terminal rather than just testing
    # permission bits on /dev/tty; there may be no controlling terminal at
    # all (e.g. running under certain non-interactive harnesses), in which
    # case the open itself fails.
    if exec 3</dev/tty 2>/dev/null; then
      CHOICE=""
      while true; do
        read -r -u 3 -p "$(printf '%sSelect the one to launch [1-%d]:%s ' "$C_BOLD" "${#CANDIDATES[@]}" "$C_RESET")" CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#CANDIDATES[@]}" ]; then
          LAUNCH_EXE="${CANDIDATES[$((CHOICE - 1))]}"
          break
        fi
        log_error "enter a number between 1 and ${#CANDIDATES[@]}."
      done
      exec 3<&-
    else
      log_info "Not running in an interactive terminal; re-run install naming the one to launch, e.g.:"
      echo "    make install $GAME_NAME $EXE_PATH '${CANDIDATES[0]}'"
      exit 1
    fi
  else
    log_info "No new executable detected inside the prefix;"
    echo "  treating $(bold "$EXE_ABS") itself as the game to launch."
    LAUNCH_EXE="$EXE_ABS"
  fi
fi

config_set "$GAME_NAME" launch "$LAUNCH_EXE"
echo
log_success "Install complete for $(bold "$GAME_NAME")."
echo "  Launch target saved: $(dim "$LAUNCH_EXE")"
echo "  Run it with: $(bold "make run $GAME_NAME")"
