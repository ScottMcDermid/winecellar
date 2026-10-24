#compdef make
# Native zsh tab completion for this project's `make <subcommand> ...` CLI:
# completes subcommand names, <game_name> (from games/), tool names, config
# keys, log names, and the GAME=/TOOL=/KEY=/NAME= variable forms.
#
# Usage - add this to ~/.zshrc, after compinit:
#   autoload -Uz compinit && compinit
#   eval "$(make -C /path/to/winecellar completion-zsh)"
# or source it directly:
#   source /path/to/winecellar/scripts/completion.zsh
#
# Only takes over completion for `make` while the current directory is
# inside a winecellar checkout (detected via the Makefile's distinctive
# .PHONY line); everywhere else it defers to zsh's own `_make` completion
# (if available), so this is safe to add globally.

_winecellar_root() {
  local dir="$PWD"
  while true; do
    if [[ -f "$dir/Makefile" ]] && grep -q '^\.PHONY: help init install run launch tool regedit config list clean kill logs completion completion-zsh$' "$dir/Makefile" 2>/dev/null; then
      print -r -- "$dir"
      return 0
    fi
    [[ "$dir" == / ]] && return 1
    dir="${dir:h}"
  done
}

_winecellar_games() {
  local root="$1"
  [[ -d "$root/games" ]] || return 0
  find "$root/games" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
}

_winecellar_tools() {
  local root="$1" game="${2:-}" file
  [[ -n "$game" ]] || return 0
  file="$root/games/$game/config.json"
  [[ -f "$file" ]] && (( $+commands[jq] )) || return 0
  jq -r 'keys[] | select(startswith("tool_")) | sub("^tool_"; "")' "$file" 2>/dev/null
}

_winecellar_logs() {
  local root="$1" game="${2:-}" dir
  [[ -n "$game" ]] || return 0
  dir="$root/games/$game/logs"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -name '*.log' -printf '%f\n' 2>/dev/null | sed 's/\.log$//'
}

_winecellar_config_keys() {
  local root="$1" game="${2:-}"
  print -l launch gamescope_args no_gamescope cd_image cd_drive
  _winecellar_tools "$root" "$game" | sed 's/^/tool_/'
}

_winecellar_make() {
  local root
  if ! root="$(_winecellar_root)"; then
    # Not inside this project: fall back to zsh's own `_make` completion
    # (file targets from the Makefile) if it's available, else plain files.
    if (( $+functions[_make] )); then
      _make
    else
      _files
    fi
    return
  fi

  local -a subcommands
  subcommands=(
    'help:show usage'
    'init:create a wine prefix for <game_name>'
    'install:run an installer/exe inside the prefix'
    'run:launch the recorded executable (gamescope on), or [exe] (gamescope off)'
    'launch:alias for run'
    'tool:record/launch an auxiliary exe in the prefix (gamescope off by default)'
    "regedit:launch wine's registry editor inside the prefix"
    'config:view or set an option in config.json'
    'list:list known games'
    'clean:delete one (or ALL) game directories, incl. prefix'
    "kill:force-kill a game's gamescope/wine session by hand"
    'logs:print gamescope/wine output from the last run'
    'completion:print a bash tab-completion script'
    'completion-zsh:print this zsh tab-completion script'
  )

  # Find the subcommand: the first word after `make` that isn't a VAR=value
  # assignment. words[1] is "make" itself; CURRENT is the index of the word
  # being completed.
  local i sub="" sub_index=0
  for (( i = 2; i < CURRENT; i++ )); do
    if [[ "${words[i]}" != *=* ]]; then
      sub="${words[i]}"
      sub_index=$i
      break
    fi
  done

  if [[ -z "$sub" ]]; then
    _describe 'subcommand' subcommands
    return
  fi

  # Positional (non VAR=value) args seen after the subcommand, not counting
  # the word currently being completed.
  local -a positional
  for (( i = sub_index + 1; i < CURRENT; i++ )); do
    [[ "${words[i]}" == *=* ]] && continue
    positional+=("${words[i]}")
  done
  local pos_count=${#positional[@]}

  case "${words[CURRENT]}" in
    GAME=*)
      compadd -P 'GAME=' -- $(_winecellar_games "$root")
      return
      ;;
    TOOL=*)
      compadd -P 'TOOL=' -- $(_winecellar_tools "$root" "${positional[1]:-}")
      return
      ;;
    KEY=*)
      compadd -P 'KEY=' -- $(_winecellar_config_keys "$root" "${positional[1]:-}")
      return
      ;;
    NAME=*)
      compadd -P 'NAME=' -- $(_winecellar_logs "$root" "${positional[1]:-}")
      return
      ;;
    EXE=* | VALUE=* | LAUNCH=*)
      # Free-form paths/values; fall back to normal filename completion.
      _files
      return
      ;;
  esac

  case "$sub" in
    init | install | run | launch | tool | regedit | clean | kill | logs | config)
      if (( pos_count == 0 )); then
        compadd -- $(_winecellar_games "$root")
      elif [[ "$sub" == tool && $pos_count -eq 1 ]]; then
        compadd -- $(_winecellar_tools "$root" "${positional[1]}")
      elif [[ "$sub" == logs && $pos_count -eq 1 ]]; then
        compadd -- $(_winecellar_logs "$root" "${positional[1]}")
      elif [[ "$sub" == config && $pos_count -eq 1 ]]; then
        compadd -- $(_winecellar_config_keys "$root" "${positional[1]}")
      elif [[ "$sub" == install || "$sub" == run || "$sub" == launch ]] || [[ "$sub" == tool && $pos_count -eq 2 ]]; then
        _files
      fi
      ;;
  esac
}

compdef _winecellar_make make
