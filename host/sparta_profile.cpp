// Everything PortableKit has to be told about God of War: Ghost of Sparta.
// The framework reads the rest out of the game's own executable.
//
// The numbers here were read off the player's disc, not recalled: the disc id
// and title from PSP_GAME/PARAM.SFO, the hashes from the files themselves, the
// tag from offset 0xD0 of EBOOT.BIN, and the load address and memory size from
// the ELF's program headers.

#include "profile.hpp"

#include "psprecomp/elf32.hpp"

namespace portablekit {
namespace {

// The executable builds its save names at run time: the game name is the disc
// id, and the save names are its own. The trace shows it loading
// "UCES01401PROFILE00" at boot; "DATA00" is the only other save name the
// executable contains, and has not been seen in a trace yet.
constexpr SaveFolder kSaveFolders[] = {
    {"UCES01401PROFILE00", "Profile", true},
    {"UCES01401DATA00", "Game data", true},
};

// The launcher: charcoal, with Spartan red. Its art is the player's, never
// the repository's: background.jpg and logo.jpg in <data>/launcher/ when they
// put them there, else PIC1.PNG and ICON0.PNG from their disc image.
constexpr LauncherTheme kLauncher{
    .title = "GOD OF WAR",
    .subtitle = "GHOST OF SPARTA",
    .background = 0x161414u,
    .sidebar = 0x0F0E0Eu,
    .panel = 0x1C1919u,
    .accent = 0xA3161Au,
    .accent_bright = 0xD8343Au,
    .text = 0xE8E4DFu,
    .text_dim = 0x9C9590u,
    // Kratos stands to the right with his head near the top.
    .backdrop_focus_y = 0.03f,
    .logo_on_black = true,
    .project_url = "https://github.com/arnaldolima1/gow-ghost-of-sparta-pc",
    .issues_url = "https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/issues",
    .credits = "An unofficial port, played from your own copy of the game.",
};

// The North American release has the same textures: a pack made for it on
// PPSSPP keys the European release's textures alike (checked against one).
// The game itself still names it, in the paths of its downloadable content.
constexpr const char *kTexturePackReleases[] = {"UCUS98737"};

} // namespace

const GameProfile &game() {
    static const GameProfile profile{
        .app_name = "SpartaNative",
        .project_name = "Sparta",
        .env_prefix = "SPARTA",
        .data_organization = "Sparta",
        .data_application = "UCES01401",

        .disc_id = "UCES01401",
        .disc_id_display = "UCES-01401",
        .game_title = "God of War: Ghost of Sparta",
        .executable_path_on_disc = "PSP_GAME/SYSDIR/EBOOT.BIN",
        .param_sfo_path_on_disc = "PSP_GAME/PARAM.SFO",
        .release_name = "the European release (1.00)",
        // PSP_GAME/SYSDIR/EBOOT.BIN of the European release, and the
        // executable it decrypts to.
        .encrypted_executable_sha256 = "b946971243e030973926c78e18d5d6466980229d90dc838b12e419e99bab3769",
        .executable_sha256 = "539f957f7d58a25736509e4d80db87349efb3ef18272cf97362b5a7c84cb18a2",
        // The "~PSP" header's tag, and the key the published tag tables give
        // for it (the same tag as Tenkawa's release).
        .decryption_tag = 0xD91613F0u,
        .decryption_key = {0xEB, 0xFF, 0x40, 0xD8, 0xB4, 0x1A, 0xE1, 0x66,
                           0x91, 0x3B, 0x8F, 0x64, 0xB6, 0xFC, 0xB7, 0x12},

        .load_base = psprecomp::kDefaultPspUserLoadBase,
        .guest_ram_bytes = 32u * 1024u * 1024u,
        .boot_path = "disc0:/PSP_GAME/SYSDIR/EBOOT.BIN",
        // No code overlays are known yet.
        .overlay_slots = {},

        .save_game_name = "UCES01401",
        .save_folders = kSaveFolders,

        .adhoc_product_code = "UCES01401",
        // The game has no multiplayer: no Network page.
        .adhoc_play = false,

        // The game's frame loop waits only on the GE, so without this it
        // flips ten times a vblank and the busy clock then holds it 100 ms.
        // At most one flip a vblank: the game's own frame is one vblank.
        .frame_vblanks = 1,
        .flips_wait_for_vblank = true,
        // Nothing in the game reads its own picture back with the CPU (the
        // pause and power-up screens draw over the last frame on the GE), so
        // the shown frame is not copied back into VRAM every flip.
        .frame_writeback = false,
        // START skips the game's pre-rendered movies.
        .start_skips_movies = true,

        // A European console: English, confirm on cross.
        .system_language = 1u,
        .confirm_button = 1u,

        .texture_pack_releases = kTexturePackReleases,
        // The game is mixed loud; a new player starts at 30%.
        .default_volume = 30u,

        .launcher = &kLauncher,
    };
    return profile;
}

} // namespace portablekit
