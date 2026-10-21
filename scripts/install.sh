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

# What we'll actually hand to wine. Normally this is just EXE_ABS, but for a
# .iso it becomes the installer exe found inside the extracted image.
RUN_EXE="$EXE_ABS"
ISO_TMPDIR=""

# Snapshot "now" so we can spot executables that show up during install.
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"; [ -n "$ISO_TMPDIR" ] && rm -rf "$ISO_TMPDIR"' EXIT

if [[ "${EXE_PATH,,}" == *.iso ]]; then
  require_7z

  ISO_TMPDIR="$(mktemp -d)"

  log_step "Extracting $(bold "$EXE_ABS")..."
  if ! 7z x -y -o"$ISO_TMPDIR" -- "$EXE_ABS" >/dev/null 2>/dev/null; then
    if ! command -v python3 >/dev/null 2>&1; then
      die "failed to extract ISO: $EXE_ABS (if this is a raw/2352-byte-sector CD image, converting it needs python3, which isn't on PATH)"
    fi

    log_warn "standard extraction failed; checking for a raw (2352-byte sector) CD image..."
    CONVERTED_ISO="$(mktemp --suffix=.iso)"
    if ! convert_raw_cd_image "$EXE_ABS" "$CONVERTED_ISO"; then
      rm -f "$CONVERTED_ISO"
      die "failed to extract ISO: $EXE_ABS"
    fi

    rm -rf "$ISO_TMPDIR"
    mkdir -p "$ISO_TMPDIR"
    if ! 7z x -y -o"$ISO_TMPDIR" -- "$CONVERTED_ISO" >/dev/null; then
      rm -f "$CONVERTED_ISO"
      die "failed to extract ISO even after raw-sector conversion: $EXE_ABS"
    fi
    rm -f "$CONVERTED_ISO"
    log_info "Detected a raw (2352-byte sector) CD image and converted it before extracting."
  fi

  # Prefer the conventional installer names, preferring whichever sits
  # shallowest in the image (so a handful of decoy copies bundled alongside
  # it — Acrobat Reader, DirectX, an uninstaller stub, etc. — don't out-vote
  # the real one); fall back to every .exe in the image, skipping
  # redistributable bundles, which are never the game's own installer.
  shallowest_paths() {
    awk -F'\t' '
      NR == 1 || $1 < min { min = $1 }
      { depth[NR] = $1; path[NR] = $2 }
      END { for (i = 1; i <= NR; i++) if (depth[i] == min) print path[i] }
    '
  }

  mapfile -t ISO_CANDIDATES < <(
    find "$ISO_TMPDIR" -iname 'setup.exe' -printf '%d\t%p\n' | shallowest_paths
  )
  if [ "${#ISO_CANDIDATES[@]}" -eq 0 ]; then
    mapfile -t ISO_CANDIDATES < <(
      find "$ISO_TMPDIR" -iname 'autorun.exe' -printf '%d\t%p\n' | shallowest_paths
    )
  fi
  if [ "${#ISO_CANDIDATES[@]}" -eq 0 ]; then
    mapfile -t ISO_CANDIDATES < <(
      find "$ISO_TMPDIR" -iname '*.exe' -not -ipath '*redist*' -printf '%d\t%p\n' | shallowest_paths
    )
  fi

  if [ "${#ISO_CANDIDATES[@]}" -eq 0 ]; then
    die "no executable found inside ISO: $EXE_ABS"
  elif [ "${#ISO_CANDIDATES[@]}" -eq 1 ]; then
    RUN_EXE="${ISO_CANDIDATES[0]}"
  else
    echo
    log_info "Multiple possible installers found inside $(bold "$EXE_ABS"):"
    echo
    for i in "${!ISO_CANDIDATES[@]}"; do
      printf '    %s%2d)%s %s\n' "$C_CYAN" "$((i + 1))" "$C_RESET" "${ISO_CANDIDATES[$i]#"$ISO_TMPDIR"/}"
    done
    echo

    if exec 3</dev/tty 2>/dev/null; then
      CHOICE=""
      while true; do
        read -r -u 3 -p "$(printf '%sSelect the one to run [1-%d]:%s ' "$C_BOLD" "${#ISO_CANDIDATES[@]}" "$C_RESET")" CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#ISO_CANDIDATES[@]}" ]; then
          RUN_EXE="${ISO_CANDIDATES[$((CHOICE - 1))]}"
          break
        fi
        log_error "enter a number between 1 and ${#ISO_CANDIDATES[@]}."
      done
      exec 3<&-
    else
      log_info "Not running in an interactive terminal; extract the ISO yourself and re-run install naming the installer directly, e.g.:"
      echo "    7z x '$EXE_ABS' -o/tmp/some-dir"
      echo "    make install $GAME_NAME '/tmp/some-dir/<installer>.exe'"
      exit 1
    fi
  fi

  log_info "Using installer: $(dim "${RUN_EXE#"$ISO_TMPDIR"/}")"
fi

log_step "Running $(bold "$RUN_EXE") in the $(bold "$GAME_NAME") prefix..."
if [ -n "$ISO_TMPDIR" ]; then
  # Run from the installer's own directory, same as a real disc layout, so
  # installers that expect sibling files (data1.cab, etc.) can find them.
  (cd "$(dirname "$RUN_EXE")" && WINEPREFIX="$PREFIX_DIR" wine "$(basename "$RUN_EXE")")
else
  WINEPREFIX="$PREFIX_DIR" wine "$RUN_EXE"
fi

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
      echo "    make install GAME=$GAME_NAME EXE='$EXE_PATH' LAUNCH='${CANDIDATES[0]}'"
      exit 1
    fi
  else
    if [ -n "$ISO_TMPDIR" ]; then
      die "installer ran but no new executable was detected in the prefix; the ISO's installer exe doesn't persist after extraction, so there's nothing stable to record. Check that the installer completed successfully and try again."
    fi
    log_info "No new executable detected inside the prefix;"
    echo "  treating $(bold "$RUN_EXE") itself as the game to launch."
    LAUNCH_EXE="$RUN_EXE"
  fi
fi

config_set "$GAME_NAME" launch "$LAUNCH_EXE"
echo
log_success "Install complete for $(bold "$GAME_NAME")."
echo "  Launch target saved: $(dim "$LAUNCH_EXE")"
echo "  Run it with: $(bold "make run $GAME_NAME")"
