---
name: msx-regen
description: >-
  Regenerate a Konami MSX 8 KiB bank with z80dasm via tools/disasm/regen-seg.sh,
  emit a per-bank symbol file, and strip listing comments. Use when regenerating
  a segment, running regen-seg.sh, strip-listing.py, seg_sym.py, split-rom.sh,
  folding generated/segNN.generated.asm, or after renaming labels in msx.sym.
---

# MSX bank regen

Need `z80dasm`, `tools/sjasmplus`, and a built `<Game>.rom` (`make`, or `ROM=`).
Paths relative to repo root. Do **not** invent a one-off disassembler.

## Regen one bank

```
tools/disasm/regen-seg.sh <n> <org> [segments/banks_XXXX.blocks]
```

`<n>` is the 8 KiB bank index (0-based). `<org>` is that bank's CPU window
(`PHASE` origin). Optional `.blocks` is a paging-window map (same stem as
the window `.asm`; VK: `banks_0123.blocks`). Regen keeps only ranges whose
start is in `[org, org+0x2000)` (rendering only, never bytes).

Writes gitignored scratch:

- `generated/segNN.generated.asm` — listing comments stripped; **fold this**
- `generated/segNN.raw.asm` — address/opcode listing; temporary reference only

`regen-seg.sh` already runs `seg_sym.py` then `strip-listing.py`. Fold by hand
into the paging-window `.asm`. Never copy the generated file over annotated
source. Never commit z80dasm `;addr bytes ascii` tails.

ROM: `$ROM`, else `<Game>.rom` in the repo root (`VampireKiller.rom` here).

## Symbols (`msx.sym` is flat, the ROM is banked)

```
tools/disasm/seg_sym.py N          # generated/segNN.z80dasm.sym
tools/disasm/seg_sym.py --audit    # cross-bank CPU-address collisions
```

Keep new names in `segments/msx.sym`. Do not split into committed per-bank
`.sym` files. After a bulk rename, `--audit` then regen the banks you touched.

Auto labels (`lXXXXh` / `sub_XXXXh`) are left to z80dasm.

## Safety net

```
tools/disasm/strip-listing.py path.asm   # in place; keeps `; word` comments
```

Only needed if listing tails leaked into committed source. Regen already strips.

## Leftover bins

```
tools/disasm/split-rom.sh    # make segments
```

Deletes `segments/segNN.bin`. Once a bank has no `INCBIN`, it must not come back.

## After regen

Audit BIOS-name lies on non-`call`/`jp`/`jr` lines (`ld de,CHKRAM` was `ld de,0`).
`make verify`. Naming rules: `konami-msx-disasm`.
