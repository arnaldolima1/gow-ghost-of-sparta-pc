#!/usr/bin/env bash
# Start the port with a window, for playing by hand.
#
#   scripts/run.sh [extra environment, e.g. SPARTA_PERF=log]
#
# Data folder: SPARTA_DATA_DIR; else ../work/data beside this repository when
# it exists (a development layout); else the port's own per-user folder.
# Esc opens the menu (settings, key bindings). Close the window to quit.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${SPARTA_DATA_DIR:-}" && -d "$repo_dir/../work/data" ]]; then
    export SPARTA_DATA_DIR="$repo_dir/../work/data"
fi
exec env "$@" "$repo_dir/out/bin/SpartaNative"
