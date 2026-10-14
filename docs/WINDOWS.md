# Building on Windows

No Windows build of Sparta has been made yet. PortableKit builds on Windows and its tests pass there in continuous integration (MSVC 19.44), and another port on PortableKit (Yakumo) has been run on Windows; this port has only been built and run on macOS and Android. This page says how to build it so that it runs **fast**, and what to check on the first run. Written for whoever does it, a person or a coding agent; update it with what actually happened.

## The one choice that matters for speed: clang-cl, not cl.exe

Build with **clang-cl** (LLVM's MSVC-compatible driver, part of Visual Studio) and **Ninja**, not with Microsoft's own compiler (`cl.exe`) or the Visual Studio generator:

- The recompiled game code (`generated/`, 254 files of up to 9000 lines, each one huge C++ function) is the part whose speed matters. Every measurement and every optimization in [PERFORMANCE.md](PERFORMANCE.md) was made with clang (Apple's on the Mac, the NDK's on Android). With clang-cl the Windows build gets the same optimizer.
- MSVC has a history with this code: PortableKit removed an earlier register cache because MSVC's optimizer never finished on the large units it produced and each compile passed 2 GB (comment in `generate_auto()`, `portablekit/tools/codegen_main.cpp`). PortableKit compiles generated units under MSVC with `/Ob0` (no inlining), which is safe but slow.

**One change is needed in PortableKit for clang-cl.** CMake sets `MSVC` for clang-cl too, so `portablekit/cmake/PortableKit.cmake` gives the generated units `/O2 /Ob0 /bigobj` (the `if(MSVC)` near "generated AOT units", and again for overlay libraries further down). Under clang-cl, `/Ob0` turns off inlining of everything not marked always-inline. Use `/O2 /bigobj` without `/Ob0` when the compiler is clang-cl (`CMAKE_CXX_COMPILER_ID STREQUAL "Clang"`), and measure both if in doubt. Keep `/Ob0` for `cl.exe`.

## What to install

- **Visual Studio 2022** (Community is fine) with the *Desktop development with C++* workload and, under individual components, **C++ Clang Compiler for Windows** (clang-cl) and **C++ CMake tools for Windows** (CMake and Ninja).
- **Python 3** (the build runs Python scripts; `py` or `python` on the PATH).
- **Git for Windows** (for the submodule; Git Bash is handy but the scripts in `scripts/` are written for macOS and Linux, see below).
- **Vulkan SDK** from LunarG: the loader, headers and `glslangValidator`, which the renderer's shaders need. The installer sets `VULKAN_SDK` and puts `glslangValidator` on the PATH.
- **SDL3** for Visual Studio: the `SDL3-devel-3.x.x-VC.zip` of a 3.2 or later release from the SDL GitHub releases, unpacked somewhere such as `C:\libs\SDL3`. It contains the CMake package CMake looks for.
- **FFmpeg**: nothing to do. On Windows PortableKit's default (`PORTABLEKIT_FFMPEG=bundled`) downloads a pinned prebuilt LGPL build and puts its DLLs next to the executable. Do not pass `-DPORTABLEKIT_FFMPEG=system` as `scripts/build.sh` does on the Mac.

Without SDL3, Vulkan or glslang, CMake does not fail: it prints `renderer disabled (SDL3, Vulkan, glslang or Python 3 not found)` and builds a program that cannot draw. Read the configure output for that line.

## Steps

From an **x64 Native Tools Command Prompt for VS 2022** (so the compilers and Ninja are on the PATH), in the checkout (`git clone --recursive`, or `git submodule update --init` after cloning):

**1. Build without the game code**, which is quick, so the program can install the game:

```bat
cmake -S . -B build\win -G Ninja -DCMAKE_BUILD_TYPE=Release ^
      -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
      -DCMAKE_PREFIX_PATH=C:\libs\SDL3
cmake --build build\win
```

With `generated\` empty, PortableKit links an empty registry and says so; that build runs nothing of the game but can install it.

**2. Install the game from your disc image.** This copies the image and writes the decrypted executable, `EBOOT.ELF`, into the user data directory, `%APPDATA%\Sparta\UCES01401\` on Windows:

```bat
build\win\bin\SpartaNative.exe --install D:\path\to\UCES01401.iso
```

**3. Generate the game code** with the same options `scripts/generate.sh` uses (about 3 minutes):

```bat
build\win\portablekit\psp_recomp.exe "%APPDATA%\Sparta\UCES01401\EBOOT.ELF" --auto generated --sparse-entries --return-hints
```

**4. Build again**, now with the 254 generated units. This is the long build (it was about 15 minutes on an Apple M4 with 10 cores; each unit takes over a gigabyte to compile, so with 16 GB of memory keep the jobs down, e.g. `cmake --build build\win -j 6`):

```bat
cmake -S . -B build\win
cmake --build build\win
```

**5. Play:** `build\win\bin\SpartaNative.exe`. Settings, saves and the shader cache live in `%APPDATA%\Sparta\UCES01401\`.

The `scripts/*.sh` scripts (generate, build, run, the Android ones) assume macOS or Linux paths and options. Run the commands above instead, or, if Windows becomes a regular target, add `.bat` or PowerShell equivalents (or teach `generate.sh` the `%APPDATA%` path) and list them here.

## Check the first run

1. **The renderer is on**: the log says `Renderer: Vulkan on <your GPU>`.
2. **No unit failed to compile.** The NDK's clang 18 crashed on `generated/generated_unit_0069.cpp` (see [PERFORMANCE.md](PERFORMANCE.md), *Android compiler crash*); `CMakeLists.txt` works around it on Android only. If clang-cl crashes on a unit too, extend that block to Windows (`if(ANDROID OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")`, with the same option, which clang-cl takes as `/clang:-mllvm /clang:-regalloc=basic` or `-mllvm -regalloc=basic`).
3. **Nothing runs interpreted**: the log has no `[interpreter]` line. On the Mac there was none.
4. **Speed**: run the same stretch as on the Mac with the frame counter on, and compare `guest` (game code) and `render` (display lists) in milliseconds a frame:

   ```bat
   set SPARTA_NO_LAUNCHER=1
   set SPARTA_PERF=log
   set SPARTA_FRAME_SKIP=0
   set "SPARTA_INPUT_SCRIPT=900:pad a;1200:pad a;1500:pad a;1800:pad a;2100:pad a;2600:pad start;4400:axis leftx 0;4600:quit"
   build\win\bin\SpartaNative.exe > run.log 2>&1
   ```

   On an Apple M4, `guest` in the boat fight (between `frame 2600` and `frame 4400` in the log) was 1.4–2.9 ms a frame. A recent desktop x86-64 CPU should be in that range. Several times more points at the compiler settings above (`/Ob0`, or `cl.exe`) before anything else.

## Options worth knowing

- `-DPSPRECOMP_GENERATED_OPT_LEVEL=2` is the default for the generated units, and what every measurement used.
- `-DPSPRECOMP_NATIVE_AVX2=ON` builds with AVX2 (`/arch:AVX2`); faster on any CPU from about 2015 on, but the result will not start on older ones. Leave it off for a build meant for others.
- ccache works with clang-cl and Ninja and saves hours on rebuilds; PortableKit uses it automatically when it is on the PATH. sccache is the more common choice on Windows and works the same way.
- PortableKit's build lock (against two builds in one directory) is a no-op on Windows: do not run two builds of `build\win` at once.

## Releasing for Windows

There is no `scripts/release_windows.sh` yet. A release would be: the Release build above with `PSPRECOMP_NATIVE_AVX2` off, `SpartaNative.exe` with the DLLs next to it (SDL3, the FFmpeg ones), the launcher art in the layout `release_macos.sh` uses, `THIRD_PARTY_NOTICES.md`, and the FFmpeg source archive beside the release (LGPL), zipped. Model it on `scripts/release_macos.sh` and `portablekit/docs/RELEASING.md`, and add the zip to `scripts/publish_release.sh`.
