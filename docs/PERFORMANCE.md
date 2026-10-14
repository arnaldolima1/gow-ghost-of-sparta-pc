# Performance work

Where the frame time goes, what has been done about it, what was tried and dropped, and what is next. Written to be picked up by whoever continues: a person or a coding agent. Keep the [status](#status) table current.

The target device is a **Moto g84 5G** (Snapdragon 695: two Cortex-A78 at 2.2 GHz and six Cortex-A55; Adreno 619; Android 15), the slowest machine the port is expected to run well on. On an Apple M4 the game has run at full speed with frames to spare all along; the Mac is where correctness is checked, the phone is where speed is measured.

The framework changes live in PortableKit (`portablekit/`, the fork's `sparta` branch, offered upstream in [TeamGDB/PortableKit#44](https://github.com/TeamGDB/PortableKit/pull/44)). This repository only takes them.

## Status

| # | Work | State | Effect measured on the phone |
| --- | --- | --- | --- |
| — | Draw batching in the GE (PortableKit `9a3d053`) | **Done, released in 0.1.4** | Boat fight at ×2, frame skip off: 90–91% → **~100%** speed |
| — | Render thread (`render-thread` branch) | **Parked** — correct but no gain | 90% → 76–92% |
| 1 | Recompiler: dispatcher entries only where needed (PortableKit `dispatch-entries` branch) | **Runs on the Mac (title → movie → boat fight, nothing interpreted); phone not measured yet** | Estimated 1.5–2 ms a frame of game code |
| 2 | Fewer render target copies on the GPU | To do | Needed for ×3 on the phone |
| 3 | Cache of static vertices on the GPU | To do | Estimated ~1 ms a frame, and memory bandwidth |
| 4 | Recompiler: guest registers in locals | To do, large | The biggest possible gain in game code |
| 5 | Small per-draw costs in the renderer | To do | A few tenths of a millisecond each |

## How to measure

Always measure the same stretch of play, and measure before changing anything.

**On the phone** (`scripts/bench_android.sh`): plays the boat's first fight through scripted input and prints one `[perf]` line a second with averages.

```bash
# A debuggable build, signed with the release key so it installs over the player's app.
set -a; source ../work/keys/release.env; set +a
DEBUGGABLE=1 scripts/build_android.sh
adb install -r build/android/dist/Sparta-android-arm64.apk
adb shell setprop security.perf_harden 0              # once per boot, for simpleperf

scripts/bench_android.sh base SPARTA_HALF_RATE=0                   # numbers only
scripts/bench_android.sh base profile SPARTA_HALF_RATE=0           # plus 15 s of simpleperf
tools/perf/profile_report.py cycles   build/bench/base.data
tools/perf/profile_report.py children build/bench/base.data "VulkanRenderer::submit("
tools/perf/profile_report.py lines    build/bench/base.data "VulkanRenderer::submit("
```

- The app id is `io.sparta`. The game must already be set up in the debuggable app; a release build (not debuggable) cannot be driven this way.
- The script sets `SPARTA_FRAME_SKIP=0` so slowness shows as speed below 100% instead of skipped frames. It never edits `settings.ini`: the phone's owner keeps their own settings (at the time of writing ×2 and *Limit to 30 fps* on), so pass what is measured as variables (`SPARTA_HALF_RATE=0`, `SPARTA_INTERNAL_SCALE=2` or `3`).
- On the `[perf]` line, `guest` is the game thread outside display lists (recompiled code, HLE, kernel), `render` the game thread inside display lists (GE commands, vertex decoding, the renderer), `wait` time the game thread waits (for the GPU, or ahead of real time), `gpu` GPU time a frame.
- **Runs differ.** The guest clock starts from the wall clock, so the fight is not the same twice. Compare averages of several runs, and compare CPU work in **absolute cycles** (`profile_report.py cycles`), never in percentages, which move whenever anything else does.
- Long series of runs heat the phone. `adb shell dumpsys thermalservice` shows the thermal status; 0 is not throttled.

**On the Mac**, for correctness: `scripts/run.sh` with `SPARTA_NO_LAUNCHER=1`, `SPARTA_INPUT_SCRIPT` (key presses at frame numbers: Space through the menus at 620, 920, 1220, 1520, Return at 1900 skips the intro, the fight starts around 3000), `SPARTA_SCREENSHOT_DIR` and `shot NAME` steps, and `SPARTA_FRAME_RATE=30` to turn frame interpolation off. Compare captures of a change against the same run with the change switched off; every new behaviour has a variable that turns it off.

## Where the time goes

The boat's heaviest fight, ×2, frame skip off, with draw batching (0.1.4). The game thread is the limit; it has to fit in 16.7 ms:

| Part of the game thread | ms a frame | Share |
| --- | --- | --- |
| Recompiled game code (and HLE calls from it) | ~8–9 | ~54% |
| Display lists: GE commands, vertex decoding, the renderer | ~6 | ~39% |
| Presents and the rest | ~1 | |
| **GPU**, at ×2 / ×3 | ~11 / 17–19 | separate |

So at ×2 the game now holds full speed with 1–5 ms to spare; at ×3 the GPU is the limit (87% speed measured with 0.1.4).

### The game's draws

- The game makes about **6600 GE prims a frame** of about **9 vertices each** (60–85 thousand vertices a frame). Before draw batching each prim paid the renderer's whole per-draw work: framebuffer texture lookup, alias lookup, texture lookup, pipeline lookup, render area, indices, state. Batching hands about 790 draws a frame to the renderer.
- **42–76% of the vertices** of a frame are byte-identical to the previous frame's (level geometry). The rest are skinned characters, skinned on the CPU while decoding. Measured with a temporary trace hashing each draw's decoded vertices; see item 3.
- What is left of the renderer's per-draw cost, by `profile_report.py children ... "VulkanRenderer::submit("` on 0.1.4: own code ~3.8% of the game thread (vertex conversion into the mapped buffer, uniforms), `triangle_indices` 1.5%, `texture_descriptor` 1.2%, `flush_group` 1.0%, `snapshot_guest_words` 1.0%, `framebuffer_descriptor` 0.9%, `begin_frame` 0.8%.

### The recompiled code

`psp_recomp` (`portablekit/tools/codegen_main.cpp`) cuts the executable into 16 KiB units, each one C++ function. **Every instruction word is a dispatcher entry**: the unit's `switch` has a case for each of its 4096 words, and the code is emitted as one block per entry, so every instruction is its own basic block ending in a `goto` to the next. The comment in `generate_auto()` gives the reason: static analysis cannot resolve every computed jump, and an address with no code would stop the runtime.

The effect, read off `clang -S` of a hot unit (`generated_unit_0003.cpp`) for arm64 at `-O2`:

- **~12.6 arm64 instructions and ~4.9 loads per PSP instruction**. Every PSP instruction loads its operands from `AllegrexContext` and stores the result back, because no value can stay in a register across a label every dispatch can reach.
- Keeping only one case in sixteen (an experiment, not a valid program) gave **−26% instructions and −35% loads** for the same unit.
- `__restrict` on the context changed nothing: the labels, not aliasing, are what stop the optimizer.

## Done

**Draw batching in the GE** (PortableKit `9a3d053`, Sparta 0.1.4). `GeState` keeps prims drawn in a row with nothing changed between them (a `state_serial_` that moves with every command except the vertex and index pointers, `BASE`, `OFFSET_ADDR` and the bone matrices, which decoding applies) and sends them as one draw: triangles, strips and fans as one indexed triangle list in the order the renderer expands them in, unindexed sprites appended. The batch is flushed before a block transfer, a patch, at `END`, at the stall address and at the end of a list. Raw draws (`SPARTA_GPU_DECODE=1`) are not batched. `SPARTA_NO_DRAW_BATCH=1` turns it off. Captures on the Mac (title, movie, boat, fight, the Power Up screen, an engine cutscene) match.

Earlier, still relevant: frame skipping (`video.frame_skip`), *Limit to 30 fps* (`video.half_rate`), render areas, partial target copies, depthless passes, no per-frame write-back for this game (`GameProfile::frame_writeback = false`). See the PortableKit history and PR #44.

## Tried and parked: a render thread

Branch `render-thread` in the PortableKit fork (`520f452`, `261a6c1`). Off by default (`<prefix>_RENDER_THREAD=1`). It is correct on the Mac and the phone (title, movie, menus, fight, texture packs, the write-back) but **does not make the game faster on the phone**:

- `submit()` was split in two: the half that reads guest memory (framebuffer texture lookup, the targets' guest words, aliases, a new texture's key and bytes) stays on the game thread; the rest goes to the render thread with the draw, along with presents, movie pictures and the interface's draw lists. Rare calls (settings, captures, packs, the menu) sync with the thread first. Frame interpolation keeps everything on the game thread.
- Handing a draw over means copying its decoded vertices, about 2.5 MB a frame. On this phone that copy cost the game thread about as much as the work it took off it (absolute cycles: decode + submit 11.7 G without the thread, 12.3–12.4 G with it). The phone is memory-bound.
- With GPU vertex decode the copy is smaller, but the GPU (16 ms at ×2) and the render thread (12 ms) become the limit: 92%, no better than without.

Bugs met on the way, kept in that branch and worth knowing:
- Android started the new thread on a slow core (an A55); it now pins itself to the fastest cores (`RENDER_THREAD_ANY_CORE` leaves it to the scheduler).
- The `perf` counters took a mutex at every draw from both threads; they are now atomics there.
- Swapping vertex buffers with `GeState` instead of copying doubled decode time, because the buffers came back too small and grew again.
- The queue had no bound and ran out of memory (`std::bad_alloc`); the game thread now waits at its flip while more than one frame is queued.

Worth another look only once per-draw costs and vertex volume are much smaller, or on a device with more memory bandwidth.

## Next

### 1. Dispatcher entries only where they are needed (written, not yet run in the game)

**Idea.** Separate the two roles every word has now:
- **Labels**, where a block starts: every target of a branch or jump inside the unit, and every instruction after a branch's delay slot. These stay `goto` targets, as now.
- **Dispatcher entries**, the `switch` cases a dispatch can land on: function entries, the continuation after every call (`jal`, `jalr`, `bal`, and the import stubs, after which a thread switch may resume), the targets of `j`/`jal` from other units (which use `direct_entry_ids`), the targets of jump tables the analysis resolves, and code addresses referenced from data (function pointers, thread entry points, vtables).

The analysis already computes most of this: `FunctionAnalysis::entry_labels` ("function entry and basic-block/return continuations") and `ProgramAnalysis::covered_entry_labels` (`portablekit/include/psprecomp/program_analysis.hpp`); `generate_auto()` ignores them and uses every word.

**Safety net.** A dispatch to an address that is not an entry leaves the unit through the `switch`'s `default` with `ctx.pc` set; the outer dispatcher finds no function there and runs the **interpreter** from it (`Runtime::run_interpreter_fallback`), which keeps statistics. So a missed entry costs speed, not correctness. A finished port must also run with `PSPRECOMP_NO_INTERPRETER=1` wherever it can.

**What is done** (PortableKit branch `dispatch-entries`, Sparta's `scripts/generate.sh`):
- `psp_recomp --auto … --sparse-entries` (`generate_auto()` in `portablekit/tools/codegen_main.cpp`). Blocks: the analysis' block starts, the targets and fallthroughs of every branch and `j`, and the entries. Entries: every analysis seed (function entries, data and relocated code pointers), the word after every `jal`/`jalr`/`bltzal`-family branch, every `jal` target, branch and `j` targets in another unit, the first word of each unit (straight-line code runs on into it), and every word the analysis never reached (as before). Delay slots are neither.
- A unit entered at an address that has no entry, with no local jump yet, calls the interpreter (new `CorpusHostApi::interpret`, ABI version 2) instead of stopping with "invalid internal function entry". The interpreter stops at the next registered address. A local `jr` to an address without an entry still leaves the unit, and the outer dispatcher comes back to it.
- `scripts/generate.sh` passes `--sparse-entries`; `SPARTA_DENSE_ENTRIES=1 scripts/generate.sh` generates the old way.
- Test `test_automatic_sparse_entries` in `portablekit/tests/test_main.cpp` (`psprecomp_tests` passes).

**Measured so far, without running the game:** 1,040,000 words → 93,774 entries (9%) and about 200,000 blocks (20%). Units 0100 and 0200, compiled with `clang++ -O2` for arm64: 409 → 267 KB and 332 → 205 KB of code (−35 to −38%).

**First run, Mac (M4, dev build, frame skip off):** title, movie and the boat fight look as before, and the log has no `[interpreter]` line: nothing ran without an entry. Guest time in the fight 1.4–2.9 ms a frame; there is no Mac baseline from the old corpus to compare with, so the number that matters is the phone's.

**Android compiler crash.** The NDK r27 clang 18 crashes (segfault in the greedy register allocator) on `generated_unit_0069.cpp` of the sparse corpus; Apple clang and every other unit are fine. `CMakeLists.txt` compiles that one unit with `-mllvm -regalloc=basic` on Android. To check all units after a regeneration, compile each with the NDK clang (3 minutes with 10 jobs); a newer NDK may not need it.

**Steps.**
1. ~~In `generate_auto()`, build the entry set from the analysis (plus data-referenced code addresses and cross-unit jump targets) and the label set from the units' control flow; emit blocks per label and `switch` cases per entry. Keep the old behaviour behind a switch to the generator, to compare.~~ Done, above.
2. Regenerate (`scripts/generate.sh`, about 3 minutes) and rebuild (`scripts/build.sh`, about 15 minutes on an M4; the Android build is longer). These are long builds: the owner runs them.
3. Check: the interpreter statistics in the log after a run through title, movie, boat and fight (how many entries, how many instructions interpreted; anything hot there is a missing entry); captures against the current build; then the phone numbers.
4. Compare `clang -S` instructions per PSP instruction for a few hot units before and after.
5. If it holds: merge `dispatch-entries` into the fork's `sparta` branch, bump the submodule, add it to PR #44 or a new PR (the option is off unless asked for, so other ports are unaffected).

**Reading the interpreter statistics.** The first fallback prints `[interpreter] no recompiled function at …` to the log; `PSPRECOMP_INTERPRETER_VERBOSE=1` prints every new address. When the run loop ends (quitting the game), stderr gets `[interpreter] instructions=… entries=… unique_addresses=…` and the 20 addresses that ran the most (nothing if nothing was interpreted). A hot address there is a missing entry: find which kind of transfer reaches it (`PSPRECOMP_INTERPRETER_WATCH`) and add that kind to the entry rules in `generate_auto()`. With `PSPRECOMP_NO_INTERPRETER=1` a missing entry stops the game with "no entry here and no interpreter", naming the address.

**Risks.** An entry the analysis misses that is hot (a jump table it cannot resolve) runs interpreted: slow, visible in the statistics. Code reached only through a computed jump into the middle of a function. Overlays, if a game loads code later (this one has none). Compile time and memory per unit may change.

### 2. Fewer render target copies (for ×3)

The perf line shows about 34–37 render target copies a frame (`copies`), most for the bloom chain and the shadow maps: a texture read from a target is copied out of it first, because a pass cannot sample its own attachment. Their cost grows with the resolution, which is why ×3 is GPU-bound. Options: sample the target directly when the draw reading it is in another pass (no copy at all), copy only once per target per frame when several draws read the same unchanged area (partly done), merge the shadow maps' extracts.

### 3. Cache of static vertices

Keep the converted vertices of draws whose source bytes are unchanged (hash of the raw vertex bytes with the vertex type and count) in a persistent GPU buffer, and draw from there instead of decoding, converting and uploading them again. Skinned draws change every frame and stay as they are. PPSSPP has such a cache. Saves decode (~2.9 G cycles in 15 s), part of the conversion and memory bandwidth, which is what this phone is short of.

### 4. Guest registers in locals

The big one for game code: emit each unit with the 32 GPRs (and the FPU registers) in local variables, stored back to `AllegrexContext` before anything that leaves the unit's code (imports, other units, the interpreter, returns) and reloaded after. With item 1 done the compiler can keep them in host registers across blocks. A rewrite of much of the code generator.

### 5. Small per-draw costs

From the profiles, each worth a few tenths of a millisecond:
- `triangle_indices` for unindexed prims depends only on the primitive and the count: cache it.
- `find_framebuffer_texture`: the targets are all in VRAM; a texture in main RAM can be rejected before looking at any target.
- `multiply(view, world)` for every draw: compute it when either matrix changes.
- `texture_descriptor`: the per-list memo is a `std::map` keyed by seven fields.

## Lessons

- **Measure, then change.** Profiles found every real cause here; the plausible guesses (a render thread) did not pay.
- **Absolute cycles, not percentages,** when comparing builds.
- On a phone, **memory traffic** is the cost to watch: copying data to hand it over can cost what moving the work saves.
- Android's scheduler may put a new busy thread on a slow core.
- An unbounded queue between threads will eventually run out of memory.
- `adb` drops when the phone sleeps or the cable moves; scripts must notice a dead app instead of waiting for a log line forever (`bench_android.sh` does).
