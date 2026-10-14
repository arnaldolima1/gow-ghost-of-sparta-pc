#!/usr/bin/env bash
# Build an arm64 Android APK of the port, with PortableKit's Android packaging.
#
#   scripts/build_android.sh
#
# Needs the recompiled code in generated/ (scripts/generate.sh), ANDROID_HOME
# (default ~/Library/Android/sdk) with an NDK, build-tools and a platform, a
# JDK, CMake, Ninja, curl and glslangValidator. Works in build/android/ and
# writes build/android/dist/Sparta-android-arm64.apk. Logs to
# build/logs/build.log; scripts/build_status.sh reads it.
#
# No game data enters the APK: the player picks their disc image on the device.
# The launcher's art (background.jpg, logo.jpg) is packed when
# SPARTA_LAUNCHER_ART (default ../work/data/launcher) has it, as for macOS.
#
# Optional: ANDROID_NDK, JOBS (default 4; each recompiled unit takes over a
# gigabyte), DEBUGGABLE=1 (lets `adb shell run-as` reach the app's files),
# KEYSTORE, KEYSTORE_PASS, KEY_ALIAS (a key of your own, so later builds
# install over earlier ones; without it a test key in build/android/ is used).
set -uo pipefail
source "$(dirname "$0")/common.sh"
fail() { echo "error: $*" >&2; exit 1; }
cd "$repo_dir"
[[ -f generated/generated_registry.cpp ]] || fail "no recompiled code in generated/; run scripts/generate.sh first"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
[[ -d "$ANDROID_HOME" ]] || fail "no Android SDK in $ANDROID_HOME; set ANDROID_HOME"
ndk="${ANDROID_NDK:-$(ls -d "$ANDROID_HOME"/ndk/* 2> /dev/null | sort -V | tail -1)}"
toolchain="$ndk/build/cmake/android.toolchain.cmake"
[[ -f "$toolchain" ]] || fail "no Android NDK in $ANDROID_HOME/ndk; set ANDROID_NDK"
export ANDROID_NDK="$ndk"
if ! command -v javac > /dev/null && [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
fi
jobs="${JOBS:-4}"
work="$build_root/android"
mkdir -p "$work/dist" "$logs_dir"

echo running > "$logs_dir/build.status"
{
    set -e
    echo "started $(date '+%Y-%m-%d %H:%M:%S') (android build)"
    source "$repo_dir/portablekit/packaging/sources.sh"
    sources="$work/sources"
    mkdir -p "$sources"
    sha256() { shasum -a 256 "$1" | cut -d ' ' -f1; }
    fetch() {
        local name="$1" url="$2" hash="$3"
        if [[ -f "$sources/$name" && "$(sha256 "$sources/$name")" == "$hash" ]]; then return; fi
        curl -fL --retry 3 -o "$sources/$name.part" "$url"
        [[ "$(sha256 "$sources/$name.part")" == "$hash" ]] || { echo "error: checksum mismatch for $name" >&2; exit 1; }
        mv "$sources/$name.part" "$sources/$name"
    }
    fetch "SDL3-$SDL3_VERSION.tar.gz" "$SDL3_URL" "$SDL3_SHA256"
    fetch NotoSansCJKjp-Regular.otf "$NOTO_CJK_URL" "$NOTO_CJK_SHA256"
    fetch NotoSansCJK-LICENSE.txt "$NOTO_CJK_LICENSE_URL" "$NOTO_CJK_LICENSE_SHA256"

    # SDL, built for Android once.
    sdl_source="$sources/SDL3-$SDL3_VERSION"
    [[ -d "$sdl_source" ]] || tar -xzf "$sources/SDL3-$SDL3_VERSION.tar.gz" -C "$sources"
    if [[ ! -f "$work/sdl/lib/libSDL3.so" ]]; then
        cmake -S "$sdl_source" -B "$work/sdl-build" -G Ninja \
            -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DANDROID_ABI=arm64-v8a \
            -DANDROID_PLATFORM=android-29 -DCMAKE_BUILD_TYPE=Release \
            -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF \
            -DSDL_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX="$work/sdl"
        cmake --build "$work/sdl-build" -j "$jobs"
        cmake --install "$work/sdl-build"
    fi

    # The game: libmain.so with the recompiled code.
    cmake -S "$repo_dir" -B "$work/native" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DANDROID_ABI=arm64-v8a \
        -DANDROID_PLATFORM=android-29 -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release \
        -DSDL3_DIR="$work/sdl/lib/cmake/SDL3" -DCMAKE_FIND_ROOT_PATH="$work/sdl" \
        -DPORTABLEKIT_ANDROID_APP=ON -DPORTABLEKIT_RELEASE=ON \
        -DPORTABLEKIT_FFMPEG=bundled -DPSPRECOMP_BUILD_TESTS=OFF \
        -DPSPRECOMP_GENERATED_JOBS="$jobs"
    cmake --build "$work/native" --target SpartaNative -j "$jobs"

    # The launcher's art, when it is here.
    launcher_art="${SPARTA_LAUNCHER_ART:-$repo_dir/../work/data/launcher}"
    rm -rf "$work/assets"
    mkdir -p "$work/assets/launcher"
    for art in background.jpg logo.jpg; do
        if [[ -f "$launcher_art/$art" ]]; then cp "$launcher_art/$art" "$work/assets/launcher/"; fi
    done
    [[ -n "$(ls "$work/assets/launcher")" ]] || echo "note: no launcher art in $launcher_art; the app shows the disc image's"

    apk="$work/dist/Sparta-android-arm64.apk"
    APP_ID=io.sparta GAME_REPO="$repo_dir" \
    GAME_RES="$repo_dir/packaging/android/res" NOTICES="$repo_dir/packaging/THIRD_PARTY_NOTICES.md" \
    FONT_DIR="$sources" EXTRA_ASSETS="$work/assets" \
        bash "$repo_dir/portablekit/packaging/android/build_apk.sh" "$work/native" "$sdl_source" \
        "$work/sdl/lib/libSDL3.so" "$apk"
    build_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
    "$build_tools/apksigner" verify "$apk"
    "$build_tools/zipalign" -c -P 16 4 "$apk"
    (cd "$work/dist" && shasum -a 256 "$(basename "$apk")" > SHA256SUMS)
    echo "APK: $apk"
    echo "Install and start it with scripts/run_android.sh"
} 2>&1 | tee "$logs_dir/build.log"
code=${PIPESTATUS[0]}
echo "finished $(date '+%Y-%m-%d %H:%M:%S') exit=$code" >> "$logs_dir/build.log"
echo "$code" > "$logs_dir/build.status"
exit "$code"
