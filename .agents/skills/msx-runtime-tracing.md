---
name: msx-runtime-tracing
description: >-
  Correlate an MSX game's runtime behaviour to its code and RAM using the
  instrumented CocoaMSX build (DISASMTRACE): execution/memory-write logging and
  full-RAM state snapshots, then diffing snapshots and matching writer PCs. Use
  when identifying what a RAM address means (HP, timers, positions, inventory),
  which routine writes a field, or naming variables/blocks from live play.
---

# MSX runtime tracing

The instrumented emulator lives at `tools/CocoaMSX` (a submodule on the
`disasm-tracing` branch; changes are generic, not VK-specific). It logs
executed addresses, memory writes, and RAM snapshots, each tagged with the ROM
segment currently paged in (`X 06:be44` = seg 6, PC 0xBE44).

## Two capture mechanisms

- **WATCH / EXEC logging** → `generated/disasmtrace.log`. Logs writes to given RAM
  ranges (`W ss:pppp aaaa=vv`) and/or execution of given address ranges. Gives the
  **writer PC** for a field. Ranges are read once at launch — changing them means
  relaunching.
- **State snapshots** → `generated/disasmsnap.bin`. F9 = one snapshot; F8 =
  toggle per-frame auto-snapshot (on-screen red indicator). Each snapshot dumps
  the `SNAPRANGE` RAM window (default `c000-dfff`, all work RAM). **Independent of
  WATCH** — captures everything regardless of what's being logged.

## Cost discipline (important)

- **Snapshots are the cheap, high-yield primary tool.** A short F8 recording of an
  action gives a frame-by-frame timeline of every changed byte. Use it first to
  find *which* addresses matter.
- **Then** use a *targeted* WATCH (just the few addresses of interest) in a follow-
  up run to get writer PCs. Avoid broad EXEC traces — they explode the log.
- Always keep `DEDUP=1`. Keep WATCH ranges tight.
- **Never kill a running emulator** (`kill`, `pkill`, closing CocoaMSX, etc.)
  unless the user specifically asks. The user is usually mid-recording and killing
  it destroys in-progress state. If a relaunch *seems* needed (e.g. to change WATCH
  ranges) but you weren't asked, **ask first**.

## Workflow

1. Build once: `tools/build-cocoamsx.sh` (run outside sandbox: `required_permissions:["all"]`).
2. Launch: `WATCH=<ranges> tools/trace-run.sh <rom>` (knobs: `EXEC WATCH LOG SNAP
   SNAPRANGE DEDUP SOFTGL` — see the script header). `SOFTGL=1` is required on
   Apple Silicon (Metal-backed GL shim segfaults on immediate-mode draws).
3. Confirm it's actually running with the intended env before the user records:
   `pgrep -f CocoaMSX`; `ps eww -p <pid> -o command= | tr ' ' '\n' | grep DISASM`.
   (Process listing may need `required_permissions:["all"]`.)
4. Snapshots append. Record the **baseline frame count** before the user records so
   you analyze only new frames.
5. Ask the user to narrate the action + rough timing ("first hit right after F8").
6. Analyze: `tools/snapdiff.py <snapfile> --track <addr|range>` for a per-frame
   value timeline; diff two frames to see all changes. Correlate changed addresses
   with writer PCs in the log (`grep ' aaaa='`), then annotate the routine at that
   PC's `seg:offset` and rename it/the RAM field per the `konami-msx-disasm` naming
   rule.

## Analysis tips

- Give the user a stationary/known actor as a control (e.g. an enemy that doesn't
  move) to separate its slot from the one you're studying.
- Actor structs: scan a slot base + stride; offset 0 is usually a type/active
  byte. Watch it flip on spawn/hit/death. "Kill" is often "convert slot to a
  death-effect type in place", not an HP decrement — multi-hit HP shows up only on
  tougher enemies/bosses.
- Filter per-frame sprite-list churn (composed OAM shadow) from the actual struct
  fields — the sprite list changes every frame and is noise.

## Reference implementation (paths relative to this repo root)

- `tools/trace-run.sh` — launch + env knobs + preset WATCH ranges.
- `tools/snapdiff.py` — snapshot diff / `--track` timeline.
- `tools/CocoaMSX/Src/Debugger/disasmtrace.{c,h}` — the tracer.
- `docs/progress.md` — RAM map + presets + resume plan.
