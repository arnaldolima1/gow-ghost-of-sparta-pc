#!/usr/bin/env bash
# Build the Android APK of a release, after scripts/release_macos.sh has set
# its version and tag.
#
#   scripts/release_android.sh
#
# Builds from the commit tagged v<VERSION> (the checkout must be at it and
# clean), signs with the release key and copies the APK to release/android/.
# Publish it with scripts/publish_release.sh, together with the macOS release.
#
# The release key signs every version, so each installs over the one before
# and keeps the player's data. It is not in the repository: SPARTA_KEYS names
# a file setting KEYSTORE, KEYSTORE_PASS and KEY_ALIAS, by default
# ../work/keys/release.env beside the checkout. Keep a copy of the key: a
# version signed with another cannot replace one already installed.
set -uo pipefail
source "$(dirname "$0")/common.sh"
fail() { echo "error: $*" >&2; exit 1; }
cd "$repo_dir"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "the checkout has uncommitted changes; commit them first"
version="$(tr -d ' \n' < "$version_file")"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse -q --verify "refs/tags/v$version^{commit}")" ]] ||
    fail "HEAD is not v$version; run scripts/release_macos.sh first"
keys="${SPARTA_KEYS:-$repo_dir/../work/keys/release.env}"
[[ -f "$keys" ]] || fail "no release key settings in $keys; set SPARTA_KEYS"
set -a
# shellcheck disable=SC1090
source "$keys"
set +a
[[ -f "${KEYSTORE:-}" ]] || fail "the release key $KEYSTORE is missing"

VERSION_NAME="$version" VERSION_CODE="$(git rev-list --count HEAD)" bash "$repo_dir/scripts/build_android.sh" ||
    fail "the Android build failed; see build/logs/build.log"
mkdir -p "$android_release_dir"
rm -f "$android_release_dir"/*.apk
apk="$android_release_dir/sparta-$version-android-arm64.apk"
cp "$build_root/android/dist/Sparta-android-arm64.apk" "$apk"
(cd "$android_release_dir" && shasum -a 256 "$(basename "$apk")" > SHA256SUMS)
echo
echo "Sparta $version for Android: $apk"
echo "Publish it with scripts/publish_release.sh"
