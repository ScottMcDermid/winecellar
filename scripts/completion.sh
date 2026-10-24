#!/usr/bin/env bash
# Prints scripts/completion.bash, for `make completion` - meant to be eval'd:
#   eval "$(make completion)"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "$SCRIPT_DIR/completion.bash"
