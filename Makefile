# Vampire Killer (MSX2, 128 KiB Konami MegaROM) disassembly build.
#
#   make            assemble VampireKiller.asm -> VampireKiller.rom
#   make verify     SHA-1 check against VampireKiller.sha1
#   make segments   drop leftover .bin files (all banks are source)
#   make gfx        PNG sheets + annotated stage composites
#   make music      BGM WAVs
#   make sfx        SFX WAVs
#   make clean      remove build output
#
# Prerequisite: tools/sjasmplus (built from source, gitignored)
# Workbench: tools/workbench (MSXDAW submodule)

SRC      := VampireKiller.asm
OUT      := VampireKiller.rom
SHA1FILE := VampireKiller.sha1
include tools/workbench/make/game.mk

.PHONY: segments gfx music sfx

segments:
	tools/workbench/msx/split-rom.sh

gfx:
	python3 tools/gfxdump.py
	python3 tools/roomperm.py --all --composite

music:
	python3 tools/psgplay.py

sfx:
	python3 tools/psgplay.py --sfx
