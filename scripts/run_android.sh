#!/usr/bin/env bash
# Install the APK from scripts/build_android.sh on a device or the emulator,
# and start it.
#
#   scripts/run_android.sh [AVD name]
#
# With no device connected, starts the emulator (the AVD named, else the first
# one there is) and waits for it. The app keeps its data across installs while
# the APK is signed with the same key.
#
# On the device, the setup asks for the disc image in Android's file picker. To
# get one onto the emulator first:
#   adb push "/path/to/God of War - Ghost of Sparta.iso" /sdcard/Download/
set -euo pipefail
source "$(dirname "$0")/common.sh"
fail() { echo "error: $*" >&2; exit 1; }
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$ANDROID_HOME/platform-tools/adb"
emulator="$ANDROID_HOME/emulator/emulator"
apk="$build_root/android/dist/Sparta-android-arm64.apk"
app=io.sparta
[[ -f "$apk" ]] || fail "no $apk; run scripts/build_android.sh first"

if [[ -z "$("$adb" devices | awk 'NR > 1 && $2 == "device"')" ]]; then
    avd="${1:-$("$emulator" -list-avds | head -1)}"
    [[ -n "$avd" ]] || fail "no device connected and no emulator (AVD) to start"
    echo "starting the emulator $avd"
    nohup "$emulator" -avd "$avd" -gpu host > "$build_root/logs/emulator.log" 2>&1 &
    "$adb" wait-for-device
    until [[ "$("$adb" shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" == 1 ]]; do sleep 2; done
fi
echo "installing $apk"
"$adb" install -r "$apk"
"$adb" shell am start -n "$app/io.github.teamgdb.portablekit.GameActivity"
echo "started; its log: $adb shell run-as $app cat files/SpartaNative.log (with a DEBUGGABLE=1 build)"
