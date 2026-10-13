#!/usr/bin/env bash
# Recompile the game's executable into the AOT corpus.
#
#   scripts/generate.sh [build_dir]
#
# Needs an executable prepared by `SpartaNative --install <image.iso>`, which
# writes EBOOT.ELF into the per-user data directory, or a game directory named
# by SPARTA_GAME_DIR. Output: generated/, which is never committed.
#
# This takes a couple of minutes. Compiling what it produces takes hours, so
# read PortableKit's docs/BRINGING_UP_A_GAME.md before waiting for it: the
# interpreter runs the game without any of this.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${1:-$repo_dir/out}"

elf="${SPARTA_EBOOT:-}"
if [[ -z "$elf" ]]; then
    for candidate in \
        "${SPARTA_GAME_DIR:-}/EBOOT.ELF" \
        "${SPARTA_DATA_DIR:-}/EBOOT.ELF" \
        "$HOME/Library/Application Support/Sparta/UCES01401/EBOOT.ELF" \
        "$HOME/.local/share/Sparta/UCES01401/EBOOT.ELF" \
        "$repo_dir/../work/data/EBOOT.ELF"; do
        if [[ -f "$candidate" ]]; then elf="$candidate"; break; fi
    done
fi
if [[ ! -f "$elf" ]]; then
    echo "error: no prepared executable found." >&2
    echo "Run '$build_dir/bin/SpartaNative --install <image.iso>' first," >&2
    echo "or set SPARTA_EBOOT to the decrypted EBOOT.ELF." >&2
    exit 1
fi

cmake --build "$build_dir" --target psp_analyze psp_recomp
mkdir -p "$repo_dir/analysis" "$repo_dir/generated"
"$build_dir/portablekit/psp_analyze" "$elf" "$repo_dir/analysis/report.json"
# Regenerated in place: psp_recomp rewrites only units whose text changed and
# removes units that no longer exist, so unchanged units keep their timestamps
# and are not recompiled.
"$build_dir/portablekit/psp_recomp" "$elf" --auto "$repo_dir/generated"

echo
echo "What the recompiler could not lower:"
grep -rho 'unsupported(0x[0-9A-Fa-f]*u, 0x[0-9A-Fa-f]*u, "[^"]*"' "$repo_dir/generated"/*.cpp \
    | sed 's/.*"\(.*\)"/\1/' | sort | uniq -c | sort -rn
