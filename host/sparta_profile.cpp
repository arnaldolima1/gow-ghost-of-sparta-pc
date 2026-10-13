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

// Not confirmed yet: the executable builds its save names at run time (it
// names "DATA00" but no game name). Check with SPARTA_TRACE_SAVEDATA.
constexpr SaveFolder kSaveFolders[] = {
    {"UCES01401", "Game data", true},
};

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

        // A European console: English, confirm on cross.
        .system_language = 1u,
        .confirm_button = 1u,
    };
    return profile;
}

} // namespace portablekit
