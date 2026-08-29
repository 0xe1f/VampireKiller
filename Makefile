# Vampire Killer (MSX2, 128 KiB Konami MegaROM) disassembly build.
#
#   make            assemble VampireKiller.asm -> VampireKiller.rom
#   make verify     SHA-1 check against VampireKiller.sha1
#   make segments   drop leftover .bin files (all banks are source)
#   make gfx        PNG sheets + annotated stage composites
#   make music      BGM WAVs
#   make sfx        SFX WAVs
#   make skills     symlink workbench skills into .cursor/skills/
#   make clean      remove build output
#
# Prerequisite: tools/sjasmplus (built from source, gitignored)
# Workbench (tools/workbench) is required for gfx / music / sfx / segments
# and for regen — not for assemble or verify.

SRC      := VampireKiller.asm
OUT      := VampireKiller.rom
SHA1FILE := VampireKiller.sha1
ASM      ?= tools/sjasmplus --longptr
SHA1SUM  ?= $(shell command -v sha1sum 2>/dev/null || echo "shasum -a 1")

.PHONY: all verify clean segments gfx music sfx skills

all: $(SRC)
	$(ASM) $(SRC)

verify: all
	@$(SHA1SUM) -c $(SHA1FILE)

clean:
	rm -f $(OUT)
	rm -f banks/*.bin segments/seg*.bin

segments:
	tools/workbench/msx/split-rom.sh

gfx:
	python3 tools/gfxdump.py
	python3 tools/roomperm.py --all --composite

music:
	python3 tools/psgplay.py

sfx:
	python3 tools/psgplay.py --sfx

skills:
	tools/workbench/bin/install-skills
