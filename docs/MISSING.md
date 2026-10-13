# What is missing

What this port does not have yet, most likely to matter first. Measured on macOS 26, Apple M4, Vulkan through MoltenVK, with the recompiled build.

## Where the port is

1. The installer accepts the European disc (`UCES-01401`), decrypts `EBOOT.BIN` and the one PGD file (`ATT_000_STARTSCREEN.BIN`).
2. The logos, the title menu and the opening cutscene play at 60 frames a second and full speed, with no audio underruns (`SPARTA_PERF=log`, `SPARTA_TRACE_STALLS=1`, `SPARTA_TRACE_AUDIO=1`).
3. A new game starts, and the first level (the boat) was played by hand for a few minutes.

**Not verified:** anything past the start of the first level; saving and loading a game; movies other than the opening; Windows, Linux and Android.

## Known gaps

### The GE stencil test

The game enables the stencil test (GE commands `0x24`, `0xDC`, `0xDD`) in many scene passes and in the bloom composite, which PortableKit's renderer does not implement. Nothing visibly wrong has been traced to it yet; it is the first suspect for any masking error.

### Imports with no implementation

Two of the game's 206 imports (`SPARTA_LIST_STUBS=1`): `LoadExecForUser::sceKernelLoadExec` and `sceAtrac3plus::sceAtracSetAA3DataAndGetID`. Neither has been seen called; the game's music is RIFF AT3, not AA3.

### The GE takes no emulated time

The game's frame loop waits on nothing but the GE. PortableKit runs a display list instantly, so without the profile's `flips_wait_for_vblank` the game flips about ten times a vblank and the busy clock then holds it for 100 ms. The cap fixes the symptom; a model of the GE's own time would fix the cause.

### Downloadable content

The game probes `ms0:/PSP/GAME/UCUS98737/dlcarena.EDAT` and `dlccostume.EDAT` and carries on without them. EDAT is not supported.

## Platforms

Only macOS on Apple Silicon has been run. PortableKit builds on Windows and Linux and has an Android packaging path (see Purun's `scripts/build_android.sh`); this port has been built and run on none of them.
