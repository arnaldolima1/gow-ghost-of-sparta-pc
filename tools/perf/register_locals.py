#!/usr/bin/env python3
"""The experiment of item 4 in docs/PERFORMANCE.md: guest GPRs in locals.

    tools/perf/register_locals.py unit   generated/generated_unit_0172.cpp out.cpp
    tools/perf/register_locals.py blocks generated/generated_unit_0172.cpp out.cpp
    tools/perf/register_locals.py count  a.asm b.asm ...

unit    every ctx.gpr[n] of the unit's _entry function becomes a local for the
        whole function, loaded on entry; all 32 are stored back before every
        rt. call and return and reloaded after every rt. call.
blocks  each block (from one L_xxxxxxxx: label to the next) gets its own
        locals for the GPRs it uses, loaded at its start; the ones it writes
        are stored back before every goto, return and rt. call, and all are
        reloaded after an rt. call. Nothing crosses a label.
count   instructions, loads and stores other than the stack, stack loads and
        stores (spills), and calls, in the _entry function of each assembly
        listing (clang-cl /FA, x86-64 or arm64).

Compile the output with the flags of the build (build.ninja) and /FA, for
x86-64 or with --target=aarch64-pc-windows-msvc for arm64.
"""
import re
import sys

ENTRY = '_entry(CorpusRuntime &rt, AllegrexContext &ctx, std::uint16_t direct_entry_id'
ANCHOR = '    std::uint32_t entry_id = direct_entry_id;\n'
CALL = re.compile(r'rt\.(invoke_chained_direct|invoke_chained_call|interpret|unsupported)\b')


def entry_function(src):
    start = src.index(ENTRY)
    start = src.rindex('\n', 0, start) + 1
    return start, src.index('\n}\n', start) + 1


def call_end(text, j):
    """The end of an rt. call starting at j (after its name)."""
    for open_, close in (('<', '>'), ('(', ')')):
        if text[j] != open_:
            continue
        depth = 0
        while True:
            depth += text[j] == open_
            depth -= text[j] == close
            j += 1
            if depth == 0:
                break
    return j


def wrap_calls(text, spill, reload):
    """Store before, and reload after, every rt. call: comma expressions."""
    out, i = [], 0
    while m := CALL.search(text, i):
        out.append(text[i:m.start()])
        j = call_end(text, m.end())
        call = text[m.start():j]
        pre = f'({spill}), ' if spill else ''
        if m.group(1) == 'unsupported':
            out.append(f'({pre}{call})')
        else:
            out.append(f'({pre}sync_r = {call}, {reload}, sync_r)')
        i = j
    out.append(text[i:])
    return ''.join(out)


def whole_unit(func):
    regs = range(32)
    spill_expr = ', '.join(f'ctx.gpr[{n}] = g{n}' for n in regs)
    reload_expr = ', '.join(f'g{n} = ctx.gpr[{n}]' for n in regs)
    func = re.sub(r'ctx\.gpr\[(\d+)\]', r'g\1', func)
    func = wrap_calls(func, spill_expr, reload_expr)
    func = re.sub(r'(?<!\w)return;', '{ ' + spill_expr + '; return; }', func)
    decl = '    bool sync_r = false;\n' + ''.join(f'    std::uint32_t g{n} = ctx.gpr[{n}];\n' for n in regs)
    return func.replace(ANCHOR, ANCHOR + decl, 1)


def per_block(func):
    parts = re.split(r'^(L_[0-9A-F]{8}):\n', func, flags=re.M)
    out = [parts[0]]
    for name, body in zip(parts[1::2], parts[2::2]):
        used = sorted({int(n) for n in re.findall(r'ctx\.gpr\[(\d+)\]', body)})
        written = sorted({int(n) for n in re.findall(r'ctx\.gpr\[(\d+)\] = ', body)})
        if not used:
            out.append(f'{name}:\n{body}')
            continue
        body = re.sub(r'ctx\.gpr\[(\d+)\]', r'b\1', body)
        spill = ''.join(f'ctx.gpr[{n}] = b{n}; ' for n in written)
        body = wrap_calls(body, ', '.join(f'ctx.gpr[{n}] = b{n}' for n in written),
                          ', '.join(f'b{n} = ctx.gpr[{n}]' for n in used))
        if written:
            body = re.sub(r'goto (L_[0-9A-F]{8}|LOCAL_DISPATCH);', lambda m: '{ ' + spill + f'goto {m.group(1)}; }}', body)
            body = re.sub(r'(?<!\w)return;', '{ ' + spill + 'return; }', body)
        decl = ' '.join(f'std::uint32_t b{n} = ctx.gpr[{n}];' for n in used)
        out.append(f'{name}: {{\n    {decl}\n{body}    {spill}}}\n')
    return ''.join(out).replace(ANCHOR, ANCHOR + '    bool sync_r = false;\n', 1)


def count(path):
    lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
    s = next(i for i, l in enumerate(lines) if re.match(r'^"\?recomp_unit_\d+_entry@[^"]*":', l))
    e = next(i for i in range(s + 1, len(lines)) if lines[i].strip() == '.seh_endproc')
    ins = [re.split(r'#|//', l)[0].strip() for l in lines[s:e] if l.startswith('\t')]
    ins = [l for l in ins if l and not l.startswith('.')]
    arm = any(l.startswith(('ldr', 'str', 'bl\t')) for l in ins)
    if arm:
        mem = [l for l in ins if re.match(r'(ldr|ldur|ldp|str|stur|stp)\w*\s', l)]
        stack = [l for l in mem if re.search(r'\[(sp|x29)\b', l)]
        loads = [l for l in mem if l.startswith('ld') and l not in stack]
        stores = [l for l in mem if l.startswith('st') and l not in stack]
        calls = [l for l in ins if re.match(r'blr?\s', l)]
    else:
        mem = [l for l in ins if 'ptr [' in l]
        stack = [l for l in mem if re.search(r'\[(rsp|rbp)\b', l)]
        loads = [l for l in mem if l not in stack and re.match(r'\w+\s+\w+, \w+ ptr \[', l)]
        stores = [l for l in mem if l not in stack and re.match(r'mov\s+\w+ ptr \[', l)]
        calls = [l for l in ins if l.startswith('call')]
    print(f'{path}: {len(ins)} instructions, {len(loads)} loads, {len(stores)} stores, '
          f'{len(stack)} stack loads and stores, {len(calls)} calls')


def main(argv):
    if len(argv) >= 2 and argv[0] == 'count':
        for path in argv[1:]:
            count(path)
        return
    if len(argv) != 3 or argv[0] not in ('unit', 'blocks'):
        sys.exit(__doc__)
    src = open(argv[1], encoding='utf-8').read()
    start, end = entry_function(src)
    func = (whole_unit if argv[0] == 'unit' else per_block)(src[start:end])
    open(argv[2], 'w', encoding='utf-8', newline='\n').write(src[:start] + func + src[end:])


if __name__ == '__main__':
    main(sys.argv[1:])
