#!/usr/bin/env bash
# Recompile the game's executable into the AOT corpus.
#
#   scripts/generate.sh [build_dir]     (build/dev by default)
#
# Needs an executable prepared by `SpartaNative --install <image.iso>`, which
# writes EBOOT.ELF into the per-user data directory, or a game directory named
# by SPARTA_GAME_DIR. Output: generated/, which is never committed.
#
# This takes a couple of minutes. Compiling what it produces takes hours, so
# read PortableKit's docs/BRINGING_UP_A_GAME.md before waiting for it: the
# interpreter runs the game without any of this.
set -euo pipefail

source "$(dirname "$0")/common.sh"
build_dir="${1:-$dev_dir}"
if [[ ! -f "$build_dir/build.ninja" ]]; then
    cmake -S "$repo_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DPORTABLEKIT_FFMPEG=system
fi

elf="${SPARTA_EBOOT:-}"
if [[ -z "$elf" ]]; then
    for candidate in \
        "${SPARTA_GAME_DIR:-}/EBOOT.ELF" \
        "${SPARTA_DATA_DIR:-}/EBOOT.ELF" \
        "$HOME/Library/Application Support/Sparta/UCES01401/EBOOT.ELF" \
        "$HOME/.local/share/Sparta/UCES01401/EBOOT.ELF"; do
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
mkdir -p "$analysis_dir" "$repo_dir/generated"
"$build_dir/portablekit/psp_analyze" "$elf" "$analysis_dir/report.json"
# Regenerated in place: psp_recomp rewrites only units whose text changed and
# removes units that no longer exist, so unchanged units keep their timestamps
# and are not recompiled. --sparse-entries makes dispatcher entries only where
# control arrives from outside a block, so the compiler can optimize across
# instructions (docs/PERFORMANCE.md); SPARTA_DENSE_ENTRIES=1 generates the old
# way, an entry at every word.
sparse=--sparse-entries
[[ "${SPARTA_DENSE_ENTRIES:-0}" == 1 ]] && sparse=
"$build_dir/portablekit/psp_recomp" "$elf" --auto "$repo_dir/generated" $sparse

echo
echo "What the recompiler could not lower:"
grep -rho 'unsupported(0x[0-9A-Fa-f]*u, 0x[0-9A-Fa-f]*u, "[^"]*"' "$repo_dir/generated"/*.cpp \
    | sed 's/.*"\(.*\)"/\1/' | sort | uniq -c | sort -rn
