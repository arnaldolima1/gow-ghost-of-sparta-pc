# Paths every script shares; sourced, not run.
#
#   generated/            the recompiled game code (scripts/generate.sh)
#   build/dev/            the everyday build (scripts/build.sh, scripts/run.sh)
#   build/release/        the Release build a disk image is made from
#   build/release-macos/  PortableKit's release work: dependencies, staging
#   build/analysis/       the analyser's report on the game's executable
#   build/logs/           build.log and build.status of the last build
#   release/macos/        a finished release: Sparta.app, the .dmg, checksums
#
# None of it is committed. The game's own data folder is SPARTA_DATA_DIR,
# else ../work/data beside the repository when it exists (a development
# layout), else the port's per-user folder.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_dir/build"
dev_dir="$build_root/dev"
release_build_dir="$build_root/release"
release_work_dir="$build_root/release-macos"
analysis_dir="$build_root/analysis"
logs_dir="$build_root/logs"
release_dir="$repo_dir/release/macos"
version_file="$repo_dir/VERSION"
if [[ -z "${SPARTA_DATA_DIR:-}" && -d "$repo_dir/../work/data" ]]; then
    export SPARTA_DATA_DIR="$repo_dir/../work/data"
fi
