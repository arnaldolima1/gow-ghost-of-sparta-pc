#!/usr/bin/env bash
# Says whether scripts/build.sh is running, finished or failed.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$repo_dir/../work"
status="$(cat "$work_dir/build.status" 2>/dev/null || echo none)"
progress="$(grep -o '^\[[0-9]*/[0-9]*\]' "$work_dir/build.log" 2>/dev/null | tail -1)"
case "$status" in
    running) echo "running ${progress}" ;;
    0) echo "done ${progress}" ;;
    none) echo "never run" ;;
    *) echo "failed (exit $status) ${progress}"; grep -m5 -E 'error|FAILED' "$work_dir/build.log" ;;
esac
