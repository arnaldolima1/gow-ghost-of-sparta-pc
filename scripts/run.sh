#!/usr/bin/env bash
# Start the port with a window, for playing by hand.
#
#   scripts/run.sh [extra environment, e.g. SPARTA_PERF=log]
#
# Data folder: SPARTA_DATA_DIR, or ../work/data beside this repository.
# Esc opens the menu (settings, key bindings). Close the window to quit.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
export SPARTA_DATA_DIR="${SPARTA_DATA_DIR:-$repo_dir/../work/data}"
exec env "$@" "$repo_dir/out/bin/SpartaNative"
