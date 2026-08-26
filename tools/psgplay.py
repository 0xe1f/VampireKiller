#!/usr/bin/env python3
"""Render Vampire Killer BGM from the ROM's packed PSG bytecode.

Reimplements sound_tick / sound_fetch (seg14) against an AY-3-8910 model.
Reads the same bytes the assemble uses (references/VampireKiller.rom, or
the rebuilt VampireKiller.rom).  Writes 16-bit mono WAVs into music/.

The output is recognizable but not a complete match to a real MSX (software
AY, loop/fade heuristics).  Fine for catalogue listening; accuracy later.

Usage (from repo root):
  python3 tools/psgplay.py              # all ids 0x80-0x8E
  python3 tools/psgplay.py --id 0x80
  python3 tools/psgplay.py --loops 2 --seconds 90
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "music")

MUSIC_PTR = 0x8DC9
ENV_PTR = 0xAAD6
ENV_PTR_ALT = 0xAAEE
NOTE_TBL = 0x8B81  # sound_note_tbl (odd-aligned; add nibble*2 to L)

# One octave, little-endian periods (sound_note_tbl).  Also loaded from ROM.
NOTE_PERIODS = [
    0x1AB8, 0x1938, 0x17D0, 0x1678, 0x1534, 0x1404,
    0x12E4, 0x11D4, 0x10D4, 0x0FE4, 0x0F00, 0x0E28,
]

# play_sound copies this 20-byte block to each music channel (l515dh).
TEMPLATE = bytes([
    0x00, 0x00,  # +0 stream ptr (filled in)
    0x01, 0x00, 0x00,  # +2 flags (bit0=tone), +3 scale, +4 base vol
    0x00, 0x00, 0x00, 0x00,  # +5 decay start, +6 decay end, +7 octave, +8
    0x01, 0x00, 0x00,  # +9 duration=1 so the first tick fetches
    0x00, 0x00,  # +12 env ptr
    0x01, 0x01, 0x00,  # +14/+15 sfx reload, +16 loop count
    0x00, 0x00, 0x00,  # +17..+19 call return
])

# Mixer AND/OR pairs (sound_mix_*_tbl), indexed by channel 0..2.
MIX_TONE = [(0xFE, 0x08), (0xFD, 0x10), (0xFB, 0x20)]
MIX_NOISE = [(0xF7, 0x01), (0xEF, 0x02), (0xDF, 0x04)]
MIX_BOTH = [(0xF6, 0x00), (0xED, 0x00), (0xDB, 0x00)]
MIX_MUTE = [(0xFF, 0x09), (0xFF, 0x12), (0xFF, 0x24)]

# AY 4-bit volume, ~logarithmic (common emulator table, 16-bit peak).
AY_VOL = [
    0x0000, 0x0385, 0x053D, 0x0770, 0x0AD7, 0x0FD5, 0x15B0, 0x230C,
    0x2B34, 0x43A5, 0x5F2C, 0x7DC9, 0xA199, 0xC8D2, 0xF477, 0xFFFF,
]

TRACKS = {
    0x80: "80_bgm_s00-03",
    0x81: "81_bgm_s04_06_11_12",
    0x82: "82_bgm_s07-09",
    0x83: "83_bgm_s16-17",
    0x84: "84_bgm_s13-15",
    0x85: "85_bgm_s10_18",
    0x86: "86_bgm_boss_dracula",
    0x87: "87_bgm_boss",
    0x88: "88_bgm_boss_dracula_portrait",
    0x89: "89_game_over",
    0x8A: "8A_enter_castle",
    0x8B: "8B_game_over",
    0x8C: "8C_boss_defeated",
    0x8D: "8D_dracula_defeated",
    0x8E: "8E_credits",
}

PSG_HZ = 1_789_772.5  # MSX: 3.579545 MHz / 2
FRAME_HZ = 60.0


def load_rom() -> bytes:
    for path in (
        os.path.join(ROOT, "references", "VampireKiller.rom"),
        os.path.join(ROOT, "VampireKiller.rom"),
    ):
        if os.path.isfile(path):
            data = open(path, "rb").read()
            if len(data) != 0x20000:
                sys.exit("expected 128 KiB ROM at %s (got %d)" % (path, len(data)))
            return data
    sys.exit("no ROM: put one at references/VampireKiller.rom")


def cpu_off(cpu: int) -> int:
    """File offset for a pointer while segs 14/15 are paged at 0x8000/0xA000."""
    if 0x8000 <= cpu < 0xA000:
        return 14 * 0x2000 + (cpu - 0x8000)
    if 0xA000 <= cpu < 0xC000:
        return 15 * 0x2000 + (cpu - 0xA000)
    raise ValueError("music pointer 0x%04X is outside the sound banks" % cpu)


class AY:
    """Minimal AY-3-8910: tone + noise + mixer + 4-bit volume (no HW envelope)."""

    def __init__(self, sample_rate: int):
        self.sr = sample_rate
        self.reg = [0] * 16
        self.tone_cnt = [0, 0, 0]
        self.tone_bit = [0, 0, 0]
        self.noise_cnt = 0
        self.noise_lfsr = 1
        self.noise_bit = 0
        self.sub = 0.0
        self.step = (PSG_HZ / 16.0) / sample_rate

    def write(self, r: int, v: int) -> None:
        self.reg[r & 15] = v & 0xFF

    def _period(self, ch: int) -> int:
        p = self.reg[ch * 2] | ((self.reg[ch * 2 + 1] & 0x0F) << 8)
        return p if p else 1

    def sample(self) -> int:
        self.sub += self.step
        ticks = int(self.sub)
        self.sub -= ticks
        for _ in range(ticks):
            for ch in range(3):
                self.tone_cnt[ch] += 1
                if self.tone_cnt[ch] >= self._period(ch):
                    self.tone_cnt[ch] = 0
                    self.tone_bit[ch] ^= 1
            np = self.reg[6] & 0x1F
            if np == 0:
                np = 1
            self.noise_cnt += 1
            if self.noise_cnt >= np:
                self.noise_cnt = 0
                bit0 = self.noise_lfsr & 1
                # AY 17-bit LFSR: xor bits 0 and 3.
                self.noise_lfsr >>= 1
                if bit0:
                    self.noise_lfsr ^= 0x10004
                self.noise_bit = bit0
        mix = self.reg[7]
        acc = 0
        for ch in range(3):
            tone_off = (mix >> ch) & 1
            noise_off = (mix >> (ch + 3)) & 1
            audible = (tone_off or self.tone_bit[ch]) and (
                noise_off or self.noise_bit
            )
            if not audible:
                continue
            vol = self.reg[8 + ch] & 0x0F
            acc += AY_VOL[vol]
        acc //= 4
        if acc > 32767:
            acc = 32767
        return acc


class Channel:
    __slots__ = ("st", "slot", "psg_ch", "alive", "ea_hits")

    def __init__(self, slot: int, psg_ch: int, ptr: int):
        self.st = bytearray(TEMPLATE)
        self.st[0] = ptr & 0xFF
        self.st[1] = ptr >> 8
        self.slot = slot
        self.psg_ch = psg_ch
        self.alive = True
        self.ea_hits = 0

    def ptr(self) -> int:
        return self.st[0] | (self.st[1] << 8)

    def set_ptr(self, cpu: int) -> None:
        self.st[0] = cpu & 0xFF
        self.st[1] = cpu >> 8


class Driver:
    def __init__(self, rom: bytes):
        self.rom = rom
        self.mixer = 0xBC
        self.fade = 0  # C0A6
        self.live = 0x07  # C0A7 bits 0..2
        self.ay = None  # type: AY | None
        self.ch: list[Channel] = []

    def peek(self, cpu: int) -> int:
        return self.rom[cpu_off(cpu)]

    def peek16(self, cpu: int) -> int:
        return self.peek(cpu) | (self.peek((cpu + 1) & 0xFFFF) << 8)

    def note_period(self, idx: int) -> int:
        return self.peek16(NOTE_TBL + (idx & 0x0F) * 2)

    def wr(self, reg: int, val: int) -> None:
        assert self.ay is not None
        self.ay.write(reg, val)

    def wr_period(self, ch: Channel, period: int) -> None:
        self.wr(ch.psg_ch * 2, period & 0xFF)
        self.wr(ch.psg_ch * 2 + 1, (period >> 8) & 0x0F)

    def wr_vol(self, ch: Channel, vol: int) -> None:
        self.wr(8 + ch.psg_ch, vol & 0x0F)

    def mix_apply(self, ch: Channel, table: list[tuple[int, int]]) -> None:
        a, o = table[ch.psg_ch]
        self.mixer = (self.mixer & a) | o
        self.wr(7, self.mixer)

    def play(self, id80: int, sample_rate: int, loops: int, max_seconds: float, min_seconds: float):
        rec = MUSIC_PTR + ((id80 & 0x7F) * 6)
        ptrs = [self.peek16(rec + i * 2) for i in range(3)]
        self.ay = AY(sample_rate)
        self.mixer = 0xBC
        self.fade = 0
        self.live = 0x07
        self.wr(7, self.mixer)
        self.ch = [Channel(i, i, ptrs[i]) for i in range(3)]

        spf = int(round(sample_rate / FRAME_HZ))
        max_frames = int(max_seconds * FRAME_HZ)
        fade_frames = int(FRAME_HZ)
        pcm = bytearray()
        stop_at = None  # type: int | None

        for frame in range(max_frames + fade_frames + 1):
            self.wr(7, self.mixer)
            for ch in self.ch:
                if ch.alive:
                    self.tick(ch)
            if stop_at is None:
                if self.live & 7 == 0:
                    stop_at = frame + fade_frames
                elif (
                    max(c.ea_hits for c in self.ch) >= loops
                    and frame > int(min_seconds * FRAME_HZ)
                ):
                    stop_at = frame + fade_frames
            gain = 1.0
            if stop_at is not None:
                left = stop_at - frame
                if left <= 0:
                    break
                if left < fade_frames:
                    gain = left / fade_frames
            for _ in range(spf):
                s = int(self.ay.sample() * gain)
                pcm.extend(struct.pack("<h", s))
        return bytes(pcm), ptrs

    def tick(self, ch: Channel) -> None:
        st = ch.st
        dur = st[9]
        dur = (dur - 1) & 0xFF
        st[9] = dur
        if dur == 0:
            self.fetch(ch)
            return
        flags = st[2]
        if flags & 1:
            # Pitched: decay / hold (see sound_ch_tick).
            if dur >= st[11]:
                self._decay_vol(ch)
                return
            if dur >= st[6]:
                return
            self._decay_vol(ch)
            return
        if flags & 0x80:
            return
        if self.sfx_fetch(ch):
            st[2] = flags | 0x80
            st[10] = 0
            self.wr_vol(ch, 0)

    def _decay_vol(self, ch: Channel) -> None:
        vol = ch.st[10]
        nxt = (vol - 1) & 0xFF
        if nxt & 0x80:
            return
        ch.st[10] = nxt
        self.wr_vol(ch, nxt)

    def fetch(self, ch: Channel) -> None:
        cpu = ch.ptr()
        for _ in range(4096):
            op = self.peek(cpu)
            cpu = (cpu + 1) & 0xFFFF
            if op < 0xD0:
                ch.set_ptr(cpu)
                if op >= 0xC0:
                    self._rest(ch, op)
                else:
                    self._note(ch, op)
                return
            cpu = self._command(ch, op, cpu)
            if not ch.alive:
                return
        raise RuntimeError("command loop at 0x%04X" % ch.ptr())

    def _duration(self, ch: Channel, op: int) -> int:
        n = (op & 0x0F) + 1
        scale = ch.st[3]
        acc = 0
        for _ in range(n):
            acc = (acc + scale) & 0xFF
        ch.st[9] = acc
        return acc

    def _rest(self, ch: Channel, op: int) -> None:
        self._duration(ch, op)
        ch.st[10] = 0
        self.wr_vol(ch, 0)

    def _note(self, ch: Channel, op: int) -> None:
        self._duration(ch, op)
        flags = ch.st[2]
        if flags & 1:
            ch.st[11] = (ch.st[9] - ch.st[5]) & 0xFF
            idx = op >> 4
            period = self.note_period(idx)
            srl = ch.st[7]
            steps = srl if srl else 256
            for _ in range(steps):
                period >>= 1
            if flags & 0x40:
                period = (period + 2) & 0xFFFF
            self.wr_period(ch, period)
            vol = (self.fade + ch.st[4]) & 0xFF
            if vol & 0x80:
                vol = 0
            ch.st[10] = vol
            self.wr_vol(ch, vol)
            self.mix_apply(ch, MIX_TONE)
            return
        table = ENV_PTR_ALT if (flags & 4) else ENV_PTR
        env = self.peek16(table + ((op & 0xF0) >> 3))
        ch.st[12] = env & 0xFF
        ch.st[13] = env >> 8
        ch.st[2] = flags & 0x7F
        ch.st[14] = 1

    def _command(self, ch: Channel, op: int, cpu: int) -> int:
        hi = op & 0xF0
        lo = op & 0x0F
        if hi == 0xD0:
            ch.st[3] = lo
            return cpu
        if hi == 0xE0:
            return self._cmd_e(ch, lo, cpu)
        if lo == 0x0F:
            mask = 0x7F
            for _ in range(ch.slot + 1):
                mask = ((mask << 1) | (mask >> 7)) & 0xFF
            self.live &= mask
            ch.alive = False
            self.wr_vol(ch, 0)
            return cpu
        if lo == 0x0E:
            return self._loop(ch, cpu)
        # Envelope params (F0-FD except FE/FF handled above).
        ch.st[4] = (lo + 1) & 0xFF
        b = self.peek(cpu)
        cpu = (cpu + 1) & 0xFFFF
        ch.st[5] = ((b >> 4) - 1) & 0xFF
        ch.st[6] = b & 0x0F
        return cpu

    def _cmd_e(self, ch: Channel, lo: int, cpu: int) -> int:
        if lo < 6:
            ch.st[7] = (6 - lo) & 0xFF
            return cpu
        if lo == 6:
            return cpu  # sfx lock: ignore
        if lo == 7:
            ch.st[2] |= 0x40
            return cpu
        if lo == 0x0A:
            dest = self.peek16(cpu)
            ch.ea_hits += 1
            return dest
        if lo == 0x0B:
            return cpu  # unlock
        if lo == 0x0D:
            dest = self.peek16(cpu)
            ret = (cpu + 2) & 0xFFFF
            ch.st[0x12] = ret & 0xFF
            ch.st[0x13] = ret >> 8
            return dest
        if lo == 0x0E:
            return ch.st[0x12] | (ch.st[0x13] << 8)
        ch.st[2] = (ch.st[2] & 0xF8) | (lo & 7)
        return cpu

    def _loop(self, ch: Channel, cpu: int) -> int:
        n = (ch.st[0x10] - 1) & 0xFF
        if n == 0:
            ch.st[0x10] = 0
            return (cpu + 3) & 0xFFFF
        if n < 0x80:
            ch.st[0x10] = n
            return self.peek16(cpu + 1)
        count = self.peek(cpu)
        ch.st[0x10] = (count - 1) & 0xFF
        return self.peek16((cpu + 1) & 0xFFFF)

    def sfx_fetch(self, ch: Channel) -> bool:
        """True (CY) if the env/sfx stream ended."""
        st = ch.st
        d = (st[14] - 1) & 0xFF
        st[14] = d
        if d != 0:
            return False
        st[14] = st[15]
        cpu = st[12] | (st[13] << 8)
        for _ in range(256):
            b = self.peek(cpu)
            if b == 0xFF:
                return True
            cpu = (cpu + 1) & 0xFFFF
            if b == 0xFE:
                cpu = self._sfx_loop(ch, cpu)
                continue
            hi = b & 0xF0
            c = b
            if hi == 0x10:
                self.wr(6, (c & 0x0F) * 2)
                c = self.peek(cpu)
                cpu = (cpu + 1) & 0xFFFF
                hi = c & 0xF0
            if hi == 0x20:
                self._sfx_mix(ch, c)
                vol_bit = (c << 1) & 0x10
                st[10] = vol_bit
                self.wr_vol(ch, 0 if not vol_bit else 0x0F)
                reload = self.peek(cpu)
                cpu = (cpu + 1) & 0xFFFF
                st[14] = reload
                st[15] = reload
                if c == 0x20:
                    st[12] = cpu & 0xFF
                    st[13] = cpu >> 8
                    return False
                if c < 0x28:
                    continue
                coarse = self.peek(cpu)
                cpu = (cpu + 1) & 0xFFFF
                fine = self.peek(cpu)
                cpu = (cpu + 1) & 0xFFFF
                self.wr(12, coarse)
                self.wr(11, fine)
                continue
            vol = c >> 4
            st[10] = vol
            self.wr_vol(ch, vol)
            period_hi = c & 0x0F
            period_lo = self.peek(cpu)
            cpu = (cpu + 1) & 0xFFFF
            st[12] = cpu & 0xFF
            st[13] = cpu >> 8
            self.wr_period(ch, period_lo | (period_hi << 8))
            return False
        return True

    def _sfx_loop(self, ch: Channel, cpu: int) -> int:
        n = (ch.st[0x11] - 1) & 0xFF
        if n == 0:
            ch.st[0x11] = 0
            return (cpu + 3) & 0xFFFF
        if n < 0x80:
            ch.st[0x11] = n
            return self.peek16(cpu + 1)
        count = self.peek(cpu)
        ch.st[0x11] = (count - 1) & 0xFF
        return self.peek16((cpu + 1) & 0xFFFF)

    def _sfx_mix(self, ch: Channel, c: int) -> None:
        if not (c & 1):
            if c & 2:
                self.mix_apply(ch, MIX_TONE)
            else:
                self.mix_apply(ch, MIX_MUTE)
        elif c & 2:
            self.mix_apply(ch, MIX_BOTH)
        else:
            self.mix_apply(ch, MIX_NOISE)


def write_wav(path: str, sr: int, pcm: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm)


def verify_tables(rom: bytes) -> None:
    off = cpu_off(NOTE_TBL)
    got = [rom[off + i] | (rom[off + i + 1] << 8) for i in range(0, 24, 2)]
    if got != NOTE_PERIODS:
        sys.exit("sound_note_tbl mismatch at 0x%04X: %s" % (NOTE_TBL, ["%04X" % p for p in got]))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--id", type=lambda s: int(s, 0), help="single id 0x80-0x8E")
    ap.add_argument("--loops", type=int, default=2, help="EA-loop repeats before fade")
    ap.add_argument("--min-seconds", type=float, default=20.0, help="play at least this long if the track loops")
    ap.add_argument("--seconds", type=float, default=90.0, help="hard cap")
    ap.add_argument("--rate", type=int, default=22050)
    ap.add_argument("-o", "--out", default=MUSIC)
    args = ap.parse_args()

    rom = load_rom()
    verify_tables(rom)
    ids = [args.id] if args.id is not None else sorted(TRACKS)
    for i in ids:
        if i == 0x8F:
            continue
        if i not in TRACKS:
            sys.exit("unknown id 0x%02X (want 0x80-0x8E)" % i)
        drv = Driver(rom)
        pcm, ptrs = drv.play(
            i, args.rate, max(1, args.loops), args.seconds, args.min_seconds
        )
        name = TRACKS[i]
        path = os.path.join(args.out, name + ".wav")
        write_wav(path, args.rate, pcm)
        sec = len(pcm) / (2 * args.rate)
        print(
            "0x%02X  %s  A/B/C=%04X/%04X/%04X  %.1fs  %s"
            % (i, name, ptrs[0], ptrs[1], ptrs[2], sec, path)
        )


if __name__ == "__main__":
    main()
