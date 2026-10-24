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

# One-line explanation shown by check_deps next to each missing command.
declare -A DEP_DESC=(
  [wine]="run Windows executables inside the wine prefix"
  [jq]="read/write each game's config.json"
  [7z]="extract .iso installers (try installing p7zip)"
  [gamescope]="launch games in their own nested session"
)

# check_deps <cmd> [<cmd> ...]
# Checks every command up front, before anything else runs, and - if any are
# missing - reports all of them together in one nicely-aligned list instead
# of dying on the first one. Without this, fixing dependencies is a
# run/fail/install-one/re-run cycle; with it, you see everything you need in
# one go.
check_deps() {
  local -a missing=()
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [ "${#missing[@]}" -eq 0 ] && return 0

  local width=0
  for cmd in "${missing[@]}"; do
    [ "${#cmd}" -gt "$width" ] && width="${#cmd}"
  done

  local plural="y"
  [ "${#missing[@]}" -gt 1 ] && plural="ies"
  log_error "missing ${#missing[@]} required dependenc$plural on PATH:"
  echo >&2
  for cmd in "${missing[@]}"; do
    printf '    %s✗%s %-*s  %s\n' "$C_RED" "$C_RESET" "$width" "$cmd" "$(dim "${DEP_DESC[$cmd]:-required}")" >&2
  done
  echo >&2
  exit 1
}

# Some CD images are distributed as raw dumps with 2352-byte sectors (common
# for CD-ROM XA/Mode 2 discs - older multimedia titles, hybrid Mac/PC discs
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
    check_deps 7z

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

# Force-kills every process tied to a game's wine prefix: gamescope, wine,
# wineserver, and anything else wine spawned. Shared by `make kill` (manual
# cleanup) and the stuck-gamescope watcher below (automatic cleanup).
#
# launch_exe exports WINEPREFIX="$prefix" before launching gamescope (or
# wine directly), so every process in that tree inherits it verbatim.
# Scanning /proc/*/environ for an exact match finds the whole tree
# regardless of how it's nested, with no need to guess at command lines or
# parent/child relationships.
force_kill_game() {
  local game="$1"
  local prefix
  prefix="$(prefix_dir "$game")"

  local pid env_file
  local -a pids=()
  for env_file in /proc/[0-9]*/environ; do
    pid="${env_file#/proc/}"
    pid="${pid%/environ}"
    [ "$pid" = "$$" ] && continue
    if grep -Fxzqs -- "WINEPREFIX=$prefix" "$env_file" 2>/dev/null; then
      pids+=("$pid")
    fi
  done

  if [ "${#pids[@]}" -eq 0 ]; then
    log_info "No running processes found for $(bold "$game")."
    return 0
  fi

  log_step "Found ${#pids[@]} process(es) for $(bold "$game") $(dim "(${pids[*]})")"

  log_step "Sending SIGTERM..."
  kill "${pids[@]}" 2>/dev/null || true

  local -a remaining=()
  local i
  for pid in "${pids[@]}"; do
    kill -0 "$pid" 2>/dev/null && remaining+=("$pid")
  done
  for ((i = 0; i < 10 && ${#remaining[@]} > 0; i++)); do
    sleep 0.3
    local -a still=()
    for pid in "${remaining[@]}"; do
      kill -0 "$pid" 2>/dev/null && still+=("$pid")
    done
    remaining=("${still[@]}")
  done

  if [ "${#remaining[@]}" -gt 0 ]; then
    log_warn "${#remaining[@]} process(es) still alive after SIGTERM, sending SIGKILL $(dim "(${remaining[*]})")"
    kill -9 "${remaining[@]}" 2>/dev/null || true
  fi

  # Belt-and-braces: wineserver can outlive the processes that were using it
  # (or never show up in the WINEPREFIX scan if it was inherited from a
  # differently-cased/symlinked path), so explicitly tell it to shut down too.
  if command -v wineserver >/dev/null 2>&1; then
    WINEPREFIX="$prefix" wineserver -k 2>/dev/null || true
  fi

  log_success "Cleaned up $(bold "$game")."
}

# Watches a gamescope session for a long-standing upstream bug where it
# keeps running after the game it's wrapping has already exited instead of
# releasing the terminal - https://github.com/ValveSoftware/gamescope/issues/777.
# Gamescope spawns a dedicated "gamescopereaper" helper whose only job is
# supervising the exact wrapped command (nothing else - not Xwayland or
# gamescope's other internal helpers), so that process, and in turn its one
# child, is what we track rather than guessing from WINEPREFIX-tagged pids
# (which both gamescope-internal processes and the wrapped game share).
#
# Meant to run in the background alongside `wait`-ing on gamescope; once the
# wrapped process is gone, gamescope gets a grace period to notice and exit
# on its own (the normal path) before this force-kills the whole session.
watch_stuck_gamescope() {
  local game="$1" gs_pid="$2" kill_marker="$3"
  local grace="${GAMESCOPE_AUTO_KILL_GRACE:-10}"

  local reaper_pid="" wine_pid="" i
  for ((i = 0; i < 100; i++)); do
    kill -0 "$gs_pid" 2>/dev/null || return 0
    reaper_pid="$(pgrep -P "$gs_pid" -x gamescopereaper 2>/dev/null | head -n1)" || true
    [ -n "$reaper_pid" ] && break
    sleep 0.1
  done
  [ -z "$reaper_pid" ] && return 0 # couldn't find it; don't guess, bail out quietly

  for ((i = 0; i < 100; i++)); do
    kill -0 "$reaper_pid" 2>/dev/null || return 0
    wine_pid="$(pgrep -P "$reaper_pid" 2>/dev/null | head -n1)" || true
    [ -n "$wine_pid" ] && break
    sleep 0.1
  done
  [ -z "$wine_pid" ] && return 0

  # Wait for the wrapped process to exit. If gamescope exits first, there's
  # nothing stuck - it beat us to it.
  while kill -0 "$gs_pid" 2>/dev/null && kill -0 "$wine_pid" 2>/dev/null; do
    sleep 1
  done
  kill -0 "$gs_pid" 2>/dev/null || return 0

  local waited=0
  while [ "$waited" -lt "$grace" ] && kill -0 "$gs_pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
  done
  kill -0 "$gs_pid" 2>/dev/null || return 0

  log_warn "gamescope is still running ${grace}s after $(bold "$game") exited $(dim "(known upstream bug)"); force-killing the session..."
  : >"$kill_marker"
  force_kill_game "$game"
}

# Known log lines that mean wine itself is wedged, as opposed to gamescope
# just failing to notice a clean exit (watch_stuck_gamescope above) - e.g.
# the DirectShow/quartz filter-graph deadlock some Bethesda-engine games hit
# tearing down video playback on exit, which doesn't actually resolve once
# hit. In that case the wrapped wine process never exits at all, so there's
# nothing for watch_stuck_gamescope's "has the game exited yet" check to
# ever notice - this instead watches the logfile directly for one of these
# to show up. Add more here as other known-unrecoverable patterns turn up.
HUNG_WINE_LOG_PATTERNS=(
  'err:quartz:BaseMemAllocator_Decommit Waiting'
)

# Companion to watch_stuck_gamescope: watches the logfile for a sign that
# wine itself is wedged (see HUNG_WINE_LOG_PATTERNS above) rather than
# waiting for the process to exit, since it never will if this is what's
# going on. To avoid treating an isolated, benign print of one of these
# lines as a permanent hang, it waits for a further grace period of log
# inactivity afterwards before concluding it's genuinely stuck - if wine
# goes on to log anything else (or exits on its own), nothing happens.
watch_hung_wine_log() {
  local game="$1" gs_pid="$2" log_file="$3" kill_marker="$4"
  local grace="${WINE_HANG_GRACE:-15}"

  local pattern="" p
  while kill -0 "$gs_pid" 2>/dev/null; do
    if [ -f "$log_file" ]; then
      for p in "${HUNG_WINE_LOG_PATTERNS[@]}"; do
        if grep -Fq -- "$p" "$log_file" 2>/dev/null; then
          pattern="$p"
          break 2
        fi
      done
    fi
    sleep 2
  done
  [ -z "$pattern" ] && return 0 # gamescope/wine exited before we ever saw it - nothing to do

  local before
  before="$(stat -c '%s' "$log_file" 2>/dev/null || echo 0)"
  local waited=0
  while [ "$waited" -lt "$grace" ] && kill -0 "$gs_pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
  done
  kill -0 "$gs_pid" 2>/dev/null || return 0 # exited on its own while we waited - not stuck after all

  local after
  after="$(stat -c '%s' "$log_file" 2>/dev/null || echo 0)"
  # Still logging something, even if it's not necessarily obvious progress -
  # treat that as "not hung (yet)" and leave it to keep running; worst case
  # watch_stuck_gamescope or the next poll of this one still has it covered.
  [ "$after" != "$before" ] && return 0

  log_warn "wine looks wedged $(dim "(saw '$pattern', then no further output for ${grace}s)"); force-killing the session..."
  : >"$kill_marker"
  force_kill_game "$game"
}

# Launches an executable inside a game's wine prefix, wrapping it in
# gamescope unless disabled. Shared by `run` (the recorded game/exe
# override) and `tool` (auxiliary exes like mod managers), which only
# differ in whether gamescope is on or off by default.
#   game                  game name (used for WINEPREFIX + gamescope_args lookup)
#   exe                   absolute path to the executable to run
#   default_no_gamescope  gamescope default when $NO_GAMESCOPE isn't set ("0"=on, "1"=off)
#   label                 human-readable description for log messages
#   log_name              filename stem (no extension) for this run's logfile,
#                          under games/<game_name>/logs/ - e.g. "run" or
#                          "tool-wrye-bash". Keeps stdout to our own succinct
#                          status lines; gamescope/wine's own (very chatty)
#                          output goes to the logfile instead.
launch_exe() {
  local game="$1" exe="$2" default_no_gamescope="$3" label="$4" log_name="${5:-run}"
  local prefix
  prefix="$(prefix_dir "$game")"

  # Filters bash's own "<pid> Killed <command>" job-control notice (printed
  # whenever something below force-kills gamescope out from under us) out
  # of our stderr - alarming and redundant on top of the explanation we
  # already print ourselves. Everything else, including our own log_*
  # output, passes through unchanged. Set up before WINEPREFIX is exported
  # below so this filter process (a real subprocess, via process
  # substitution) doesn't inherit it and get swept up by force_kill_game's
  # own WINEPREFIX-based process scan.
  exec 2> >(grep -Ev '(Killed|Terminated)[[:space:]]{2,}[^[:space:]]' >&2)

  mount_cdrom "$game" "$prefix"

  local log_dir log_file
  log_dir="$(game_dir "$game")/logs"
  mkdir -p "$log_dir"
  log_file="$log_dir/$log_name.log"

  # Marker touched by force_kill_game's callers below (the Ctrl+C trap, and
  # both watchers) whenever *we* intentionally tore the session down - as
  # opposed to gamescope exiting (cleanly or not) entirely on its own.
  # Cleared per-run so a leftover marker from a previous launch can't bleed
  # into this one's status.
  local kill_marker="$log_dir/.$log_name.autokilled"
  rm -f "$kill_marker"

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

  # Under a desktop Wayland/X11 compositor (as opposed to gamescope being the
  # primary session, e.g. on the Steam Deck) gamescope's own window is just
  # an ordinary floating window by default, sized to whatever the game
  # requests - not fullscreen on the host display. -f/--fullscreen tells
  # gamescope to take over the whole screen, so we always pass it unless
  # explicitly disabled.
  if [ "${GAMESCOPE_FULLSCREEN:-1}" = "1" ]; then
    gamescope_args_arr=(-f "${gamescope_args_arr[@]}")
  fi

  export WINEPREFIX="$prefix"
  cd "$(dirname "$exe")"

  # $NO_GAMESCOPE wins if set; otherwise a per-game "no_gamescope" default
  # in config.json (for games that are simply incompatible with gamescope);
  # otherwise the caller's own default (0 for the recorded launch target,
  # 1 for a one-off exe override/tool).
  local no_gamescope
  no_gamescope="${NO_GAMESCOPE:-$(config_get "$game" no_gamescope "$default_no_gamescope")}"
  if [ "$no_gamescope" = "1" ]; then
    log_step "Launching $label $(dim "(gamescope disabled)"): $exe"
    log_info "Output logged to $(dim "$log_file")"
    exec wine "$exe" >"$log_file" 2>&1
  fi

  if ! command -v gamescope >/dev/null 2>&1; then
    log_warn "'gamescope' not found on PATH; launching without it."
    log_step "Launching $label: $exe"
    log_info "Output logged to $(dim "$log_file")"
    exec wine "$exe" >"$log_file" 2>&1
  fi

  log_step "Launching $label $(dim "in gamescope"): $exe"
  log_info "Output logged to $(dim "$log_file")"

  # Run gamescope in the background (instead of exec'ing it) so this shell
  # stays alive to watch for it outliving the game - see
  # watch_stuck_gamescope above - and to make sure Ctrl+C actually tears the
  # session down instead of leaving a stuck gamescope holding the terminal.
  # Its (very chatty) output goes to the logfile rather than our own
  # stdout, same as the direct-wine paths above.
  gamescope "${gamescope_args_arr[@]}" -- wine "$exe" >"$log_file" 2>&1 &
  local gs_pid=$!

  local -a watch_pids=()
  if [ "${GAMESCOPE_AUTO_KILL:-1}" = "1" ]; then
    watch_stuck_gamescope "$game" "$gs_pid" "$kill_marker" &
    watch_pids+=("$!")
    if [ "${WINE_HANG_AUTO_KILL:-1}" = "1" ]; then
      watch_hung_wine_log "$game" "$gs_pid" "$log_file" "$kill_marker" &
      watch_pids+=("$!")
    fi
  fi

  # A Ctrl+C (or `make`/a terminal closing) sends SIGINT/SIGTERM to this
  # whole process group, including gamescope - but if gamescope's own
  # shutdown path is what's stuck (the same upstream bug), it won't react.
  # Force-killing here guarantees the signal actually releases the terminal.
  trap ': >"$kill_marker"; force_kill_game "$game"' INT TERM

  local status=0
  # The 2>/dev/null hides bash's own "<pid> Killed <command>" job-control
  # notification for the (expected, by now) case where force_kill_game just
  # SIGKILL'd this job out from under us - it'd otherwise look like a crash.
  wait "$gs_pid" 2>/dev/null || status=$?
  if [ "${#watch_pids[@]}" -gt 0 ]; then
    kill "${watch_pids[@]}" 2>/dev/null || true
  fi

  # If something above force-killed the session on our behalf, that's a
  # successful (if forceful) cleanup from the user's point of view, not a
  # crash - report success rather than propagating SIGKILL/SIGTERM's raw
  # exit status up through `make` (which would otherwise print its own
  # alarming "Error 137"/"Error 143" on top of our own, already-printed
  # explanation of what happened).
  if [ -f "$kill_marker" ]; then
    rm -f "$kill_marker"
    status=0
  fi

  log_step "$label exited $(dim "(status $status)")"
  exit "$status"
}
