# Publish the release in release\windows\ on GitHub, as a pre-release.
#
#   powershell -ExecutionPolicy Bypass -File scripts\publish_release_windows.ps1
#
# The Windows counterpart of scripts/publish_release.sh. Pushes main and the
# tag v<VERSION>, then creates the GitHub release with the zip, its checksums
# and the FFmpeg source it bundles. When the release of that version already
# exists (made on the Mac with scripts/publish_release.sh), adds the Windows
# files to it instead. Needs the GitHub CLI, logged in.
$ErrorActionPreference = 'Stop'
function Fail([string]$message) { [Console]::Error.WriteLine("error: $message"); exit 1 }

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$releaseDir = Join-Path $repo 'release\windows'
$version = (Get-Content (Join-Path $repo 'VERSION') -Raw).Trim()
$zip = Join-Path $releaseDir "sparta-$version-windows-x64.zip"
if (-not (Test-Path $zip)) { Fail "no $zip; run scripts\release_windows.ps1 first" }
cmd /c "git rev-parse -q --verify refs/tags/v$version >nul 2>&1"
if ($LASTEXITCODE -ne 0) { Fail "no tag v$version" }
$ffmpeg = Get-ChildItem $releaseDir -Filter 'ffmpeg-*-source.tar.gz' | Select-Object -First 1 -ExpandProperty FullName
if (-not $ffmpeg) { Fail 'no FFmpeg source in release\windows' }
$sums = Join-Path $releaseDir 'SHA256SUMS'
$assets = @($zip, $ffmpeg)

cmd /c "gh release view v$version >nul 2>&1"
if ($LASTEXITCODE -eq 0) {
    # Released already: add the Windows files, renaming the checksums so they
    # do not replace the other platforms' SHA256SUMS.
    $windowsSums = Join-Path $releaseDir 'SHA256SUMS-windows'
    Copy-Item $sums $windowsSums
    gh release upload "v$version" @assets $windowsSums --clobber
    if ($LASTEXITCODE -ne 0) { Fail 'gh release upload failed' }
    Write-Host "added the Windows build to v$version; add a Windows section to its notes by hand (gh release edit)"
    exit 0
}

$zipName = Split-Path -Leaf $zip
$notes = @"
**Alpha.** Only the opening of the game has been played. Expect bugs; see [what is missing](https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/blob/main/docs/MISSING.md).

**This release is for Windows.** For macOS and Android, use the most recent [release](https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/releases) that has them.

### Windows

1. Unzip ``$zipName`` anywhere (not inside Program Files) and start **Sparta.exe**. Nothing is installed.
2. The program is not signed: if Windows SmartScreen stops it, click **More info**, then **Run anyway**.
3. At the first start, pick the disc image of **your own** copy of the game: the European release, ``UCES-01401``, as an uncompressed ``.iso``.

Needs Windows 10 or 11 (64-bit) and a graphics card with Vulkan and up-to-date drivers. Tested on Windows 11 with an AMD Radeon RX 7600: 60 fps and full speed in the first level.

No game data is included in this release. Sparta is not affiliated with Sony Interactive Entertainment.

``SHA256SUMS`` has the checksums; ``ffmpeg-*-source.tar.gz`` is the source of the FFmpeg the zip bundles (LGPL).
"@
$notesFile = Join-Path $env:TEMP "sparta-$version-notes.md"
[IO.File]::WriteAllText($notesFile, $notes)

cmd /c "git push origin main v$version 2>&1"
if ($LASTEXITCODE -ne 0) { Fail 'git push failed' }
gh release create "v$version" --title "Sparta $version" --prerelease --notes-file $notesFile @assets $sums
if ($LASTEXITCODE -ne 0) { Fail 'gh release create failed' }
Remove-Item $notesFile
