#!/usr/bin/env bash
# Build a release of the port for macOS and pack it as a disk image.
#
#   scripts/release_macos.sh
#
# The version is VERSION. When that version has already been published (its
# tag v<version> is on GitHub), the last number goes up by one first -- 0.1.0,
# 0.1.1, 0.1.2 -- and the change is committed. The tag v<version> is then set
# on the commit being built, so the program reports that version. Publish the
# result with scripts/publish_release.sh.
#
# Needs the recompiled code in generated/ (scripts/generate.sh) and a clean
# checkout. Builds a Release configuration with PortableKit's bundled FFmpeg
# in build/release/, runs PortableKit's release script (which assembles
# Sparta.app, signs it ad hoc and packs the disk image), and copies the
# results to release/macos/.
#
# PortableKit checks the program's imports against the SDK of its deployment
# target (macOS 13). Without that SDK installed, PORTABLEKIT_CHECK_SDK names
# another one; by default the newest macOS 15 SDK of the Command Line Tools.
set -uo pipefail
source "$(dirname "$0")/common.sh"
fail() { echo "error: $*" >&2; exit 1; }
cd "$repo_dir"
[[ -f generated/generated_registry.cpp ]] || fail "no recompiled code in generated/; run scripts/generate.sh first"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "the checkout has uncommitted changes; commit them first"

version="$(tr -d ' \n' < "$version_file")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION is not x.y.z: $version"
if git ls-remote --exit-code --tags origin "refs/tags/v$version" > /dev/null 2>&1; then
    IFS=. read -r major minor patch <<< "$version"
    version="$major.$minor.$((patch + 1))"
    echo "$version" > "$version_file"
    git commit -q -m "Version $version" -- "$version_file" || fail "cannot commit VERSION"
    echo "v${major}.${minor}.${patch} is published; this release is $version"
fi
git tag -f "v$version" > /dev/null

if [[ -z "${PORTABLEKIT_CHECK_SDK:-}" ]] && ! ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX13.*.sdk > /dev/null 2>&1; then
    sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.*.sdk 2> /dev/null | sort -V | tail -1)"
    [[ -n "$sdk" ]] && export PORTABLEKIT_CHECK_SDK="$sdk"
fi
export PORTABLEKIT_RELEASE_WORK="$release_work_dir"
mkdir -p "$logs_dir"
echo running > "$logs_dir/build.status"
{
    echo "started $(date '+%Y-%m-%d %H:%M:%S') (release $version)"
    echo "checking imports against ${PORTABLEKIT_CHECK_SDK:-the macOS 13 SDK}"
    cmake -S "$repo_dir" -B "$release_build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DPORTABLEKIT_RELEASE=ON -DPORTABLEKIT_FFMPEG=bundled &&
        cmake --build "$release_build_dir" --target SpartaNative -j4 &&
        bash "$repo_dir/portablekit/scripts/release_macos.sh" --game "$repo_dir" --version "$version" "$release_build_dir" &&
        {
            rm -rf "$release_dir" && mkdir -p "$release_dir" &&
                cp -R "$release_work_dir/stage/Sparta.app" "$release_dir/" &&
                cp "$release_work_dir/dist/"* "$release_dir/" &&
                echo && echo "Sparta $version: $release_dir" && ls -1 "$release_dir" &&
                echo && echo "Publish it with scripts/publish_release.sh"
        }
    code=$?
    echo "finished $(date '+%Y-%m-%d %H:%M:%S') exit=$code"
    exit $code
} 2>&1 | tee "$logs_dir/build.log"
code=${PIPESTATUS[0]}
echo "$code" > "$logs_dir/build.status"
exit "$code"
