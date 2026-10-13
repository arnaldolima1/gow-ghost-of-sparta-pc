#!/usr/bin/env bash
# Says whether the last scripts/build.sh or scripts/release_macos.sh is
# running, finished or failed.
source "$(dirname "$0")/common.sh"
status="$(cat "$logs_dir/build.status" 2>/dev/null || echo none)"
progress="$(grep -o '^\[[0-9]*/[0-9]*\]' "$logs_dir/build.log" 2>/dev/null | tail -1)"
what="$(grep -m1 -o '([a-z0-9. ]*build[^)]*)\|(release[^)]*)' "$logs_dir/build.log" 2>/dev/null)"
case "$status" in
    running) echo "running $what ${progress}" ;;
    0) echo "done $what ${progress}" ;;
    none) echo "never run" ;;
    *) echo "failed (exit $status) $what ${progress}"; grep -m5 -E 'error|FAILED|fail' "$logs_dir/build.log" ;;
esac
