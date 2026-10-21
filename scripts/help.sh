#!/usr/bin/env bash
# Pretty-printed usage for `make help` (the default goal).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

cmd() {
  if [ -n "${2:-}" ]; then
    printf '  %s%-43s%s %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"
  else
    printf '  %s%s%s\n' "$C_CYAN" "$1" "$C_RESET"
  fi
}
flag() { printf '  %s%-23s%s %s\n' "$C_MAGENTA" "$1" "$C_RESET" "$2"; }

echo "$(bold "game-framework") $(dim "— run Windows games on Linux, one isolated wine prefix per game")"
echo
echo "$(bold "Usage")"
cmd "make init <game_name>" "create a wine prefix for <game_name>"
cmd "make install <game_name> <exe>" "run an installer/exe inside the prefix"
cmd "make run <game_name> [exe]" "launch the recorded executable (gamescope on), or [exe] (gamescope off) (alias: launch)"
cmd "make tool <game_name> [name] [exe]" "record/launch an auxiliary exe in the prefix, e.g. a mod manager (gamescope off by default)"
cmd "make config <game_name> [key] [value]" "view or set an option in config.json"
cmd "make list" "list known games"
cmd "make clean <game_name>" "delete one game's directory, incl. prefix (asks to confirm)"
cmd "make clean" "delete ALL games' directories (asks to confirm)"
echo
echo "$(bold "Paths with spaces")"
echo "  the <exe>/<tool exe> path can have spaces positionally, but extra"
echo "  optional args ([launch], config's [key] [value]) can't — use variables:"
cmd "make install GAME=<game_name> EXE='/path/with spaces/setup.exe' [LAUNCH='...']" ""
cmd "make run GAME=<game_name> EXE='/path/with spaces/game.exe'" ""
cmd "make tool GAME=<game_name> TOOL=<name> EXE='/path/with spaces/tool.exe'" ""
echo
echo "$(bold "CD-ROM emulation")"
echo "  some older games refuse to run (or ask you to insert the disc) unless"
echo "  a drive is specifically flagged as a CD-ROM. Record a disc image or an"
echo "  already-extracted disc folder once, and it's mounted automatically on"
echo "  every launch (run or tool):"
cmd "make config <game_name> cd_image <path-to.iso-or-folder>" "disc image/folder to mount"
cmd "make config <game_name> cd_drive <letter>" "drive letter to use (default: d)"
echo
echo "$(bold "Env")"
flag "WINEARCH=win32|win64" "arch used by 'make init' (default: win64)"
flag "GAMESCOPE_ARGS='...'" "flags passed to gamescope for 'make run'"
flag "NO_GAMESCOPE=1" "skip gamescope and launch wine directly"
flag "GAMESCOPE_FORCE_GRAB_CURSOR=0" "disable the default --force-grab-cursor gamescope flag"
flag "GAMESCOPE_FULLSCREEN=0" "disable the default -f (fullscreen) gamescope flag"
flag "NO_COLOR=1" "disable colored/styled output"
