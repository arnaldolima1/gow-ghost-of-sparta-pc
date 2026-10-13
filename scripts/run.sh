#!/usr/bin/env bash
# Play, from the everyday build.
#
#   scripts/run.sh [VARIABLE=value ...]     e.g. scripts/run.sh SPARTA_PERF=log
#
# Esc opens the menu (settings, key bindings). Close the window to quit.
set -euo pipefail
source "$(dirname "$0")/common.sh"
exec env "$@" "$dev_dir/bin/SpartaNative"
