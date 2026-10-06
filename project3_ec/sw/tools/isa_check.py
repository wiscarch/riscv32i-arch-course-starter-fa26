#!/usr/bin/env python3
"""
Fail the build if a program uses anything outside the WISC-F25 instruction set.

The point is to make "only use supported instructions" a property the build
enforces rather than a rule someone has to remember. Checks three things:

  1. every instruction in .text is one of the 37 supported instructions
  2. .data is empty (a reset does not reload memory, so initialised mutable
     globals would come back stale)
  3. the image fits the memory budget

Usage: isa_check.py <name> <disasm.txt> <sections.txt> [--max-bytes N]

Takes objdump output as text rather than invoking objdump itself. The
Makefile runs it in the toolchain container, so the host needs no Python.
"""

import re
import sys

# The 37 instructions of WISC-F25.
REAL = {
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
    "addi", "slti", "sltiu", "andi", "ori", "xori", "slli", "srli", "srai",
    "lui", "auipc",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "jal", "jalr",
    "lb", "lbu", "lh", "lhu", "lw", "sb", "sh", "sw",
    "ebreak",
}

# Pseudo-instruction spellings objdump prints. Each is a legal encoding of
# something in REAL, so these are accepted -- but they have to be listed
# explicitly or every real program trips the checker on its first `mv`.
PSEUDO = {
    "nop", "mv", "li", "la", "not", "neg", "seqz", "snez", "sltz", "sgtz",
    "beqz", "bnez", "blez", "bgez", "bltz", "bgtz",
    "bgt", "ble", "bgtu", "bleu",
    "j", "jr", "ret", "call", "tail",
}

ALLOWED = REAL | PSEUDO

# Helpers the compiler emits calls to when C asks for something the ISA
# cannot do. With -nostdlib these normally fail at link time, but check
# anyway in case libgcc ever gets linked in deliberately.
LIBGCC = re.compile(r"__(mul|div|udiv|mod|umod|ashl|ashr|lshr|cmp|ucmp)[a-z]*[23]")

DISASM = re.compile(r"^\s*[0-9a-f]+:\s+[0-9a-f]+\s+([a-z][a-z0-9._]*)")


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2

    name, disasm_path, sections_path = sys.argv[1], sys.argv[2], sys.argv[3]
    max_bytes = 4096
    if "--max-bytes" in sys.argv:
        max_bytes = int(sys.argv[sys.argv.index("--max-bytes") + 1])

    with open(disasm_path) as f:
        text = f.read()

    bad = []
    for line in text.splitlines():
        m = DISASM.match(line)
        if m and m.group(1) not in ALLOWED:
            bad.append((line.strip(), m.group(1)))

    calls = sorted(set(LIBGCC.findall(text)))

    # Section sizes.
    with open(sections_path) as f:
        sizes = f.read()
    section = {}
    for line in sizes.splitlines():
        f = line.split()
        if len(f) >= 7 and f[0].isdigit():
            section[f[1]] = int(f[2], 16)

    loaded = sum(section.get(s, 0) for s in (".text", ".rodata", ".data"))
    total = loaded + section.get(".bss", 0)

    errors = []
    if bad:
        errors.append("uses instructions not in WISC-F25:")
        for line, mnem in bad[:20]:
            errors.append("    %-56s <- %s" % (line, mnem))
    if calls:
        errors.append("calls compiler helper routines: " + ", ".join(calls))
        errors.append("    (no M extension -- avoid *, / and %%)")
    if section.get(".data", 0):
        errors.append(".data is %d bytes, must be 0" % section[".data"])
        errors.append("    (reset does not reload memory; use const or init at runtime)")
    if total > max_bytes:
        errors.append("image is %d bytes, budget is %d" % (total, max_bytes))

    if errors:
        print("ISA CHECK FAILED: %s" % name, file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    print("  ok  %-14s text %4d  rodata %3d  bss %3d  stack %4d" % (
        name, section.get(".text", 0), section.get(".rodata", 0),
        section.get(".bss", 0), max_bytes - total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
