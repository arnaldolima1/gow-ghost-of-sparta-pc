#!/usr/bin/env bash
# Build the port for everyday use in build/dev/, with the recompiled game
# code when generated/ has it.
#
#   scripts/build.sh
#
# Logs to build/logs/build.log; scripts/build_status.sh reads it.
set -uo pipefail
source "$(dirname "$0")/common.sh"
mkdir -p "$logs_dir"
echo running > "$logs_dir/build.status"
{
    echo "started $(date '+%Y-%m-%d %H:%M:%S') (dev build)"
    cmake -S "$repo_dir" -B "$dev_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DPORTABLEKIT_FFMPEG=system &&
        cmake --build "$dev_dir" -j4
    code=$?
    echo "finished $(date '+%Y-%m-%d %H:%M:%S') exit=$code"
    exit $code
} 2>&1 | tee "$logs_dir/build.log"
code=${PIPESTATUS[0]}
echo "$code" > "$logs_dir/build.status"
exit "$code"
