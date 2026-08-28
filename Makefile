# Vampire Killer (MSX2, 128 KiB Konami MegaROM) disassembly build.
#
#   make segments   drop leftover .bin files (all banks are source)
#   make            assemble VampireKiller.asm -> VampireKiller.rom
#   make verify     assemble, then SHA-1 check against VampireKiller.sha1
#   make gfx        (re)build PNG sheets in gfx/, gfx/sprites/, gfx/tilesets/, gfx/palettes/, gfx/metatiles/, gfx/fonts/
#   make music      render BGM WAVs from the ROM PSG bytecode (music/)
#   make sfx        render sfx ids 0x01-0x1D into sfx/
#   make guide      player-handbook portraits, annotated maps, stage pages
#   make clean      remove build output
#
# Prerequisite (not committed, gitignored - see README):
#   - tools/sjasmplus : assembler, built from source

# --longptr: no device is set, so let the program counter run past 0x10000.
# The build is a single flat 128 KiB image (16 x 8 KiB segments concatenated),
# which is larger than the Z80's 64 KiB address space; without this flag
# sjasmplus prints harmless "RAM limit exceeded" warnings as the output pointer
# crosses 0x10000.  Output stays byte-exact (see `make verify`).
ASM      := tools/sjasmplus --longptr
SRC      := VampireKiller.asm
OUT      := VampireKiller.rom
SHA1FILE := VampireKiller.sha1
# GNU sha1sum, or BSD/macOS shasum -a 1
SHA1SUM  := $(shell command -v sha1sum 2>/dev/null || echo "shasum -a 1")

.PHONY: all verify segments gfx music sfx guide clean

all: $(SRC)
	$(ASM) $(SRC)

# Drop leftover .bin files (all banks are source).
segments:
	tools/disasm/split-rom.sh

# Rebuild PNG sheets from identified asm / ROM tables (`tools/gfxdump.py`)
# plus per-stage pixel rooms (`tools/roomperm.py --all --pixels`).
gfx:
	python3 tools/gfxdump.py
	python3 tools/roomperm.py --all --pixels

music:
	python3 tools/psgplay.py

sfx:
	python3 tools/psgplay.py --sfx

# Player handbook art + stage inventories under docs/manual/assets/.
guide:
	python3 tools/guide_assets.py

verify: all
	@$(SHA1SUM) -c $(SHA1FILE)

clean:
	rm -f $(OUT)
	rm -f segments/seg*.bin
