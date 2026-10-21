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

require_7z() {
  if ! command -v 7z >/dev/null 2>&1; then
    die "'7z' is not installed or not on PATH (needed to extract .iso installers; try installing p7zip)."
  fi
}

# Some CD images are distributed as raw dumps with 2352-byte sectors (common
# for CD-ROM XA/Mode 2 discs — older multimedia titles, hybrid Mac/PC discs
# burned with tools like Toast, etc.) instead of the plain 2048-byte-sector
# layout most ISO tools (including 7z) expect, so straightforward extraction
# fails even though the file ends in .iso. Detects that layout by looking
# for the ISO9660 "CD001" signature repeating every 2352 bytes and, if
# found, writes a standard-sector copy to $2 that 7z can read. Returns
# non-zero (leaving $2 untouched) if the source doesn't look like a raw CD
# image, so the caller can fall back to reporting the original error.
convert_raw_cd_image() {
  local src="$1" dst="$2"
  python3 - "$src" "$dst" <<'PYEOF'
import sys

RAW = 2352  # sync + header (+ XA subheader) + 2048 user bytes + EDC/ECC

src, dst = sys.argv[1], sys.argv[2]
with open(src, "rb") as f:
    head = f.read(200000)

first = head.find(b"CD001")
if first < 0:
    sys.exit(1)
second = head.find(b"CD001", first + 1)
if second < 0 or second - first != RAW:
    sys.exit(1)

# "CD001" sits 1 byte into the Volume Descriptor's 2048-byte payload, and
# the primary descriptor is always logical sector 16.
hdr = first - 16 * RAW - 1
if hdr < 0 or hdr > 64:
    sys.exit(1)

BATCH = 2000  # sectors per read, a few MB at a time
with open(src, "rb") as fin, open(dst, "wb") as fout:
    while True:
        chunk = fin.read(RAW * BATCH)
        if not chunk:
            break
        for i in range(0, len(chunk) - RAW + 1, RAW):
            fout.write(chunk[i + hdr : i + hdr + 2048])
PYEOF
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

# Some old CD-ROM games refuse to start (or refuse to go past the title
# screen) unless a drive they can see is actually flagged as a CD-ROM, not
# just a folder of files. Wine can't infer that from a plain dosdevices
# symlink, so this mirrors what winecfg's Drives tab does by hand: symlink
# the disc's contents into dosdevices/<letter>: and tell wine to report
# that drive's type as "cdrom" via the same registry key winecfg writes
# (HKEY_LOCAL_MACHINE\Software\Wine\Drives).
#
# Configured per-game via config.json:
#   cd_image  path to a .iso, or to an already-extracted disc folder
#   cd_drive  drive letter to mount it as (default: d)
# e.g. make config <game_name> cd_image /path/to/game.iso
#      make config <game_name> cd_drive d
#
# A .iso is extracted once into games/<game_name>/cdrom (via 7z) and
# re-extracted only if the source file's size/mtime changes; an
# already-extracted folder is symlinked as-is.
mount_cdrom() {
  local game="$1" prefix="$2"
  local image
  image="$(config_get "$game" cd_image)"
  [ -z "$image" ] && return 0

  if [ ! -e "$image" ]; then
    log_warn "configured cd_image for '$game' not found, skipping: $image"
    return 0
  fi

  local drive
  drive="$(config_get "$game" cd_drive d)"
  drive="${drive%:}"
  drive="${drive,,}"

  local source_dir
  if [ -d "$image" ]; then
    source_dir="$image"
  else
    require_7z

    local cache_dir stamp_file stamp
    cache_dir="$(game_dir "$game")/cdrom"
    stamp_file="$(game_dir "$game")/.cdrom-source"
    stamp="$image:$(stat -c '%s:%Y' "$image" 2>/dev/null)"

    if [ ! -d "$cache_dir" ] || [ "$(cat "$stamp_file" 2>/dev/null)" != "$stamp" ]; then
      log_step "Extracting CD image for $(bold "$game") $(dim "(cached under games/$game/cdrom)")..."
      rm -rf "$cache_dir"
      mkdir -p "$cache_dir"
      if ! 7z x -y -o"$cache_dir" -- "$image" >/dev/null; then
        rm -rf "$cache_dir"
        die "failed to extract CD image: $image"
      fi
      echo "$stamp" >"$stamp_file"
    fi
    source_dir="$cache_dir"
  fi

  mkdir -p "$prefix/dosdevices"
  ln -sfn "$source_dir" "$prefix/dosdevices/$drive:"

  WINEPREFIX="$prefix" wine reg add 'HKLM\Software\Wine\Drives' /v "$drive:" /d cdrom /f >/dev/null 2>&1

  log_step "Mounted CD image for $(bold "$game") at $(bold "${drive^^}:")"
}

# Launches an executable inside a game's wine prefix, wrapping it in
# gamescope unless disabled. Shared by `run` (the recorded game/exe
# override) and `tool` (auxiliary exes like mod managers), which only
# differ in whether gamescope is on or off by default.
#   game                  game name (used for WINEPREFIX + gamescope_args lookup)
#   exe                   absolute path to the executable to run
#   default_no_gamescope  gamescope default when $NO_GAMESCOPE isn't set ("0"=on, "1"=off)
#   label                 human-readable description for log messages
launch_exe() {
  local game="$1" exe="$2" default_no_gamescope="$3" label="$4"
  local prefix
  prefix="$(prefix_dir "$game")"

  mount_cdrom "$game" "$prefix"

  # gamescope options: $GAMESCOPE_ARGS wins if set, otherwise fall back to a
  # per-game default stored in games/<game_name>/config.json under the
  # "gamescope_args" key (one line of flags, e.g. "-W 1920 -H 1080 -f").
  local gamescope_defaults
  gamescope_defaults="$(config_get "$game" gamescope_args)"
  local -a gamescope_args_arr
  read -r -a gamescope_args_arr <<< "${GAMESCOPE_ARGS:-$gamescope_defaults}"

  # gamescope's default cursor handling flips between confined and free
  # depending on whether the game currently hides its cursor, which guesses
  # wrong for a lot of wine games (the cursor escapes the window, or mouse
  # look stops tracking). --force-grab-cursor pins it to relative mode
  # instead, so we always pass it unless explicitly disabled.
  if [ "${GAMESCOPE_FORCE_GRAB_CURSOR:-1}" = "1" ]; then
    gamescope_args_arr=(--force-grab-cursor "${gamescope_args_arr[@]}")
  fi

  export WINEPREFIX="$prefix"
  cd "$(dirname "$exe")"

  if [ "${NO_GAMESCOPE:-$default_no_gamescope}" = "1" ]; then
    log_step "Launching $label $(dim "(gamescope disabled)"): $exe"
    exec wine "$exe"
  fi

  if ! command -v gamescope >/dev/null 2>&1; then
    log_warn "'gamescope' not found on PATH; launching without it."
    log_step "Launching $label: $exe"
    exec wine "$exe"
  fi

  log_step "Launching $label $(dim "in gamescope"): $exe"
  exec gamescope "${gamescope_args_arr[@]}" -- wine "$exe"
}
