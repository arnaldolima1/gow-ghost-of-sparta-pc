# What is missing

What this port does not have yet, most likely to matter first. Measured on macOS 26, Apple M4, Vulkan through MoltenVK, with the recompiled build.

## Where the port is

1. The installer accepts the European disc (`UCES-01401`), decrypts `EBOOT.BIN` and the one PGD file (`ATT_000_STARTSCREEN.BIN`).
2. The logos, the title menu and the opening cutscene play at 60 frames a second and full speed, with no audio underruns (`SPARTA_PERF=log`, `SPARTA_TRACE_STALLS=1`, `SPARTA_TRACE_AUDIO=1`).
3. A new game starts, and the first level (the boat) was played by hand for a few minutes.
4. On Windows (0.1.7, AMD Radeon RX 7600) the game was played further, past the boat, saving and loading in several slots from the save list.

**Not verified:** most of the game past the first levels; movies other than the opening and `R6_AST_2`; Linux.

## Graphics: where the work stopped

A handoff for whoever picks this up next. What comes after the bugs (mods, antialiasing) is in [ROADMAP.md](ROADMAP.md). The fixes are in the PortableKit fork's `sparta` branch.

**Fixed (2026-10-14/15, tested on Windows by playing):**

- *Shadows far from the characters, and too large.* The GE's texture mapping registers (`0xC0` TMAP, `0xC1` TEXSHADELS) were ignored, so every draw took its vertices' UVs. The game projects each character's shadow map onto the floor with the texture matrix (TMAP mode 1, position source). PortableKit `76f8443` implements UV, texture-matrix projection and shade (environment) mapping.
- *A dark rectangle around every shadow, and white lines along edges.* Through-mode vertices without a colour must take the material colour even when the lighting enable is left on; the renderer drew them white. The game clears its shadow maps with such sprites, so each map got a white border. PortableKit `cb96bd2`. The player confirmed both are gone.

**Open:**

1. **"Textures jumping" (the main open bug).** In one area the player reached (past the boat; ask the player for a save near it), parts of the map flash, or a texture seems to jump to another place for a frame, now and then. Not reproduced here yet. First thing to try: set *Video › Frame rate* to 30 (`video.frame_rate`, which turns frame interpolation off). If the flashes stop, the cause is interpolation (blended movement between two frames, probably for draws matched to the wrong draw of the previous frame); if not, look at framebuffer extracts and render-target aliasing. Switches that help: `SPARTA_TRACE_FB_TEXTURES=1`, `SPARTA_NO_TARGET_ALIASES=1`, `SPARTA_NO_TARGET_CLEAR=1`, `SPARTA_NO_SPRITE_CLAMP=1`, `SPARTA_NO_LIGHTING=1`. Capture with `SPARTA_INPUT_SCRIPT` (`shot`, `pad`, `key`, `drop`, `quit` steps) and `SPARTA_SCREENSHOT_DIR`; run on a copy of the data folder (`SPARTA_DATA_DIR`) so the player's saves stay untouched.
2. **Dark bands at the foot of some walls** (below).
3. **The AMD Vulkan driver (`amdvlk64.dll`) sometimes crashes as the program exits**, after the game has stopped. Not looked into.
4. **Remastered movies** (`mods/movies/NAME.264`): the subtitles the game draws over a movie should stay on top of the replacement; not checked. Colours of the replacement against the original not compared closely.

## Known gaps

### Dark bands at the foot of some walls

On the boat, the vertical faces at the foot of raised platforms come out pitch black. Without lighting (`SPARTA_NO_LIGHTING=1`) they are dark grey, so it is the lighting the GE's model gives them; whether the PSP shows them as dark has not been compared.

### Imports with no implementation

Two of the game's 206 imports (`SPARTA_LIST_STUBS=1`): `LoadExecForUser::sceKernelLoadExec` and `sceAtrac3plus::sceAtracSetAA3DataAndGetID`. Neither has been seen called; the game's music is RIFF AT3, not AA3.

### The GE takes no emulated time

The game's frame loop waits on nothing but the GE. PortableKit runs a display list instantly, so without the profile's `flips_wait_for_vblank` the game flips about ten times a vblank and the busy clock then holds it for 100 ms. The cap fixes the symptom; a model of the GE's own time would fix the cause.

### Downloadable content

The game probes `ms0:/PSP/GAME/UCUS98737/dlcarena.EDAT` and `dlccostume.EDAT` and carries on without them. EDAT is not supported.

## Platforms

macOS on Apple Silicon, Android (a Moto g84, Adreno 619) and Windows 11 (clang-cl, AMD Radeon RX 7600: 60 fps, full speed) have been run. On that phone the boat holds full speed at ×2 internal resolution most of the time and dips to about 90% in its heaviest fights, where the game's code and the renderer share one thread; *Limit to 30 fps* holds 100% there. At ×3 the GPU cannot keep up. PortableKit builds on Linux; this port has not been run there.
