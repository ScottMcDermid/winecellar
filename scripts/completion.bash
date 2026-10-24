#!/usr/bin/env bash
# Tab completion for this project's `make <subcommand> ...` CLI: completes
# subcommand names, <game_name> (from games/), tool names, config keys, log
# names, and the GAME=/TOOL=/KEY=/NAME= variable forms.
#
# Usage - either source it directly:
#   source /path/to/winecellar/scripts/completion.bash
# or, to avoid hardcoding a path, add this to ~/.bashrc instead:
#   eval "$(make -C /path/to/winecellar completion)"
#
# Only takes over completion for `make` while the current directory is
# inside a winecellar checkout (detected via the Makefile's distinctive
# .PHONY line); everywhere else it defers to whatever `make` completion
# (if any) was already registered, so this is safe to source globally.

_winecellar_root() {
  local dir="$PWD"
  while :; do
    if [ -f "$dir/Makefile" ] && grep -q '^\.PHONY: help init install run launch tool regedit config list menu clean kill logs completion completion-zsh$' "$dir/Makefile" 2>/dev/null; then
      printf '%s' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

_winecellar_games() {
  local root="$1"
  [ -d "$root/games" ] || return 0
  find "$root/games" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
}

_winecellar_tools() {
  local root="$1" game="${2:-}" file
  [ -n "$game" ] || return 0
  file="$root/games/$game/config.json"
  [ -f "$file" ] && command -v jq >/dev/null 2>&1 || return 0
  jq -r 'keys[] | select(startswith("tool_")) | sub("^tool_"; "")' "$file" 2>/dev/null
}

_winecellar_logs() {
  local root="$1" game="${2:-}" dir
  [ -n "$game" ] || return 0
  dir="$root/games/$game/logs"
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -name '*.log' -printf '%f\n' 2>/dev/null | sed 's/\.log$//'
}

_winecellar_config_keys() {
  local root="$1" game="${2:-}"
  printf '%s\n' launch gamescope_args no_gamescope cd_image cd_drive
  _winecellar_tools "$root" "$game" | sed 's/^/tool_/'
}

_winecellar_make() {
  local root
  if ! root="$(_winecellar_root)"; then
    # Not inside this project: fall back to whatever generic `make`
    # completion (e.g. bash-completion's _make) was registered, if any.
    if declare -F _make >/dev/null 2>&1; then
      _make
    fi
    return
  fi

  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]:-}"

  local -a subcommands=(help init install run launch tool regedit config list menu clean kill logs completion completion-zsh)

  # Find the subcommand: the first word after `make` that isn't a VAR=value
  # assignment.
  local sub="" i word sub_index=-1
  for ((i = 1; i < COMP_CWORD; i++)); do
    word="${COMP_WORDS[i]}"
    case "$word" in
      *=*) continue ;;
      *)
        sub="$word"
        sub_index="$i"
        break
        ;;
    esac
  done

  if [ -z "$sub" ]; then
    COMPREPLY=($(compgen -W "${subcommands[*]}" -- "$cur"))
    return
  fi

  # Positional (non VAR=value) args seen after the subcommand, not counting
  # the word currently being completed.
  local -a positional=()
  for ((i = sub_index + 1; i < COMP_CWORD; i++)); do
    word="${COMP_WORDS[i]}"
    case "$word" in
      *=*) continue ;;
      *) positional+=("$word") ;;
    esac
  done
  local pos_count="${#positional[@]}"

  case "$cur" in
    GAME=*)
      COMPREPLY=($(compgen -P 'GAME=' -W "$(_winecellar_games "$root")" -- "${cur#GAME=}"))
      return
      ;;
    TOOL=*)
      COMPREPLY=($(compgen -P 'TOOL=' -W "$(_winecellar_tools "$root" "${positional[0]:-}")" -- "${cur#TOOL=}"))
      return
      ;;
    KEY=*)
      COMPREPLY=($(compgen -P 'KEY=' -W "$(_winecellar_config_keys "$root" "${positional[0]:-}")" -- "${cur#KEY=}"))
      return
      ;;
    NAME=*)
      COMPREPLY=($(compgen -P 'NAME=' -W "$(_winecellar_logs "$root" "${positional[0]:-}")" -- "${cur#NAME=}"))
      return
      ;;
    EXE=* | VALUE=* | LAUNCH=*)
      # Free-form paths/values; leave it to readline's default filename
      # completion rather than guessing.
      return
      ;;
  esac

  case "$sub" in
    init | install | run | launch | tool | regedit | clean | kill | logs | config)
      if [ "$pos_count" -eq 0 ]; then
        COMPREPLY=($(compgen -W "$(_winecellar_games "$root")" -- "$cur"))
      elif [ "$sub" = "tool" ] && [ "$pos_count" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$(_winecellar_tools "$root" "${positional[0]}")" -- "$cur"))
      elif [ "$sub" = "logs" ] && [ "$pos_count" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$(_winecellar_logs "$root" "${positional[0]}")" -- "$cur"))
      elif [ "$sub" = "config" ] && [ "$pos_count" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$(_winecellar_config_keys "$root" "${positional[0]}")" -- "$cur"))
      elif [ "$sub" = "install" ] || [ "$sub" = "run" ] || [ "$sub" = "launch" ] || { [ "$sub" = "tool" ] && [ "$pos_count" -eq 2 ]; }; then
        compopt -o filenames 2>/dev/null
        COMPREPLY=($(compgen -f -- "$cur"))
      fi
      ;;
  esac
}

complete -F _winecellar_make make
