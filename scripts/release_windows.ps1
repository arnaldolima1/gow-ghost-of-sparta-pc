# Build a release of the port for Windows and pack it as a zip.
#
#   powershell -ExecutionPolicy Bypass -File scripts\release_windows.ps1 [-Sdl3 DIR] [-Jobs N]
#
# The Windows counterpart of scripts/release_macos.sh, and it versions the same
# way: the version is VERSION; when that version has already been published
# (its tag v<version> is on GitHub), the last number goes up by one first and
# the change is committed. The tag v<version> is then set on the commit being
# built, so the program reports that version. Publish the result with
# scripts\publish_release_windows.ps1.
#
# Needs the recompiled code in generated\ and a clean checkout, Visual Studio
# 2022 with clang-cl (see docs/WINDOWS.md), CMake and Ninja. Builds a Release
# configuration with clang-cl, without AVX2, in build\release-windows\ (the
# long build: every generated unit; ccache makes a second one quick), then
# assembles release\windows\Sparta\ and packs it:
#
#   Sparta.exe and its DLLs (SDL3, FFmpeg, the Visual C++ runtime)
#   launcher\    the launcher's art, from SPARTA_LAUNCHER_ART, by default
#                ..\work\data\launcher beside the checkout (not in the repository)
#   licenses\    the licenses of everything shipped, and THIRD_PARTY_NOTICES.md
#   README.txt   packaging\windows\README.txt
#
# The result is release\windows\sparta-<version>-windows-x64.zip, SHA256SUMS,
# and the source of the exact FFmpeg the zip ships (its LGPL licence asks for
# it to be offered beside it). -Sdl3 names the unpacked SDL3-devel-*-VC
# package, by default the newest ..\work\deps\SDL3-*, else the pinned one,
# downloaded into build\deps.
param(
    [string]$Sdl3 = "",
    [int]$Jobs = 6
)
$ErrorActionPreference = 'Stop'
function Fail([string]$message) { [Console]::Error.WriteLine("error: $message"); exit 1 }
# Shows each line and appends it to the log in UTF-8 (Tee-Object writes UTF-16).
function Write-Log([string]$path) { process { $_; Add-Content -Path $path -Value $_ -Encoding UTF8 } }

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$buildDir = Join-Path $repo 'build\release-windows'
$logsDir = Join-Path $repo 'build\logs'
$releaseDir = Join-Path $repo 'release\windows'
$versionFile = Join-Path $repo 'VERSION'

if (-not (Test-Path 'generated\generated_registry.cpp')) { Fail 'no recompiled code in generated\; generate it first (docs/WINDOWS.md, step 3)' }
if (git status --porcelain --untracked-files=no) { Fail 'the checkout has uncommitted changes; commit them first' }

# Version, as release_macos.sh does it.
$version = (Get-Content $versionFile -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Fail "VERSION is not x.y.z: $version" }
cmd /c "git ls-remote --exit-code --tags origin refs/tags/v$version >nul 2>&1"
if ($LASTEXITCODE -eq 0) {
    $parts = $version.Split('.')
    $next = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
    [IO.File]::WriteAllText($versionFile, "$next`n")
    git commit -q -m "Version $next" -- VERSION
    if ($LASTEXITCODE -ne 0) { Fail 'cannot commit VERSION' }
    Write-Host "v$version is published; this release is $next"
    $version = $next
}
git tag -f "v$version" | Out-Null

# Visual Studio with clang-cl.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath
if (-not $vs) { Fail 'no Visual Studio with clang-cl; see docs/WINDOWS.md' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'

if (-not $Sdl3) {
    $Sdl3 = Get-ChildItem (Join-Path $repo '..\work\deps') -Directory -Filter 'SDL3-*' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'cmake\SDL3Config.cmake') } |
        Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
}
if (-not $Sdl3) {
    # None at hand: the pinned SDL3-devel VC package, downloaded once into
    # build\deps and checked against its SHA-256.
    $SdlVersion = '3.4.18'
    $SdlSha256 = '78d84602ae616cfe26b33a73b7d3b9b6b56e8a6650e53d92c9c6ca938f747acd'
    $deps = Join-Path $repo 'build\deps'
    $unpacked = Join-Path $deps "SDL3-$SdlVersion"
    if (-not (Test-Path (Join-Path $unpacked 'cmake\SDL3Config.cmake'))) {
        New-Item -ItemType Directory -Force -Path $deps | Out-Null
        $zip = Join-Path $deps "SDL3-devel-$SdlVersion-VC.zip"
        Write-Host "Downloading SDL3-devel-$SdlVersion-VC.zip"
        Invoke-WebRequest -UseBasicParsing -OutFile $zip `
            "https://github.com/libsdl-org/SDL/releases/download/release-$SdlVersion/SDL3-devel-$SdlVersion-VC.zip"
        if ((Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower() -ne $SdlSha256) { Fail "checksum mismatch for $zip" }
        Expand-Archive -Force -Path $zip -DestinationPath $deps
    }
    $Sdl3 = $unpacked
}
if (-not $Sdl3 -or -not (Test-Path (Join-Path $Sdl3 'cmake\SDL3Config.cmake'))) { Fail 'no SDL3 package; pass -Sdl3 with the unpacked SDL3-devel-*-VC.zip' }
$Sdl3 = (Resolve-Path $Sdl3).Path

# Build. The output goes to the screen and to build\logs\build.log.
New-Item -ItemType Directory -Force $logsDir | Out-Null
$log = Join-Path $logsDir 'build.log'
Set-Content -Path (Join-Path $logsDir 'build.status') -Value running
$started = Get-Date
Set-Content -Path $log -Value "started $($started.ToString('yyyy-MM-dd HH:mm:ss')) (release $version, Windows)" -Encoding UTF8
Get-Content $log
$configure = "cmake -S . -B `"$buildDir`" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl " +
    "-DCMAKE_PREFIX_PATH=`"$Sdl3`" -DPORTABLEKIT_RELEASE=ON -DPSPRECOMP_NATIVE_AVX2=OFF"
$build = "cmake --build `"$buildDir`" --target SpartaNative -j $Jobs"
cmd /c "`"$vcvars`" >nul && $configure && $build 2>&1" | Write-Log $log
$code = $LASTEXITCODE
"finished $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) exit=$code ($([int]((Get-Date) - $started).TotalMinutes) min)" | Write-Log $log
Set-Content -Path (Join-Path $logsDir 'build.status') -Value $code
if ($code -ne 0) { Fail "the build failed; see $log" }

# Assemble release\windows\Sparta.
$bin = Join-Path $buildDir 'bin'
$stage = Join-Path $releaseDir 'Sparta'
if (Test-Path $releaseDir) { Remove-Item -Recurse -Force $releaseDir }
New-Item -ItemType Directory -Force $stage, "$stage\licenses" | Out-Null
Copy-Item "$bin\SpartaNative.exe" "$stage\Sparta.exe"
Copy-Item "$bin\*.dll" $stage
$crt = Get-ChildItem (Join-Path $vs 'VC\Redist\MSVC') -Directory | Where-Object { $_.Name -match '^\d' } |
    Sort-Object { [version]$_.Name } | Select-Object -Last 1
$crt = Join-Path $crt.FullName 'x64\Microsoft.VC143.CRT'
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') { Copy-Item (Join-Path $crt $dll) $stage }

$launcherArt = if ($env:SPARTA_LAUNCHER_ART) { $env:SPARTA_LAUNCHER_ART } else { Join-Path $repo '..\work\data\launcher' }
$art = @('background.jpg', 'logo.jpg') | Where-Object { Test-Path (Join-Path $launcherArt $_) }
if ($art) {
    New-Item -ItemType Directory -Force "$stage\launcher" | Out-Null
    foreach ($file in $art) { Copy-Item (Join-Path $launcherArt $file) "$stage\launcher\" }
} else {
    Write-Host "note: no launcher art in $launcherArt; the launcher shows the disc image's"
}

$kit = Join-Path $repo 'portablekit'
$licenses = "$stage\licenses"
Copy-Item "$repo\LICENSE" "$licenses\Sparta-LICENSE.txt"
Copy-Item "$kit\LICENSE" "$licenses\PortableKit-LICENSE.txt"
Copy-Item "$repo\packaging\THIRD_PARTY_NOTICES.md" $licenses
Copy-Item "$Sdl3\LICENSE.txt" "$licenses\SDL3-LICENSE.txt"
Copy-Item "$bin\FFmpeg-LICENSE.txt", "$bin\FFmpeg-SOURCE.txt" $licenses
Copy-Item "$kit\third_party\imgui\LICENSE.txt" "$licenses\DearImGui-LICENSE.txt"
Copy-Item "$kit\third_party\tiny_aes\UNLICENSE" "$licenses\tiny-AES-c-UNLICENSE.txt"
Copy-Item "$kit\third_party\xxhash\LICENSE" "$licenses\xxHash-LICENSE.txt"
Copy-Item "$repo\packaging\windows\README.txt" $stage

# Never ship the game's own files (packaging\release.env: RELEASE_GAME_NAMES).
$gameFiles = Get-ChildItem -Recurse -File $stage | Where-Object { $_.Name -like 'uces01401*' -or $_.Name -like 'eboot.*' -or $_.Name -eq 'boot.bin' -or $_.Name -like '*.iso' }
if ($gameFiles) { Fail "game data in the release: $($gameFiles.FullName -join ', ')" }

# Check that the packed program starts and draws: a few seconds of the game
# installed on this machine, if there is one.
if (Test-Path "$env:APPDATA\Sparta\UCES01401\EBOOT.ELF") {
    $env:SPARTA_NO_LAUNCHER = '1'
    $env:SPARTA_INPUT_SCRIPT = '300:quit'
    $smoke = Join-Path $logsDir 'release-smoke.log'
    cmd /c "`"$stage\Sparta.exe`" > `"$smoke`" 2>&1"
    Remove-Item Env:SPARTA_NO_LAUNCHER, Env:SPARTA_INPUT_SCRIPT
    $text = Get-Content $smoke -Raw
    if ($text -notmatch 'Renderer: Vulkan' -or $text -notmatch 'Runtime stopped') { Fail "the packed program did not run; see $smoke" }
    if ($text -match '\[interpreter\]') { Fail "the packed program interpreted code; see $smoke" }
    Write-Host 'smoke test: the packed program ran the game for 300 frames'
} else {
    Write-Host 'note: no game installed here; the packed program was not started'
}

# Pack, checksum, and fetch the FFmpeg source.
$zipName = "sparta-$version-windows-x64.zip"
# Windows' own tar writes the zip with forward slashes, which every unzip reads.
tar.exe -a -c -f (Join-Path $releaseDir $zipName) -C $releaseDir Sparta
if ($LASTEXITCODE -ne 0) { Fail 'cannot pack the zip' }
$ffmpegBuild = Select-String -Path "$bin\FFmpeg-SOURCE.txt" -Pattern '/((ffmpeg-n[^/]*?-g([0-9a-f]+))-win64[^/]*)\.zip' | Select-Object -First 1
if (-not $ffmpegBuild) { Fail 'cannot read the FFmpeg build from FFmpeg-SOURCE.txt' }
$ffmpegSource = "$($ffmpegBuild.Matches[0].Groups[2].Value)-source.tar.gz"
$ffmpegCommit = $ffmpegBuild.Matches[0].Groups[3].Value
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing "https://github.com/FFmpeg/FFmpeg/archive/$ffmpegCommit.tar.gz" -OutFile (Join-Path $releaseDir $ffmpegSource)
$sums = foreach ($file in $zipName, $ffmpegSource) {
    "$((Get-FileHash -Algorithm SHA256 (Join-Path $releaseDir $file)).Hash.ToLower())  $file"
}
[IO.File]::WriteAllText((Join-Path $releaseDir 'SHA256SUMS'), (($sums -join "`n") + "`n"))

Write-Host ''
Write-Host "Sparta $version`: $releaseDir"
Get-ChildItem -File $releaseDir | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host ''
Write-Host 'Publish it with scripts\publish_release_windows.ps1'
