# Vampire Killer

This is an [MSXDAW](https://github.com/) game repo (MSX Disassembly Workbench).

- Workbench (tools, generic skills): `tools/workbench` (git submodule of `~/code/msxdaw`).
- Generic skills live in `tools/workbench/skills/` and are linked into this repo's `.cursor/skills/` (`tools/workbench/bin/install-skills`). Never `~/.cursor/skills`.
- Game-only skills live in `.agents/skills/` (`vk-gfx-sheets`, `vk-disasm`). Do not copy DAW skills here.

**Placement:** if a helper would apply to a second MSX/Konami cart, put it in msxdaw (`bin/add-skill`). If it names this ROM’s stems, RAM, banks, or dumpers, keep it in this repo.

Workbench and CocoaMSX changes are documented in the submodule, not this repo’s `docs/`.

This cart uses historical `segments/` + window files (`banks_0123.asm`, …).
New games use one `banks/bankNN.asm` per 8 KiB mapper bank.
