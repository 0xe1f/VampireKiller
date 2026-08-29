# Vampire Killer

MSXDAW game repo. Workbench: `tools/workbench` (submodule of `~/code/msxdaw`).

Generic skills are user-global (`tools/workbench/bin/install-skills`; also
`~/code/msxdaw/bin/install-skills` in the canonical clone). Follow
`tools/workbench/skills/` as well as game-only `.agents/skills/`
(`vk-gfx-sheets`, `vk-disasm`). Workbench and CocoaMSX changes are documented
in the submodule, not this repo’s `docs/`.

**Placement:** if a helper would apply to a second MSX/Konami cart, put it in
msxdaw (`bin/add-skill`). If it names this ROM’s stems, RAM, banks, or dumpers,
keep it here.

This cart uses historical `segments/` + window files (`banks_0123.asm`, …).
New games use one `banks/bankNN.asm` per 8 KiB mapper bank.
