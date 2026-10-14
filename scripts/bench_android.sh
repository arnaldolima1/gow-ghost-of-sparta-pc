#!/usr/bin/env bash
# Measure the game on the Android phone connected by USB, the same stretch of
# play every time: the boat's first fight, through scripted input.
#
#   scripts/bench_android.sh NAME [profile] [SPARTA_VARIABLE=value ...]
#
# Needs a DEBUGGABLE=1 build installed (scripts/build_android.sh) with the
# game set up in it. Writes build/bench/NAME.log (the game's whole log),
# prints the [perf] lines of the fight and their averages. With `profile`,
# also records 15 s of simpleperf into build/bench/NAME.data (see
# tools/perf/profile_report.py).
#
# The script presses × through the menus, picks a difficulty, skips the intro
# movie with START and leaves the fight to play by itself. It sets the
# variables in env.txt in the app's storage for the run and removes them
# afterwards; it never touches settings.ini, so set what is measured
# (internal scale, frame skip, Limit to 30 fps) with variables, e.g.
# SPARTA_INTERNAL_SCALE=2 SPARTA_FRAME_SKIP=0 SPARTA_HALF_RATE=0.
#
# Compare runs with care: the fight is not the same twice (the clock starts
# from the wall clock), so average several runs, and compare CPU work in
# absolute cycles from profiles rather than in percentages.
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -ge 1 ]] || { echo "usage: $0 NAME [profile] [VARIABLE=value ...]" >&2; exit 1; }
name=$1
shift
profile=0
if [[ "${1:-}" == profile ]]; then
    profile=1
    shift
fi
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$ANDROID_HOME/platform-tools/adb"
app=io.sparta
out="$build_root/bench"
mkdir -p "$out"

env_file="$out/$name.env.txt"
{
    echo SPARTA_NO_LAUNCHER=1
    echo SPARTA_PERF=log
    echo SPARTA_FRAME_SKIP=0
    echo "SPARTA_INPUT_SCRIPT=900:pad a;1200:pad a;1500:pad a;1800:pad a;2100:pad a;2600:pad start;4400:axis leftx 0"
    for variable in "$@"; do echo "$variable"; done
} > "$env_file"

log() { "$adb" shell "run-as $app cat files/SpartaNative.log" 2> /dev/null || true; }
cleanup() {
    "$adb" shell am force-stop "$app" > /dev/null 2>&1 || true
    "$adb" shell "run-as $app rm -f files/env.txt" > /dev/null 2>&1 || true
    "$adb" shell svc power stayon false > /dev/null 2>&1 || true
}
trap cleanup EXIT

"$adb" shell svc power stayon usb
"$adb" push "$env_file" /data/local/tmp/sparta-env.txt > /dev/null
"$adb" shell am force-stop "$app"
"$adb" shell "run-as $app sh -c 'cp /data/local/tmp/sparta-env.txt files/env.txt; rm -f files/SpartaNative.log'"
"$adb" shell rm -f /data/local/tmp/sparta-env.txt
"$adb" shell am start -n "$app/io.github.teamgdb.portablekit.GameActivity" > /dev/null

# The script's own log lines are the milestones. A crash ends the wait.
wait_for() {
    local marker=$1 waited=0
    until log | grep -q "$marker"; do
        sleep 3
        waited=$((waited + 3))
        if [[ -z "$("$adb" shell pidof "$app" 2> /dev/null || true)" ]]; then
            echo "the game is not running any more; its log ends:" >&2
            log | tail -5 >&2
            exit 1
        fi
        if ((waited > 600)); then
            echo "no '$marker' after 10 minutes" >&2
            exit 1
        fi
    done
}
wait_for "frame 2600: pad start"
sleep 8
if [[ $profile == 1 ]]; then
    "$adb" shell "simpleperf record --app $app -g --duration 15 -f 2000 -o /data/local/tmp/sparta-perf.data" > /dev/null 2>&1
    "$adb" pull /data/local/tmp/sparta-perf.data "$out/$name.data" > /dev/null
    "$adb" shell rm -f /data/local/tmp/sparta-perf.data
fi
wait_for "frame 4400: axis"
log > "$out/$name.log"

sed -n '/frame 2600: pad start/,/frame 4400: axis/p' "$out/$name.log" | grep "\[perf\] fps" | tail -15 |
    awk -F'|' '{print $1 "|" $3 "|" $6}' | sed 's/\[perf\] //' > "$out/$name.lines"
cat "$out/$name.lines"
awk '{for (i = 1; i <= NF; i++) {if ($i == "speed") s += $(i + 1); if ($i == "guest") g += $(i + 1);
      if ($i == "render") r += $(i + 1); if ($i == "gpu") u += $(i + 1)} n++}
     END {if (n) printf "average: speed %.1f%% guest %.2f render %.2f gpu %.2f ms (%d seconds)\n", s / n, g / n, r / n, u / n, n}' \
    "$out/$name.lines"
