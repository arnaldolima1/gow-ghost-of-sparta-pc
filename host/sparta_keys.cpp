// The console's keys for this port: the framework's built-in ones, plus the
// keys PGD data needs, read from the player's keys file. The game keeps one
// file in PGD (PSP_GAME/USRDIR/DATA/ATT_000_STARTSCREEN.BIN), and the built-in
// set does not carry those keys, so the port is built with EXTERNAL_KEYS and
// this file stands in for crypto_keys_builtin.cpp.
//
// The keys file is the desktop app's format (docs/DESKTOP_APP.md, "Keys"):
// SPARTA_KEYS, or keys.txt in the data folder. Only the PGD names are read
// here, and each is checked against the fingerprint the desktop app uses, so
// a wrong key is named instead of turning the file into garbage.

#include "crypto_keys.hpp"

// The built-in keys under another name, so this file can start from them.
#define crypto_keys builtin_crypto_keys
#define keys_come_from_keys_file builtin_keys_come_from_keys_file
#include "crypto_keys_builtin.cpp"
#undef crypto_keys
#undef keys_come_from_keys_file

#include "install/user_data.hpp"
#include "profile.hpp"
#include "psprecomp/sha256.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <string>

namespace portablekit {
namespace {

struct PgdKey {
    const char *name; // lower case, as the file is compared
    const char *sha256;
    int amctrl_index; // 0: a KIRK slot
    std::uint8_t kirk_slot;
};
constexpr PgdKey kPgdKeys[] = {
    {"kirk.aes.38", "b5e2a84dbaaf99015874182a8609494d3c8e38f1837755ee29858c78b986ad17", 0, 0x38u},
    {"kirk.aes.39", "be3798d2e2a46c0018a4f7e41f5557e6cc2aeb64b0b15ae6b7063a8fa41c8559", 0, 0x39u},
    {"kirk.aes.63", "16df5079b5e31b07045b9d117c9db8bf9c45e606dbe4a9c71bb763f12d61be83", 0, 0x63u},
    {"amctrl.1cd4", "dbe5dd77c4a5f3b930b30f520ae71064a4b48161ba43d79252351effc0ecb403", 1, 0},
    {"amctrl.1ce4", "4aae0892755232421ac3077d844110b0c0334eeadc9cef6093e55a3fb8e56ee4", 2, 0},
    {"amctrl.1cf4", "e0942366cf4a2142ac1369df3d404198ac8d9bf9df73ccde6e540f2554dbcf4c", 3, 0},
    {"amctrl.dnas.1a90", "3f238f8d5e24ce9402f00be5bb869155d83bcf05457948faa36822a20af04057", 4, 0},
    {"amctrl.dnas.1aa0", "47d6a491c1dc0424e79d60b28fd7f9fc9fb6f7be0552cf4e77dfdcbea3260869", 5, 0},
};

std::filesystem::path keys_file_path() {
    if (const char *keys = env("KEYS"); keys != nullptr && *keys != '\0') return install::path_from_utf8(keys);
    if (const char *data = env("DATA_DIR"); data != nullptr && *data != '\0')
        return install::path_from_utf8(data) / "keys.txt";
    return install::user_data_directory() / "keys.txt";
}

std::string trimmed(std::string text) {
    const auto space = [](unsigned char c) { return std::isspace(c) != 0; };
    text.erase(text.begin(), std::find_if_not(text.begin(), text.end(), space));
    text.erase(std::find_if_not(text.rbegin(), text.rend(), space).base(), text.end());
    return text;
}

// "12 46 8D ..." or "12468D...", 16 bytes; false otherwise.
bool parse_key(const std::string &text, Key16 &out) {
    std::string hex;
    for (const char c : text)
        if (std::isxdigit(static_cast<unsigned char>(c)) != 0) hex += c;
        else if (c != ' ' && c != ':' && c != ',') return false;
    if (hex.size() != 32u) return false;
    for (std::size_t i = 0; i < 16u; ++i) out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2u, 2u), nullptr, 16));
    return true;
}

void add_pgd_keys(CryptoKeys &keys) {
    const std::filesystem::path path = keys_file_path();
    std::ifstream in(path);
    if (!in) return;
    std::string line;
    int added = 0;
    while (std::getline(in, line)) {
        if (const auto hash = line.find('#'); hash != std::string::npos) line.resize(hash);
        const auto equals = line.find('=');
        if (equals == std::string::npos) continue;
        std::string name = trimmed(line.substr(0, equals));
        std::transform(name.begin(), name.end(), name.begin(), [](unsigned char c) { return std::tolower(c); });
        const auto known = std::find_if(std::begin(kPgdKeys), std::end(kPgdKeys),
                                        [&](const PgdKey &key) { return name == key.name; });
        if (known == std::end(kPgdKeys)) continue;
        Key16 key{};
        if (!parse_key(trimmed(line.substr(equals + 1u)), key)) {
            std::cerr << "[keys] " << name << " is not 16 bytes of hex; it is ignored\n";
            continue;
        }
        if (psprecomp::sha256_bytes(key) != known->sha256) {
            std::cerr << "[keys] " << name << " is not the right key: its fingerprint does not match\n";
            continue;
        }
        if (known->amctrl_index != 0) keys.amctrl[known->amctrl_index] = key;
        else keys.kirk_aes[known->kirk_slot] = key;
        ++added;
    }
    std::cout << "[keys] " << added << " PGD keys from " << path.string() << "\n";
}

} // namespace

const CryptoKeys *crypto_keys() {
    static const CryptoKeys keys = [] {
        CryptoKeys merged = *builtin_crypto_keys();
        add_pgd_keys(merged);
        return merged;
    }();
    return &keys;
}

// Like the built-in keys: the port's own keys file is read for the keys HLE
// extension modules declare as well.
bool keys_come_from_keys_file() { return false; }

} // namespace portablekit
