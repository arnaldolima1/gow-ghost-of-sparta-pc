#!/usr/bin/env bash
# Build the port (and the recompiled corpus, if generated/ has one).
#
#   scripts/build.sh
#
# Writes the whole log to ../work/build.log and its exit status to
# ../work/build.status, so progress can be checked from elsewhere
# (scripts/build_status.sh).
set -uo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$repo_dir/../work"
mkdir -p "$work_dir"
log="$work_dir/build.log"
status="$work_dir/build.status"
echo running > "$status"
{
    echo "started $(date '+%Y-%m-%d %H:%M:%S')"
    cmake -S "$repo_dir" -B "$repo_dir/out" -G Ninja &&
        cmake --build "$repo_dir/out" -j4
    code=$?
    echo "finished $(date '+%Y-%m-%d %H:%M:%S') exit=$code"
    exit $code
} 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
echo "$code" > "$status"
exit "$code"
