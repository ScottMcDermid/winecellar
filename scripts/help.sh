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

echo "$(bold "winecellar") $(dim "- run Windows games on Linux, one isolated wine prefix per game")"
echo
echo "$(bold "Usage")"
cmd "make init <game_name>" "create a wine prefix for <game_name>"
cmd "make install <game_name> <exe>" "run an installer/exe inside the prefix"
cmd "make run <game_name> [exe]" "launch the recorded executable (gamescope on), or [exe] (gamescope off) (alias: launch)"
cmd "make tool <game_name> [name] [exe]" "record/launch an auxiliary exe in the prefix, e.g. a mod manager (gamescope off by default)"
cmd "make regedit <game_name>" "launch wine's registry editor inside the prefix"
cmd "make config <game_name> [key] [value]" "view or set an option in config.json"
cmd "make list" "list known games"
cmd "make clean <game_name>" "delete one game's directory, incl. prefix (asks to confirm)"
cmd "make clean" "delete ALL games' directories (asks to confirm)"
cmd "make kill <game_name>" "force-kill a game's gamescope/wine session by hand (auto-kill usually handles this)"
cmd "make logs <game_name> [name]" "print gamescope/wine output from the last run (default: run; or e.g. a tool's name)"
cmd "make completion" "print a bash tab-completion script (eval \"\$(make completion)\" in ~/.bashrc)"
cmd "make completion-zsh" "print a zsh tab-completion script (eval \"\$(make completion-zsh)\" in ~/.zshrc)"
echo
echo "$(bold "Paths with spaces")"
echo "  the <exe>/<tool exe> path can have spaces positionally, but extra"
echo "  optional args ([launch], config's [key] [value]) can't - use variables:"
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
echo "$(bold "Games incompatible with gamescope")"
echo "  some games/wine+dgVoodoo combos crash under gamescope for reasons"
echo "  outside this project's control; record a per-game default to always"
echo "  launch them with gamescope disabled (still overridable per-run via"
echo "  NO_GAMESCOPE=0):"
cmd "make config <game_name> no_gamescope 1" "always skip gamescope for this game"
echo
echo "$(bold "Env")"
flag "WINEARCH=win32|win64" "arch used by 'make init' (default: win64)"
flag "GAMESCOPE_ARGS='...'" "flags passed to gamescope for 'make run'"
flag "NO_GAMESCOPE=1" "skip gamescope and launch wine directly"
flag "GAMESCOPE_FORCE_GRAB_CURSOR=0" "disable the default --force-grab-cursor gamescope flag"
flag "GAMESCOPE_FULLSCREEN=0" "disable the default -f (fullscreen) gamescope flag"
flag "GAMESCOPE_AUTO_KILL=0" "disable auto-killing a gamescope session that outlives the game (known upstream bug)"
flag "GAMESCOPE_AUTO_KILL_GRACE=N" "seconds to wait before an auto-kill kicks in (default: 10)"
flag "WINE_HANG_AUTO_KILL=0" "disable auto-killing on a known wine-internal deadlock signature (e.g. quartz)"
flag "WINE_HANG_GRACE=N" "seconds of log inactivity after that signature before auto-killing (default: 15)"
flag "FOLLOW=1" "tail -f instead of printing once, for 'make logs'"
flag "NO_COLOR=1" "disable colored/styled output"
