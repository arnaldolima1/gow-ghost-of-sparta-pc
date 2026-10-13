// Development helper: decrypts the player's EBOOT.BIN with the profile's tag
// and key, with no check of the result, and prints the SHA-256 of what it
// produced. Used once to fill in GameProfile::executable_sha256.
//
//   decrypt_eboot <EBOOT.BIN> <EBOOT.ELF>

#include "install/executable_preparation.hpp"
#include "profile.hpp"
#include "psprecomp/sha256.hpp"

#include <cstdio>
#include <fstream>
#include <iterator>
#include <vector>

int main(int argc, char **argv) {
    if (argc != 3) {
        std::fprintf(stderr, "usage: %s <EBOOT.BIN> <EBOOT.ELF>\n", argv[0]);
        return 2;
    }
    std::ifstream in(argv[1], std::ios::binary);
    const std::vector<std::uint8_t> eboot{std::istreambuf_iterator<char>(in), {}};
    std::printf("EBOOT.BIN  sha256 %s\n", psprecomp::sha256_bytes(eboot).c_str());
    try {
        const auto &g = portablekit::game();
        const portablekit::install::TagKeyMaterial tag{g.decryption_tag, g.decryption_key, g.decryption_key_table};
        const std::vector<std::uint8_t> elf = portablekit::install::decrypt_executable(eboot, tag);
        std::ofstream(argv[2], std::ios::binary).write(reinterpret_cast<const char *>(elf.data()),
                                                       static_cast<std::streamsize>(elf.size()));
        std::printf("EBOOT.ELF  sha256 %s (%zu bytes)\n", psprecomp::sha256_bytes(elf).c_str(), elf.size());
    } catch (const std::exception &e) {
        std::fprintf(stderr, "error: %s\n", e.what());
        return 1;
    }
    return 0;
}
