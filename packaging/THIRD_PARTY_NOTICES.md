# Third-party notices

Sparta is distributed under the MIT License (`Sparta-LICENSE.txt`), and so is PortableKit, the framework it is built on (`PortableKit-LICENSE.txt`). Its released builds also contain the third-party software listed here, each under its own license. The license texts are in the same directory as this file: `licenses/` in the tarball, `/app/share/licenses/io.sparta.Sparta/` (also `/app/lib/sparta/licenses/`) in the Flatpak, `Sparta.app/Contents/Resources/licenses/` on macOS, `licenses\` in the Windows zip, and `assets/licenses/` in the Android APK.

Sparta does not include any game assets or original game files: no disc image, no copy of the game's executable or data, and no textures, models, audio or video from the game. You must provide the files from your own legally obtained copy of the game.

## Compiled into the program

In Android APKs the game's MIT license is named `Game-LICENSE.txt`.

### Dear ImGui 1.92.9b

Sparta's menu and setup screens. Copyright (c) 2014-2026 Omar Cornut. MIT License: `DearImGui-LICENSE.txt`. <https://github.com/ocornut/imgui>

### tiny-AES-c

AES for preparing the executable from the disc image and for save data. Commit `23856752fbd139da0b8ca6e471a13d5bcc99a08d`, released into the public domain under the Unlicense: `tiny-AES-c-UNLICENSE.txt`. <https://github.com/kokke/tiny-AES-c>

### stb_truetype 1.26

Rasterizes the game's text. Copyright (c) 2017 Sean Barrett. Used under the public-domain dedication it offers as an alternative to the MIT License:

> This is free and unencumbered software released into the public domain. Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software, either in source code form or as a compiled binary, for any purpose, commercial or non-commercial, and by any means.

<https://github.com/nothings/stb>

### stb_image 2.30 and stb_image_write 1.16

Read and write the PNG images of HD texture packs. Copyright (c) 2017 Sean Barrett. Used under the same public-domain dedication as stb_truetype above. <https://github.com/nothings/stb>

### dr_mp3 0.7.4

Plays a music file the player puts in the launcher's folder (none is shipped). By David Reid, based on minimp3. Released into the public domain under the Unlicense, or under the MIT No Attribution license, at the user's choice; the license texts are at the end of `dr_mp3.h`. Commit `dfe8377631000664666519fdb83da193fd8037f4`. <https://github.com/mackron/dr_libs>

### xxHash 0.8.3

Hashes textures for HD texture packs. Copyright (c) 2012-2021 Yann Collet. BSD 2-Clause License: `xxHash-LICENSE.txt`. <https://github.com/Cyan4973/xxHash>

## Shipped as separate libraries

These are dynamically linked shared libraries in `lib/` next to the executable (`/app/lib/sparta/lib/` in the Flatpak, `Sparta.app/Contents/Frameworks/` on macOS). They are unmodified builds of the upstream releases below. You may replace them with your own builds of the same or a compatible version.

### SDL3 3.4.16

Window, input and audio output. Copyright (C) 1997-2026 Sam Lantinga. zlib License: `SDL3-LICENSE.txt`.

- Library: `libSDL3.so.0` (`libSDL3.0.dylib` on macOS)
- Source: <https://github.com/libsdl-org/SDL/releases/download/release-3.4.16/SDL3-3.4.16.tar.gz> (SHA-256 `7322236cd12090c3eb40b9728be4d49c76f66ad17d04369584d4ecad5cf77c68`)

### FFmpeg 7.1.5

Decodes the game's ATRAC3 and ATRAC3plus audio and its H.264 movies. FFmpeg is licensed under the GNU Lesser General Public License, version 2.1 or later: `FFmpeg-COPYING.LGPLv2.1.txt`, with the source and configuration also noted in `FFmpeg-SOURCE.txt`. This build contains no GPL or non-free parts. <https://ffmpeg.org/>

- Libraries: `libavcodec.so.61` and `libavutil.so.59` (`libavcodec.61.dylib` and `libavutil.59.dylib` on macOS)
- Source: <https://ffmpeg.org/releases/ffmpeg-7.1.5.tar.xz> (SHA-256 `de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f`), not modified
- Configured with:

  ```text
  ./configure --prefix=<prefix> --enable-shared --disable-static --disable-programs --disable-doc --disable-avdevice --disable-avformat --disable-avfilter --disable-swscale --disable-swresample --disable-network --disable-autodetect --disable-everything --enable-decoder=atrac3,atrac3p,h264 --disable-x86asm --disable-debug
  ```

- On macOS also with `--install-name-dir=@rpath`, which only sets where the libraries expect each other.
- On Android the libraries are `libavcodec.so` and `libavutil.so`, built with the NDK for arm64 and Android 10, with 16 KiB page alignment. SDL is `libSDL3.so`; Vulkan comes from the device.
- Built by the build itself, `cmake/FFmpeg.cmake` in PortableKit (<https://github.com/TeamGDB/PortableKit>), which pins the version, checksum and configuration above.

**Source offer.** The exact FFmpeg source archive above is published on the same release page as every Sparta build that contains it. For at least three years after we distribute a build, we will also provide that source to anyone who asks through the project's issue tracker, <https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/issues>, at no more than the cost of providing it.

### Vulkan loader 1.4.357 (macOS only)

Finds and loads the Vulkan driver, MoltenVK. Copyright (c) 2015-2026 The Khronos Group Inc., Valve Corporation and LunarG, Inc. Apache License 2.0: `Vulkan-Loader-LICENSE.txt`. Built for macOS 13 and Apple Silicon, with its Vulkan-Headers of the same tag.

- Library: `libvulkan.1.dylib`
- Source: <https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/vulkan-sdk-1.4.357.0.tar.gz> (SHA-256 `54f2537df22313768da0317dda2abdaaab7711b4081c48c869a79db343d0ae70`)

### MoltenVK 1.4.2 (macOS only)

Vulkan on Apple's Metal. Copyright (c) 2015-2026 The Brenwill Workshop Ltd. Apache License 2.0: `MoltenVK-LICENSE.txt`. The Khronos release build; only its Apple Silicon (arm64) part is kept.

- Library: `libMoltenVK.dylib`, with its driver manifest in `Sparta.app/Contents/Resources/vulkan/icd.d/`
- Release: <https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.2/MoltenVK-macos.tar> (SHA-256 `f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e`); source: <https://github.com/KhronosGroup/MoltenVK/tree/v1.4.2>

## Windows

The Windows zip ships these next to `Sparta.exe`, instead of the SDL3 and FFmpeg builds described above. Vulkan comes from the graphics driver.

### SDL3 3.4.18

Copyright (C) 1997-2026 Sam Lantinga. zlib License: `SDL3-LICENSE.txt`. The unmodified `SDL3.dll` of the official Visual Studio package, <https://github.com/libsdl-org/SDL/releases/download/release-3.4.18/SDL3-devel-3.4.18-VC.zip> (SHA-256 `78d84602ae616cfe26b33a73b7d3b9b6b56e8a6650e53d92c9c6ca938f747acd`).

### FFmpeg 7.1.5 (BtbN build)

`avcodec-61.dll`, `avutil-59.dll` and `swresample-5.dll`: an unmodified prebuilt LGPL shared build of FFmpeg from BtbN/FFmpeg-Builds, licensed under the GNU Lesser General Public License, version 3 or later: `FFmpeg-LICENSE.txt`, with the build noted in `FFmpeg-SOURCE.txt`. The libraries are dynamically linked; you may replace them with your own builds of a compatible version.

- Build: <https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-06-30-13-34/ffmpeg-n7.1.5-1-g7d0e842004-win64-lgpl-shared-7.1.zip> (SHA-256 `03a8003e245c08df4277d7b0adc50b93a97ddd4a3aaafea21943c4384df59895`), pinned in PortableKit's `cmake/FFmpeg.cmake`
- Source: FFmpeg commit `7d0e842004` on the `release/7.1` branch, published as `ffmpeg-n7.1.5-1-g7d0e842004-source.tar.gz` beside every Windows build; build scripts: <https://github.com/BtbN/FFmpeg-Builds>. The source offer above applies to it too.

### Microsoft Visual C++ runtime

`msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll`, redistributed unmodified from Visual Studio 2022 under its license terms for redistributable code, so that Sparta runs without installing the Visual C++ Redistributable.

## Font

### Noto Sans CJK JP (Noto CJK Sans 2.004)

A fallback for text on systems without a CJK font: `fonts/NotoSansCJKjp-Regular.otf` (`Sparta.app/Contents/Resources/fonts/` on macOS). Copyright 2014-2021 Adobe (<http://www.adobe.com/>), with Reserved Font Name 'Source'. SIL Open Font License, version 1.1: `NotoSansCJK-OFL.txt`. <https://github.com/notofonts/noto-cjk>
