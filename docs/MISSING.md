# What is missing

What this port does not have yet, most likely to matter first. Measured on macOS 26, Apple M4, Vulkan through MoltenVK, with the recompiled build.

## Where the port is

1. The installer accepts the European disc (`UCES-01401`), decrypts `EBOOT.BIN` and the one PGD file (`ATT_000_STARTSCREEN.BIN`).
2. The logos, the title menu and the opening cutscene play at 60 frames a second and full speed, with no audio underruns (`SPARTA_PERF=log`, `SPARTA_TRACE_STALLS=1`, `SPARTA_TRACE_AUDIO=1`).
3. A new game starts, and the first level (the boat) was played by hand for a few minutes.

**Not verified:** anything past the start of the first level; saving and loading a game; movies other than the opening; Windows and Linux.

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

macOS on Apple Silicon and Android (a Moto g84, Adreno 619) have been run. On that phone the boat holds full speed at ×2 internal resolution most of the time and dips to about 90% in its heaviest fights, where the game's code and the renderer share one thread; *Limit to 30 fps* holds 100% there. At ×3 the GPU cannot keep up. PortableKit builds on Windows and Linux; this port has not been run there.
