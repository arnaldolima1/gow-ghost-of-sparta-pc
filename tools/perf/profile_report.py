#!/usr/bin/env python3
"""Reports on a simpleperf profile of the game thread (scripts/bench_android.sh NAME profile).

    tools/perf/profile_report.py threads  build/bench/NAME.data
    tools/perf/profile_report.py cycles   build/bench/NAME.data [TID]
    tools/perf/profile_report.py children build/bench/NAME.data FUNCTION [TID]
    tools/perf/profile_report.py lines    build/bench/NAME.data FUNCTION [TID]

threads   which threads took the samples (the game thread is the busiest).
cycles    absolute CPU cycles of the main parts of the game thread: compare
          two builds with this, not with percentages, which move whenever
          anything else does.
children  where the time inside FUNCTION goes, by the function it calls
          ("(self)" is its own code).
lines     the same by FUNCTION's own source lines, calls included.

FUNCTION is a substring of the demangled name, e.g. "VulkanRenderer::submit(".
TID defaults to the busiest thread. Symbols come from
build/android/native/bin/libmain.so of the build that was profiled; rebuild
nothing between profiling and reporting.
"""
import collections
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.path.join(ROOT, "build", "android", "native", "bin", "libmain.so")


def ndk_tool(relative):
    sdk = os.environ.get("ANDROID_HOME", os.path.expanduser("~/Library/Android/sdk"))
    ndks = sorted(glob.glob(os.path.join(sdk, "ndk", "*")))
    if not ndks:
        sys.exit("no Android NDK in " + sdk)
    matches = glob.glob(os.path.join(ndks[-1], relative))
    if not matches:
        sys.exit("no " + relative + " in " + ndks[-1])
    return matches[0]


def simpleperf():
    host = "darwin" if sys.platform == "darwin" else "linux"
    return ndk_tool(f"simpleperf/bin/{host}/x86_64/simpleperf")


def samples(data):
    """Yields (tid, cycles, [(symbol, address)] leaf first) for every sample."""
    symdir = os.path.dirname(LIB)
    text = subprocess.run([simpleperf(), "report-sample", "-i", data, "--symdir", symdir, "--show-callchain"],
                          capture_output=True, text=True, check=True).stdout
    current = None
    address = "0"
    for line in text.splitlines():
        s = line.strip()
        if s == "sample:":
            if current:
                yield current
            current = {"tid": None, "n": 0, "frames": []}
        elif current is None:
            continue
        elif s.startswith("thread_id:"):
            current["tid"] = s.split()[1]
        elif s.startswith("event_count:"):
            current["n"] = int(s.split()[1])
        elif s.startswith("vaddr_in_file:"):
            address = s.split()[1]
        elif s.startswith("symbol:"):
            current["frames"].append((s[8:], address))
    if current:
        yield current


def busiest(data):
    totals = collections.Counter()
    for sample in samples(data):
        totals[sample["tid"]] += sample["n"]
    return totals.most_common(1)[0][0]


def threads(data):
    totals = collections.Counter()
    for sample in samples(data):
        totals[sample["tid"]] += sample["n"]
    whole = sum(totals.values())
    for tid, n in totals.most_common(10):
        print(f"{tid:>8}  {100 * n / whole:5.1f}%  {n / 1e9:6.2f} Gcycles")


def cycles(data, tid):
    parts = ["Runtime::run(", "recomp_unit_", "GeState::execute(", "decode_vertices", "VulkanRenderer::submit",
             "VulkanRenderer::present(", "invoke_import"]
    totals = collections.Counter()
    whole = 0
    for sample in samples(data):
        if sample["tid"] != tid:
            continue
        whole += sample["n"]
        seen = set()
        for symbol, _ in sample["frames"]:
            for part in parts:
                if part in symbol and part not in seen:
                    seen.add(part)
                    totals[part] += sample["n"]
    print(f"thread {tid}: {whole / 1e9:.2f} Gcycles")
    for part in parts:
        print(f"  {part:28s} {totals[part] / 1e9:6.2f} Gcycles  {100 * totals[part] / max(whole, 1):5.1f}%")


def children(data, function, tid):
    whole = inside = 0
    child = collections.Counter()
    for sample in samples(data):
        if sample["tid"] != tid:
            continue
        whole += sample["n"]
        frames = sample["frames"]
        for i, (symbol, _) in enumerate(frames):
            if function in symbol:
                inside += sample["n"]
                child[frames[i - 1][0] if i > 0 else "(self)"] += sample["n"]
                break
    print(f"{function}: {100 * inside / max(whole, 1):.1f}% of thread {tid}")
    for name, n in child.most_common(25):
        label = name if name == "(self)" else re.sub(r"[(].*", "", name)[-100:]
        print(f"  {100 * n / whole:5.2f}%  {label}")


def lines(data, function, tid):
    whole = inside = 0
    per_address = collections.Counter()
    for sample in samples(data):
        if sample["tid"] != tid:
            continue
        whole += sample["n"]
        for i, (symbol, address) in enumerate(sample["frames"]):
            if function in symbol:
                inside += sample["n"]
                # A caller's address is a return address: step back one instruction.
                per_address[int(address, 16) - (4 if i > 0 else 0)] += sample["n"]
                break
    addresses = list(per_address)
    symbolizer = ndk_tool("toolchains/llvm/prebuilt/*/bin/llvm-symbolizer")
    out = subprocess.run([symbolizer, "--obj=" + LIB], input="\n".join(hex(a) for a in addresses),
                         capture_output=True, text=True).stdout
    short = function.split("(")[0].split("::")[-1]
    per_line = collections.Counter()
    for address, block in zip(addresses, out.strip().split("\n\n")):
        parts = block.split("\n")
        where = "?"
        for i in range(0, len(parts) - 1, 2):
            if short in parts[i]:
                where = parts[i + 1].split("/portablekit/")[-1].rsplit(":", 1)[0]
        per_line[where] += per_address[address]
    print(f"{function}: {100 * inside / max(whole, 1):.1f}% of thread {tid}")
    for where, n in per_line.most_common(40):
        print(f"  {100 * n / whole:5.2f}%  {where}")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    command, data = sys.argv[1], sys.argv[2]
    if command == "threads":
        threads(data)
    elif command == "cycles":
        cycles(data, sys.argv[3] if len(sys.argv) > 3 else busiest(data))
    elif command in ("children", "lines") and len(sys.argv) > 3:
        tid = sys.argv[4] if len(sys.argv) > 4 else busiest(data)
        (children if command == "children" else lines)(data, sys.argv[3], tid)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
