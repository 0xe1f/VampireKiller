#!/usr/bin/env python3
# Copyright 2026 Akop Karapetyan
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Render Konami packed-PSG bytecode through an AY-3-8910 model.

Reimplements the in-house driver (Vampire Killer sound_tick / sound_fetch /
sound_sfx_fetch) so any title that shares that bytecode can be rendered by
pointing --map and the table addresses at its own banks.

AY timing matches the AY-3-8910 (fmaster/8 generators, 16-step envelope
with period*2).  Still not analog-accurate (no speaker filter; loop/fade
heuristics on BGM).

Usage:
  tools/disasm/psgplay.py Game.rom --map 14@8000,15@a000 \\
      --music-ptr 0x8DC9 --sfx-ptr 0x8D8D \\
      --env-ptr 0xAAD6 --env-alt 0xAAEE --note-tbl 0x8B81 \\
      --music-ids 0x80-0x8E --name 0x80=80_theme
  tools/disasm/psgplay.py Game.rom --map ... --sfx --sfx-ids 1-0x1D
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
import wave

BANK_SIZE = 0x2000

# One octave, little-endian periods (sound_note_tbl).  Also loaded from ROM.
NOTE_PERIODS = [
    0x1AB8, 0x1938, 0x17D0, 0x1678, 0x1534, 0x1404,
    0x12E4, 0x11D4, 0x10D4, 0x0FE4, 0x0F00, 0x0E28,
]

# play_sound copies this 20-byte block to each music channel (sound_ch_template).
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

PSG_HZ = 1_789_772.5  # MSX: 3.579545 MHz / 2
FRAME_HZ = 60.0


class BankMap:
    """CPU window -> 8 KiB ROM bank.  windows: [(cpu_base, bank), ...]."""

    def __init__(self, windows, bank_size=BANK_SIZE):
        self.bank_size = bank_size
        self.windows = []
        for cpu_base, bank in sorted(windows):
            self.windows.append((cpu_base, cpu_base + bank_size, bank))

    def cpu_off(self, cpu):
        cpu &= 0xFFFF
        for lo, hi, bank in self.windows:
            if lo <= cpu < hi:
                return bank * self.bank_size + (cpu - lo)
        raise ValueError("music pointer 0x%04X is outside the mapped banks" % cpu)

    @classmethod
    def parse(cls, spec):
        """Parse '14@8000,15@a000' -> BankMap."""
        windows = []
        for part in spec.split(","):
            part = part.strip()
            if not part:
                continue
            if "@" not in part:
                raise ValueError("map entry %r: want BANK@CPU (e.g. 14@8000)" % part)
            bank_s, base_s = part.split("@", 1)
            base_s = base_s.strip()
            cpu_base = int(base_s, 16)  # 8000, a000, or 0x8000
            windows.append((cpu_base, int(bank_s, 0)))
        if not windows:
            raise ValueError("empty --map")
        return cls(windows)


class Tables:
    __slots__ = ("music_ptr", "sfx_ptr", "env_ptr", "env_ptr_alt", "note_tbl")

    def __init__(self, music_ptr, sfx_ptr, env_ptr, env_ptr_alt, note_tbl):
        self.music_ptr = music_ptr
        self.sfx_ptr = sfx_ptr
        self.env_ptr = env_ptr
        self.env_ptr_alt = env_ptr_alt
        self.note_tbl = note_tbl


class AY:
    """AY-3-8910 (MAME timing): generators run at fmaster/8.

    Tone freq = fmaster / (16 * period).  Envelope is 16 steps with the
    period doubled (YM2149 uses 32 steps at twice the clock — same sweep
    rate, finer levels).  SFX 02/envelope streams are unusable if this
    clock is off (old code ticked at fmaster/16 and env at fmaster/256).
    """

    ENV_MASK = 0x0F
    ENV_MUL = 2  # AY: period * 2 vs YM2149's 32-step /1

    def __init__(self, sample_rate: int):
        self.sr = sample_rate
        self.reg = [0] * 16
        self.tone_cnt = [0, 0, 0]
        self.tone_bit = [0, 0, 0]
        self.noise_cnt = 0
        self.noise_prescale = 0
        self.noise_lfsr = 1
        self.noise_bit = 0
        self.sub = 0.0
        self.step = (PSG_HZ / 8.0) / sample_rate
        self.env_cnt = 0
        self.env_step = self.ENV_MASK
        self.env_vol = 0
        self.env_holding = False
        self.env_attack = 0
        self.env_alt = 0
        self.env_hold = 0

    def write(self, r: int, v: int) -> None:
        r &= 15
        self.reg[r] = v & 0xFF
        if r == 13:
            self._env_reset()

    def _env_reset(self) -> None:
        # MAME ay8910_device::envelope_t::set_shape (AY 16-step).
        shape = self.reg[13] & 0x0F
        mask = self.ENV_MASK
        self.env_attack = mask if (shape & 0x04) else 0
        if (shape & 0x08) == 0:
            self.env_hold = 1
            self.env_alt = self.env_attack
        else:
            self.env_hold = shape & 1
            self.env_alt = shape & 2
        self.env_step = mask
        self.env_holding = False
        self.env_cnt = 0
        self.env_vol = self.env_step ^ self.env_attack

    def _env_tick(self) -> None:
        if self.env_holding:
            return
        period = (self.reg[11] | (self.reg[12] << 8)) * self.ENV_MUL
        if period == 0:
            period = self.ENV_MUL
        self.env_cnt += 1
        if self.env_cnt < period:
            return
        self.env_cnt = 0
        self.env_step -= 1
        if self.env_step < 0:
            if self.env_hold:
                if self.env_alt:
                    self.env_attack ^= self.ENV_MASK
                self.env_holding = True
                self.env_step = 0
            else:
                if self.env_alt and (self.env_step & (self.ENV_MASK + 1)):
                    self.env_attack ^= self.ENV_MASK
                self.env_step &= self.ENV_MASK
        self.env_vol = self.env_step ^ self.env_attack

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
                p = self._period(ch)
                while self.tone_cnt[ch] >= p:
                    self.tone_cnt[ch] -= p
                    self.tone_bit[ch] ^= 1
            np = self.reg[6] & 0x1F
            if np == 0:
                np = 1
            self.noise_cnt += 1
            if self.noise_cnt >= np:
                self.noise_cnt = 0
                self.noise_prescale ^= 1
                if not self.noise_prescale:
                    bit0 = self.noise_lfsr & 1
                    bit3 = (self.noise_lfsr >> 3) & 1
                    self.noise_lfsr = (self.noise_lfsr >> 1) | ((bit0 ^ bit3) << 16)
                    self.noise_bit = bit0
            self._env_tick()
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
            amp = self.reg[8 + ch]
            vol = self.env_vol if (amp & 0x10) else (amp & 0x0F)
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
    def __init__(self, rom: bytes, mapper: BankMap, tables: Tables):
        self.rom = rom
        self.mapper = mapper
        self.tables = tables
        self.mixer = 0xBC
        self.fade = 0  # C0A6
        self.live = 0x07  # C0A7 bits 0..2
        self.ay = None  # type: AY | None
        self.ch: list[Channel] = []

    def peek(self, cpu: int) -> int:
        return self.rom[self.mapper.cpu_off(cpu)]

    def peek16(self, cpu: int) -> int:
        return self.peek(cpu) | (self.peek((cpu + 1) & 0xFFFF) << 8)

    def note_period(self, idx: int) -> int:
        return self.peek16(self.tables.note_tbl + (idx & 0x0F) * 2)

    def wr(self, reg: int, val: int) -> None:
        assert self.ay is not None
        self.ay.write(reg, val)

    def wr_period(self, ch: Channel, period: int) -> None:
        self.wr(ch.psg_ch * 2, period & 0xFF)
        self.wr(ch.psg_ch * 2 + 1, (period >> 8) & 0x0F)

    def wr_vol(self, ch: Channel, vol: int) -> None:
        self.wr(8 + ch.psg_ch, vol & 0x1F)

    def mix_apply(self, ch: Channel, table: list[tuple[int, int]]) -> None:
        a, o = table[ch.psg_ch]
        self.mixer = (self.mixer & a) | o
        self.wr(7, self.mixer)

    def play(self, id80: int, sample_rate: int, loops: int, max_seconds: float, min_seconds: float):
        rec = self.tables.music_ptr + ((id80 & 0x7F) * 6)
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

    def play_sfx(self, sid: int, sample_rate: int, max_seconds: float):
        """Solo sfx on PSG C (slot 3), matching play_sound 1..N."""
        ptr = self.peek16(self.tables.sfx_ptr + sid * 2)
        self.ay = AY(sample_rate)
        self.mixer = 0xBF  # all muted; sfx mixer ops enable C
        self.fade = 0
        self.wr(7, self.mixer)
        ch = Channel(3, 2, 0)
        ch.st[12] = ptr & 0xFF
        ch.st[13] = ptr >> 8

        spf = int(round(sample_rate / FRAME_HZ))
        max_frames = int(max_seconds * FRAME_HZ)
        fade_frames = max(1, int(0.12 * FRAME_HZ))
        pcm = bytearray()
        stop_at = None  # type: int | None

        for frame in range(max_frames + fade_frames + 1):
            self.wr(7, self.mixer)
            if stop_at is None:
                if self.sfx_fetch(ch) or frame >= max_frames:
                    self.wr_vol(ch, 0)
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
        return bytes(pcm), ptr

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
        table = self.tables.env_ptr_alt if (flags & 4) else self.tables.env_ptr
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
                env_bit = (c << 1) & 0x10
                st[10] = env_bit
                # AY amp bit4 = use hardware envelope (not volume 0x0F).
                self.wr_vol(ch, env_bit)
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
            if st[10] & 0x10:
                self.wr(13, vol)  # envelope shape
            else:
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
    dirname = os.path.dirname(path)
    if dirname:
        os.makedirs(dirname, exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm)


def verify_note_tbl(rom: bytes, mapper: BankMap, note_tbl: int) -> None:
    off = mapper.cpu_off(note_tbl)
    got = [rom[off + i] | (rom[off + i + 1] << 8) for i in range(0, 24, 2)]
    if got != NOTE_PERIODS:
        sys.exit(
            "note table mismatch at 0x%04X: %s"
            % (note_tbl, ["%04X" % p for p in got])
        )


def parse_id_range(s: str) -> list[int]:
    if "-" not in s:
        return [int(s, 0)]
    a, b = s.split("-", 1)
    lo, hi = int(a, 0), int(b, 0)
    if hi < lo:
        raise argparse.ArgumentTypeError("empty id range %s" % s)
    return list(range(lo, hi + 1))


def parse_name(s: str) -> tuple[int, str]:
    if "=" not in s:
        raise argparse.ArgumentTypeError("--name wants ID=STEM, got %r" % s)
    k, v = s.split("=", 1)
    return int(k, 0), v


def run(
    rom: bytes,
    mapper: BankMap,
    tables: Tables,
    ids: list[int],
    *,
    sfx: bool = False,
    names: dict[int, str] | None = None,
    out_dir: str = ".",
    rate: int = 22050,
    loops: int = 2,
    min_seconds: float = 20.0,
    seconds: float | None = None,
    verify: bool = True,
) -> None:
    names = names or {}
    if verify:
        verify_note_tbl(rom, mapper, tables.note_tbl)
    cap = (4.0 if sfx else 90.0) if seconds is None else seconds
    for i in ids:
        drv = Driver(rom, mapper, tables)
        name = names.get(i, "%02X" % i)
        path = os.path.join(out_dir, name + ".wav")
        if sfx:
            pcm, ptr = drv.play_sfx(i, rate, cap)
            write_wav(path, rate, pcm)
            sec = len(pcm) / (2 * rate)
            print("0x%02X  %s  ptr=%04X  %.2fs  %s" % (i, name, ptr, sec, path))
        else:
            pcm, ptrs = drv.play(i, rate, max(1, loops), cap, min_seconds)
            write_wav(path, rate, pcm)
            sec = len(pcm) / (2 * rate)
            print(
                "0x%02X  %s  A/B/C=%04X/%04X/%04X  %.1fs  %s"
                % (i, name, ptrs[0], ptrs[1], ptrs[2], sec, path)
            )


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("rom", help="ROM image")
    ap.add_argument(
        "--map",
        required=True,
        help="BANK@CPU windows (8 KiB), comma-separated, e.g. 14@8000,15@a000",
    )
    ap.add_argument("--music-ptr", type=lambda s: int(s, 0), required=True,
                    help="6-byte records (3 channel ptrs); id 0x80 is record 0")
    ap.add_argument("--sfx-ptr", type=lambda s: int(s, 0), required=True,
                    help="word table; play_sound indexes id*2 (id 1 = first sfx)")
    ap.add_argument("--env-ptr", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--env-alt", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--note-tbl", type=lambda s: int(s, 0), required=True,
                    help="12 little-endian periods (one octave)")
    ap.add_argument("--sfx", action="store_true", help="render sfx instead of BGM")
    ap.add_argument("--id", type=lambda s: int(s, 0), help="single id")
    ap.add_argument("--music-ids", type=parse_id_range, help="BGM range, e.g. 0x80-0x8E")
    ap.add_argument("--sfx-ids", type=parse_id_range, help="sfx range, e.g. 1-0x1D")
    ap.add_argument("--name", action="append", default=[], metavar="ID=STEM",
                    type=parse_name, help="output filename stem (repeatable)")
    ap.add_argument("--loops", type=int, default=2, help="EA-loop repeats before fade (BGM)")
    ap.add_argument("--min-seconds", type=float, default=20.0,
                    help="play at least this long if the track loops")
    ap.add_argument("--seconds", type=float, default=None,
                    help="hard cap (default 90 BGM / 4 sfx)")
    ap.add_argument("--rate", type=int, default=22050)
    ap.add_argument("-o", "--out", default=".")
    ap.add_argument("--no-verify", action="store_true",
                    help="skip sound_note_tbl sanity check")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.rom):
        sys.exit("no ROM: %s" % args.rom)
    try:
        mapper = BankMap.parse(args.map)
    except ValueError as e:
        sys.exit(str(e))
    tables = Tables(
        args.music_ptr, args.sfx_ptr, args.env_ptr, args.env_alt, args.note_tbl
    )
    if args.id is not None:
        ids = [args.id]
    elif args.sfx:
        if not args.sfx_ids:
            sys.exit("pass --id or --sfx-ids")
        ids = args.sfx_ids
    else:
        if not args.music_ids:
            sys.exit("pass --id or --music-ids")
        ids = args.music_ids
    names = dict(args.name)
    rom = open(args.rom, "rb").read()
    run(
        rom, mapper, tables, ids,
        sfx=args.sfx, names=names, out_dir=args.out, rate=args.rate,
        loops=args.loops, min_seconds=args.min_seconds, seconds=args.seconds,
        verify=not args.no_verify,
    )


if __name__ == "__main__":
    main()
