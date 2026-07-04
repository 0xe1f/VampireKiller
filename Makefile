# Vampire Killer (MSX2, 128 KiB Konami MegaROM) disassembly build.
#
#   make segments   split the original ROM into segments/seg01..15.bin (needed once)
#   make            assemble VampireKiller.asm -> VampireKiller.rom
#   make verify     assemble, then byte-compare against the original ROM
#   make gfx        (re)build the readable graphics catalogue in gfx/
#   make clean      remove build output
#
# Prerequisites (not committed, both gitignored - see README):
#   - tools/sjasmplus : assembler, built from source
#   - references/VampireKiller.rom : an original ROM (the reference), used to
#     (re)create the segment binaries and to verify the build is byte-identical.

ASM      := tools/sjasmplus
SRC      := VampireKiller.asm
OUT      := VampireKiller.rom
ORIGINAL := references/VampireKiller.rom
BINS     := $(wildcard segments/seg[01][0-9].bin)

.PHONY: all verify segments gfx clean

all: $(SRC)
	$(ASM) $(SRC)

# Recreate the copyrighted segment binaries from an original ROM.
segments:
	tools/split-rom.sh $(ORIGINAL)

# Decompress the graphics streams listed in gfx/manifest.tsv into readable
# .bin/.txt dumps (ROM-derived, not committed).
gfx:
	python3 tools/gfxdump.py

verify: all
	@cmp $(OUT) $(ORIGINAL) && echo "OK: $(OUT) is byte-identical to $(ORIGINAL)"

clean:
	rm -f $(OUT)
