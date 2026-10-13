#!/usr/bin/env bash
# Build a release of the port for macOS and pack it as a disk image.
#
#   scripts/release_macos.sh
#
# Needs the recompiled code in generated/ (scripts/generate.sh). Builds a
# Release configuration with PortableKit's bundled FFmpeg in out-release/,
# then runs PortableKit's release script, which assembles Sparta.app, signs it
# ad hoc and writes the disk image to out/release-macos/dist.
# Like scripts/build.sh, it logs to ../work/build.log and ../work/build.status.
#
# PortableKit checks the program's imports against the SDK of its deployment
# target (macOS 13). Without that SDK installed, PORTABLEKIT_CHECK_SDK names
# another one; by default the newest macOS 15 SDK of the Command Line Tools.
set -uo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$repo_dir/../work"
mkdir -p "$work_dir"
log="$work_dir/build.log"
status="$work_dir/build.status"
if [[ ! -f "$repo_dir/generated/generated_registry.cpp" ]]; then
    echo "error: no recompiled code in generated/; run scripts/generate.sh first" >&2
    exit 1
fi
if [[ -z "${PORTABLEKIT_CHECK_SDK:-}" ]] && ! ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX13.*.sdk >/dev/null 2>&1; then
    sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.*.sdk 2>/dev/null | sort -V | tail -1)"
    [[ -n "$sdk" ]] && export PORTABLEKIT_CHECK_SDK="$sdk"
fi
echo running > "$status"
{
    echo "started $(date '+%Y-%m-%d %H:%M:%S') (release)"
    echo "checking imports against ${PORTABLEKIT_CHECK_SDK:-the macOS 13 SDK}"
    cmake -S "$repo_dir" -B "$repo_dir/out-release" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DPORTABLEKIT_RELEASE=ON -DPORTABLEKIT_FFMPEG=bundled &&
        cmake --build "$repo_dir/out-release" --target SpartaNative -j4 &&
        bash "$repo_dir/portablekit/scripts/release_macos.sh" --game "$repo_dir" "$repo_dir/out-release"
    code=$?
    echo "finished $(date '+%Y-%m-%d %H:%M:%S') exit=$code"
    exit $code
} 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
echo "$code" > "$status"
exit "$code"
