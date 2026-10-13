#!/usr/bin/env bash
# Publish the release in release/macos/ on GitHub, as a pre-release.
#
#   scripts/publish_release.sh
#
# Pushes main and the tag v<VERSION>, then creates the GitHub release with the
# disk image, its checksums and the FFmpeg source it bundles (which its LGPL
# licence asks to be offered beside it). Needs the GitHub CLI, logged in.
set -euo pipefail
source "$(dirname "$0")/common.sh"
fail() { echo "error: $*" >&2; exit 1; }
cd "$repo_dir"
version="$(tr -d ' \n' < "$version_file")"
dmg="$release_dir/sparta-$version-macos-arm64.dmg"
[[ -f "$dmg" ]] || fail "no $dmg; run scripts/release_macos.sh first"
git rev-parse -q --verify "refs/tags/v$version" > /dev/null || fail "no tag v$version"
if git ls-remote --exit-code --tags origin "refs/tags/v$version" > /dev/null 2>&1; then
    fail "v$version is already published"
fi
notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT
cat > "$notes" <<NOTES
**Alpha.** Only the opening of the game has been played, on macOS 26 with Apple Silicon. Expect bugs; see [what is missing](https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/blob/main/docs/MISSING.md).

### Install

1. Open \`sparta-$version-macos-arm64.dmg\` and drag **Sparta** into Applications.
2. The app is signed ad hoc, not notarized: the first time, macOS refuses to open it. Choose **Done**, then **System Settings › Privacy & Security › Open Anyway**. Or run \`xattr -dr com.apple.quarantine /Applications/Sparta.app\`.
3. At the first start, pick the disc image of **your own** copy of the game: the European release, \`UCES-01401\`, as an uncompressed \`.iso\`.

No game data is included in this release. Sparta is not affiliated with Sony Interactive Entertainment.

Needs a Mac with Apple Silicon. \`SHA256SUMS\` has the checksums; \`ffmpeg-*.tar.xz\` is the source of the FFmpeg the app bundles (LGPL).
NOTES
git push origin main "v$version"
gh release create "v$version" --title "Sparta $version" --prerelease --notes-file "$notes" \
    "$dmg" "$release_dir/SHA256SUMS" "$release_dir"/ffmpeg-*.tar.xz
