# Vampire Killer (MSX2, 128 KiB Konami MegaROM) disassembly build.
#
#   make segments   drop leftover .bin files (all banks are source)
#   make            assemble VampireKiller.asm -> VampireKiller.rom
#   make verify     assemble, then byte-compare against the original ROM
#   make gfx        (re)build the readable graphics catalogue in gfx/
#   make music      render BGM WAVs from the ROM PSG bytecode (music/)
#   make clean      remove build output
#
# Prerequisites (not committed, both gitignored - see README):
#   - tools/sjasmplus : assembler, built from source
#   - references/VampireKiller.rom : an original ROM (the reference), used to
#     verify the build is byte-identical.

# --longptr: no device is set, so let the program counter run past 0x10000.
# The build is a single flat 128 KiB image (16 x 8 KiB segments concatenated),
# which is larger than the Z80's 64 KiB address space; without this flag
# sjasmplus prints harmless "RAM limit exceeded" warnings as the output pointer
# crosses 0x10000.  Output stays byte-exact (see `make verify`).
ASM      := tools/sjasmplus --longptr
SRC      := VampireKiller.asm
OUT      := VampireKiller.rom
ORIGINAL := references/VampireKiller.rom

.PHONY: all verify segments gfx music clean

all: $(SRC)
	$(ASM) $(SRC)

# Drop leftover .bin files (all banks are source).
segments:
	tools/split-rom.sh

# Decompress the graphics streams listed in gfx/manifest.tsv into readable
# .bin/.txt dumps (ROM-derived, not committed). Also emit stage pixel sheets.
gfx:
	python3 tools/gfxdump.py
	python3 tools/roomperm.py --all --pixels

music:
	python3 tools/psgplay.py

verify: all
	@cmp $(OUT) $(ORIGINAL) && echo "OK: $(OUT) is byte-identical to $(ORIGINAL)"

clean:
	rm -f $(OUT)
	rm -f segments/seg*.bin
