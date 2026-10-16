# Where work stopped

2026-10-15. What is missing in the game is in [MISSING.md](MISSING.md) and what comes next in [ROADMAP.md](ROADMAP.md); this page is where to pick the work up.

## State

- **0.1.8** is published (Windows, macOS, Android): file mods, FXAA, the crash at exit fixed.
- **PortableKit:** pinned at `e2b6536` on the fork's `sparta` branch; [TeamGDB/PortableKit#44](https://github.com/TeamGDB/PortableKit/pull/44) offers this work upstream and is open.
- On the Windows machine the old `build\win` was configured from another folder; configure a fresh build directory (`build\win-check` was started for the check below).

## Next

1. **The check that unblocks the framework:** the fork's `konoha` branch (Naruto's port, `f098c25`) is seven commits ahead of `sparta`, with changes every game takes: the GE colour mask (`0xE8`), depth tests in through mode, block transfers written into drawn framebuffers, the alpha test's never and always (they were swapped), `sceKernelReferSemaStatus`, the game-data install and savedata `FILES`. Build Sparta in full on `konoha`, play the title menu and the boat, and look at the HUD, shadows and anything drawn with an alpha test. Then merge `konoha` into `sparta` and move this submodule.
2. **Fights with many enemies** were felt to slow down: measure with `SPARTA_PERF=log` (guest against render milliseconds) before guessing.
3. ROADMAP.md: remastered soundtrack, cheats, picture filters, true 60 fps, DLC.

## Development layout

Beside the checkout: `../work` is the private `sparta-work` repository (`main`): the release key, launcher art, remastered movies, and locally `deps/` (SDL3) and `refs/` (Purun, Tenkawa). Its `keys/release.env` names the keystore by a macOS path: fix it before building an APK on another machine.
