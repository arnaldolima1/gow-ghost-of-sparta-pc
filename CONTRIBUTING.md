# Contributing to Sparta

Thank you for wanting to help. Sparta is a work in progress; [`docs/MISSING.md`](docs/MISSING.md) says what is known to be missing, and the [issues](https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/issues) are the work. These rules follow [PortableKit's contributing guide](https://github.com/TeamGDB/PortableKit/blob/main/CONTRIBUTING.md), which applies here too.

## Where a change belongs

Almost nothing lives in this repository: it is the game's profile (`host/sparta_profile.cpp`), its keys (`host/sparta_keys.cpp`), scripts and packaging. **A change that is true of the PSP, of a file format, or of any game that makes the same call belongs in PortableKit** — on this port's fork, [`arnaldolima1/PortableKit`, branch `sparta`](https://github.com/arnaldolima1/PortableKit/tree/sparta). Only what names this game — its disc id, addresses, save folders, quirks — belongs here. An unimplemented system call is almost always the framework's.

## The rules

- **English only** in everything committed, and in issues and pull requests.
- **No game data, ever.** No disc images, executables (`EBOOT.BIN`, `BOOT.BIN`, decrypted ELFs, PRX modules), code generated from the game (`generated/`), saves, or audio or video taken from the game. Not in commits, not in issues, not in pull requests, not as attachments. `.gitignore` covers `game/`, `generated/`, `overlays/`, `build/` and `release/`; do not work around it.
- **Nothing personal.** No home paths, user names, machine names, private e-mail addresses or IP addresses in anything committed or pasted. Check logs before you paste them.
- **Write it yourself.** Public documentation and observed behaviour are fine to learn from; code from a project whose licence is incompatible with MIT — PPSSPP and other GPL emulators included — must never be copied, adapted or translated line by line. Constants, offsets and format facts are fine.
- **Trace the game; don't recall the hardware.** Turn on the relevant `SPARTA_TRACE_*` switch, read what the game does, then write the code.
- **Bound every run.** `timeout 90 build/dev/bin/SpartaNative`; never leave the game running.
- **Say what you did not verify.**

## How to send a change

1. Fork the repository and create a branch.
2. Build and run the port (see the [README](README.md)).
3. Open a pull request. Say what changed and why, how you verified it (platform, GPU, where in the game, what you looked at), what you did not verify, and which issues it closes.

## Licence

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE), like the rest of the project.
