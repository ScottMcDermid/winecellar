#!/usr/bin/env bash
# Prints scripts/completion.zsh, for `make completion-zsh` - meant to be
# eval'd:
#   eval "$(make completion-zsh)"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "$SCRIPT_DIR/completion.zsh"
