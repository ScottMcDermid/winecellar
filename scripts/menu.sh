#!/usr/bin/env bash
# Interactive menu for browsing/launching games, and setting up new games
# and tools - a friendlier front end over the make subcommands above for
# anyone who'd rather pick from a numbered list than remember game names
# and flags by hand. Delegates to the other scripts in this directory for
# every actual operation, so behavior (logs, gamescope, confirmations,
# etc.) stays identical either way.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
check_deps jq

# Every prompt below reads from the controlling terminal directly (not
# stdin) via fd 3, same trick install.sh uses for its own numbered
# prompts - makes a bad invocation (piped input, no TTY) fail loudly up
# front instead of hanging or behaving strangely deep in some submenu.
exec 3</dev/tty 2>/dev/null || die "make menu needs an interactive terminal (no TTY attached)."

ask() { # ask <prompt> -> sets REPLY (possibly empty)
  read -r -u 3 -p "$(printf '%s%s%s ' "$C_BOLD" "$1" "$C_RESET")" REPLY || REPLY=""
}

pause() {
  read -r -u 3 -p "$(dim "Press enter to continue...")" _ || true
}

item() { printf '  %s%2s)%s %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"; }

list_games() {
  mapfile -t GAMES < <(
    [ -d "$GAMES_DIR" ] && find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
  )
}

list_tools() {
  local game="$1"
  mapfile -t TOOLS < <(
    jq -r 'keys[] | select(startswith("tool_")) | sub("^tool_"; "")' "$(config_file "$game")" 2>/dev/null | sort
  )
}

new_game_flow() {
  echo
  ask "Name for the new game (no spaces):"
  local name="$REPLY"
  if [ -z "$name" ]; then
    log_info "Cancelled."
    return
  fi
  if [[ "$name" =~ [[:space:]/] ]]; then
    log_error "game names can't contain spaces or '/'."
    pause
    return
  fi
  if [ -d "$(game_dir "$name")" ]; then
    log_warn "'$name' already exists."
    pause
    return
  fi

  "$SCRIPT_DIR/init.sh" "$name" || { pause; return; }

  echo
  ask "Path to an installer/exe to install now (blank to skip):"
  local exe="$REPLY"
  if [ -n "$exe" ]; then
    "$SCRIPT_DIR/install.sh" "$name" "$exe" || true
  fi
  pause
}

tools_menu() {
  local game="$1"
  while true; do
    list_tools "$game"
    echo
    echo "$(bold "Tools for $game") $(dim "(${#TOOLS[@]})")"
    local i
    for i in "${!TOOLS[@]}"; do
      item "$((i + 1))" "${TOOLS[$i]} $(dim "- $(config_get "$game" "tool_${TOOLS[$i]}")")"
    done
    item "+" "Record a new tool"
    item "b" "Back"
    echo
    ask "Select:"
    case "$REPLY" in
      b | B | "") return ;;
      +)
        ask "Tool name (e.g. wrye-bash):"
        local tname="$REPLY"
        if [ -z "$tname" ]; then
          log_info "Cancelled."
          pause
          continue
        fi
        ask "Path to its exe:"
        local texe="$REPLY"
        if [ -z "$texe" ]; then
          log_info "Cancelled."
          pause
          continue
        fi
        "$SCRIPT_DIR/tool.sh" "$game" "$tname" "$texe" || true
        pause
        ;;
      *[!0-9]*)
        log_error "enter a number, '+', or 'b'."
        pause
        ;;
      *)
        if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#TOOLS[@]}" ]; then
          "$SCRIPT_DIR/tool.sh" "$game" "${TOOLS[$((REPLY - 1))]}" || true
          pause
        else
          log_error "no such tool."
          pause
        fi
        ;;
    esac
  done
}

config_menu() {
  local game="$1"
  while true; do
    echo
    echo "$(bold "Config for $game")"
    if [ -f "$(config_file "$game")" ]; then
      jq -C '.' "$(config_file "$game")"
    else
      echo '{}'
    fi
    echo
    item "1" "Set a value"
    item "b" "Back"
    echo
    ask "Select:"
    case "$REPLY" in
      1)
        ask "Key (e.g. gamescope_args, no_gamescope, cd_image, cd_drive):"
        local key="$REPLY"
        [ -z "$key" ] && continue
        ask "Value:"
        local value="$REPLY"
        config_set "$game" "$key" "$value"
        log_success "Set $(bold "$key") = $(bold "$value")."
        pause
        ;;
      b | B | "") return ;;
      *)
        log_error "enter 1 or 'b'."
        pause
        ;;
    esac
  done
}

logs_menu() {
  local game="$1"
  local log_dir
  log_dir="$(game_dir "$game")/logs"
  mapfile -t LOGNAMES < <(
    [ -d "$log_dir" ] && find "$log_dir" -maxdepth 1 -name '*.log' -printf '%f\n' 2>/dev/null | sed 's/\.log$//' | sort
  )
  if [ "${#LOGNAMES[@]}" -eq 0 ]; then
    log_info "No logs yet for $(bold "$game")."
    pause
    return
  fi
  echo
  echo "$(bold "Logs for $game")"
  local i
  for i in "${!LOGNAMES[@]}"; do
    item "$((i + 1))" "${LOGNAMES[$i]}"
  done
  item "b" "Back"
  echo
  ask "Select a log to view:"
  case "$REPLY" in
    b | B | "") return ;;
    *[!0-9]*)
      log_error "enter a number or 'b'."
      pause
      ;;
    *)
      if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#LOGNAMES[@]}" ]; then
        echo
        "$SCRIPT_DIR/logs.sh" "$game" "${LOGNAMES[$((REPLY - 1))]}" || true
        pause
      else
        log_error "no such log."
        pause
      fi
      ;;
  esac
}

game_menu() {
  local game="$1"
  while true; do
    local launch
    launch="$(config_get "$game" launch)"
    list_tools "$game"
    echo
    echo "$(bold "$game")"
    if [ -n "$launch" ]; then
      echo "  $(dim "launch target:") $launch"
    else
      echo "  $(dim "launch target: not set")"
    fi
    [ "${#TOOLS[@]}" -gt 0 ] && echo "  $(dim "tools:") ${TOOLS[*]}"
    echo
    item "1" "Run / launch"
    item "2" "Install / reinstall"
    item "3" "Tools"
    item "4" "Config"
    item "5" "Registry editor"
    item "6" "View logs"
    item "7" "Kill stuck session"
    item "8" "Delete this game"
    item "b" "Back"
    echo
    ask "Select:"
    case "$REPLY" in
      1)
        if [ -z "$launch" ]; then
          log_error "no launch target recorded yet; install something first."
          pause
        else
          "$SCRIPT_DIR/run.sh" "$game" || true
          pause
        fi
        ;;
      2)
        ask "Path to an installer/exe (blank to cancel):"
        local exe="$REPLY"
        [ -n "$exe" ] && { "$SCRIPT_DIR/install.sh" "$game" "$exe" || true; }
        pause
        ;;
      3) tools_menu "$game" ;;
      4) config_menu "$game" ;;
      5)
        "$SCRIPT_DIR/regedit.sh" "$game" || true
        pause
        ;;
      6) logs_menu "$game" ;;
      7)
        "$SCRIPT_DIR/kill.sh" "$game" || true
        pause
        ;;
      8)
        "$SCRIPT_DIR/clean.sh" "$game" || true
        [ -d "$(game_dir "$game")" ] || return
        pause
        ;;
      b | B | "") return ;;
      *)
        log_error "unknown choice."
        pause
        ;;
    esac
  done
}

main_menu() {
  while true; do
    list_games
    echo
    echo "$(bold "winecellar")"
    echo
    if [ "${#GAMES[@]}" -eq 0 ]; then
      echo "  $(dim "No games yet.")"
    else
      local i g l
      for i in "${!GAMES[@]}"; do
        g="${GAMES[$i]}"
        l="$(config_get "$g" launch)"
        if [ -n "$l" ]; then
          item "$((i + 1))" "$(printf '%-20s %s' "$g" "$(dim "$l")")"
        else
          item "$((i + 1))" "$(printf '%-20s %s' "$g" "$(dim "no launch target")")"
        fi
      done
    fi
    item "+" "New game"
    item "q" "Quit"
    echo
    ask "Select a game, or an action above:"
    case "$REPLY" in
      q | Q | "")
        echo
        exit 0
        ;;
      +) new_game_flow ;;
      *[!0-9]*)
        log_error "enter a number, '+', or 'q'."
        pause
        ;;
      *)
        if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#GAMES[@]}" ]; then
          game_menu "${GAMES[$((REPLY - 1))]}"
        else
          log_error "no such game."
          pause
        fi
        ;;
    esac
  done
}

main_menu
