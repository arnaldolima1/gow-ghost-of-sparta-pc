# Roadmap

Ideas agreed with the player for what comes next, roughly in the order they would be done. Nothing here is started unless it says so. Open bugs are in [MISSING.md](MISSING.md).

## Mods

The **Mods** page (launcher and menu) already has: skipping movies with START, remastered movies (`mods/movies/NAME.264`, made with [Kit Movie Tools](https://github.com/arnaldolima1/kit-movie-tools)) and HD texture packs (`mods/textures/<disc id>`). Every mod lives under `mods/` in the data folder and has an on/off row on that page.

1. **Replace any file of the disc** (`mods/files/`): a file there is read in place of the disc's file at the same path. It is the base for most other mods: a PT-BR translation of the game's text and subtitles, models, sounds. It hooks where the game opens files (`host/hle/hle_io.cpp`, `open_file`, where movie files are already recognised; the game also opens files by sector, `sce_lbn`, resolved with `IsoImage::path_at`). First to do.
2. **Remastered soundtrack** (`mods/music/NAME.ogg` or `.flac`): played in place of the game's AT3 music of the same name, as remastered movies replace movies. The game's music is RIFF AT3 through sceAtrac.
3. **Cheats** (`mods/cheats/`, PPSSPP's CWCheat format): infinite health, orbs, unlocks; each with its own on/off row. Many codes exist for this game.
4. **Picture filters**: sharpening, CRT, colour, applied to the finished picture; a list of shaders on the page.
5. **True 60 fps**: a patch to the game's code so it runs at 60 instead of 30 (today frame interpolation makes the frames in between). Risky: physics and animation timing may speed up.
6. **Downloadable content** (arena and costumes): the game probes `dlcarena.EDAT` and `dlccostume.EDAT`; EDAT is not supported. The most work of the list.

## Antialiasing (Video page)

The renderer has none today: every pipeline and render target uses one sample (`VK_SAMPLE_COUNT_1_BIT` in `host/gpu/vulkan_renderer.cpp`). Internal resolution above ×1 already works as supersampling. An **Antialiasing** row would go on the Video page, under Picture, with a setting `video.antialiasing`:

- **Off** (default).
- **FXAA** (or SMAA): a pass over the finished picture before it is scaled to the window. Cheap, works with everything the game draws, fine on phones. Softens text a little. Do this first.
- **MSAA ×2/×4**: multisampled render targets, resolved before the game's framebuffer is read back, extracted as a texture or presented. Smoother geometry edges, but it touches every render pass, the framebuffer extracts and the write-back to guest memory, and costs a lot of memory bandwidth on phones. Only after FXAA, and only if the edges still bother.
