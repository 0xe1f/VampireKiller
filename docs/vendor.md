# Vendors

The cloaked sitting merchant. He is not a `0xC800` actor. Two 16-byte
slots at `0xC5B5` / `0xC5C5` plus a transaction block around `0xC700`.
Play tick: `vendor_tick` (seg2 `0x91C5`). Whip outcomes: `0x92AE`–`0x9377`.
Shop: resident `state_vendor` (main state 12) calling into seg2 while it
is paged at `0x8000`.

Art: eight 8×8 4bpp tiles (`vendor_tiles`, seg10 `0xBDA7`). `hud_cache_load`
→ `vendor_cache_load` paints five 32×32 copies into VRAM page 1, Y=`0xA0`,
X = `0, 32, 64, 96, 128`, swapping nibble `0xF` (the cloak) from
`vendor_recolor_tbl`. `vendor_draw` LMMMs one of those onto the playfield
(colour 0 skip). Event 6 overwrites that cache with `dracula_portrait_parts`
(no vendors in stage 18 room 9). Preview: `gfx/vendor.png`.

## Placement

Scenery attr bits7–6 = `11` (`scenery_vendor` `0xC0`), or a `scenery_cover`
(`0x7F`) wall whose reveal byte has those bits. Bits5–2 index
`vendor_offer_id` (the item he will sell). Bits1–0 are the **script slot**
`0..3` (`ix+5` after `vendor_spawn`).

`scenery_vendors_compact` walks the unpacked `0xE000` rooms into `0xDE00`
(48 rooms × 4 bytes: up to two vendors × `{offer id, whip counter}`). The
counter byte starts at 0. Trailing zeros in `vendor_offer_id` after the
knife are unused.

`scenery_load` (stage bridge / game start `play_screen_build`) unpacks the
hub stream and **rebuilds** `0xDE00`, which zeros every whip counter.
Room-to-room instantiation is `scenery_room_load` from `actor_state_reset`;
it does not re-run `scenery_vendor_index`, so the 8-whip index **persists**
if you leave and return during the same stage. `vendor_leave` zeros the
`0xE000` pos byte, so he does not come back until scenery is unpacked again.

33 vendors in the packed lists (courtyard has none). Slot counts: 10 / 7 /
6 / 10 for scripts 0..3. Stage 18 room 9 is empty on purpose.

| Stage | Room | Cell (X,Y) | Script | Offer | Attr | Wall |
|------:|-----:|:-----------|-------:|-------|------|------|
| 1 | 7 | (12,10) | 1 | knife | `E1` | cover |
| 2 | 0 | (10,2) | 1 | potion | `D5` | open |
| 2 | 0 | (12,10) | 2 | yellow shield | `CE` | cover |
| 2 | 2 | (10,4) | 3 | holy water | `DB` | cover |
| 3 | 2 | (10,6) | 0 | cross | `DC` | cover |
| 4 | 1 | (12,10) | 0 | lockpick | `C4` | open |
| 4 | 2 | (4,4) | 2 | potion | `D6` | open |
| 5 | 3 | (12,8) | 3 | hourglass | `D3` | cover |
| 6 | 0 | (12,2) | 1 | potion | `D5` | cover |
| 6 | 2 | (2,3) | 3 | knife | `E3` | cover |
| 7 | 0 | (2,3) | 0 | candle | `C0` | open |
| 7 | 8 | (2,9) | 0 | red shield | `C8` | open |
| 8 | 2 | (12,7) | 3 | yellow shield | `CF` | open |
| 8 | 3 | (12,7) | 3 | hourglass | `D3` | open |
| 9 | 8 | (12,9) | 0 | cross | `DC` | cover |
| 10 | 1 | (2,3) | 1 | lockpick | `C5` | open |
| 10 | 8 | (2,9) | 2 | yellow shield | `CE` | open |
| 11 | 1 | (6,9) | 1 | candle | `C1` | cover |
| 11 | 3 | (10,9) | 3 | potion | `D7` | cover |
| 12 | 4 | (8,7) | 3 | cross | `DF` | open |
| 13 | 0 | (2,3) | 3 | knife | `E3` | cover |
| 13 | 4 | (2,9) | 2 | lockpick | `C6` | open |
| 13 | 6 | (12,3) | 1 | hourglass | `D1` | cover |
| 13 | 10 | (12,9) | 0 | holy water | `D8` | cover |
| 14 | 6 | (6,9) | 1 | candle | `C1` | open |
| 15 | 0 | (12,3) | 2 | potion | `D6` | cover |
| 15 | 2 | (12,3) | 0 | cross | `DC` | cover |
| 17 | 1 | (8,9) | 3 | holy water | `DB` | cover |
| 17 | 6 | (12,9) | 0 | knife | `E0` | cover |
| 17 | 8 | (2,3) | 2 | red shield | `CA` | open |
| 17 | 9 | (2,3) | 0 | potion | `D4` | open |
| 18 | 1 | (12,9) | 3 | knife | `E3` | open |
| 18 | 8 | (2,3) | 0 | potion | `D4` | open |

`vendor_offer_id` (seg0 `0x5B12`):

| Index | Bonus id | Item |
|------:|---------:|------|
| 0 | `0x0E` | candle |
| 1 | `0x12` | lockpick |
| 2 | `0x03` | red shield |
| 3 | `0x04` | yellow shield |
| 4 | `0x0A` | hourglass |
| 5 | `0x16` | potion |
| 6 | `0x1E` | holy water |
| 7 | `0x1D` | cross |
| 8 | `0x1B` | knife |

Axe (`0x1C`) is a world drop only; it is not in this table.

## Slot layout (`0xC5B5` / `0xC5C5`)

`vendor_spawn` (`0x9180`): HL = map pos, B = offer index (bits5–2), C =
script (bits1–0). `vendor_offer_match` picks slot 1 → `0xC5B5` else
`0xC5C5`.

| Off | Meaning |
| ---: | --- |
| +00 | occupancy / phase. `1` just spawned; `0x82` idle (bit7 set → hittable); `3` whip-reaction flash; `0` free |
| +01 / +02 | pixel Y / X |
| +03 | hit latch. `vendor_vs_attack` `inc`s it on whip/proj. `0xFF` = forced leave (`vendor_force_hit`) |
| +04 | offer index B |
| +05 | script slot C (`0..3`) — row of `vendor_transition_tbl` |
| +07 / +08 | `0xE000` pos pointer (leave writes 0 here) |
| +09 | compact-index id (0 or 1), set on first tick |
| +0A | reaction timer (loaded `0x20` = 32 frames) |

`vendors_vs_attack` (`0x80E3`) only tests a slot when +00 bit7 is set
(idle). Leather/chain vs whip, or knife/axe/cross proj. A hit `inc`s +03
and plays `sfx_hit`. During the 32-frame flash +00 is `3`, so a second
whip does not count. Knife-and-up skip the whip test and use projectiles
only (`weapon_id >= equip_knife`).

White cross (`bonus_white_cross`) calls `vendor_force_hit`: every occupied
idle slot gets +03 = `0xFF`. Next idle tick skips the table and dispatches
outcome 6 (leave, +5000).

## Per-slot tick

`vendor_slot_tick` on +00 low nibble:

1. First frame: store compact id in +09, +00 = `0x82`, idle-blit white
   (C70B slot 3). If DE00 counter bit7 is set, `dec` it (post-purchase
   flag).
2. Idle: wait for +03 ≠ 0. Clear +03. If it was `0xFF`, force C70C = 6 /
   C70B = 3. Else `res 7` + `inc` the DE00 whip counter and
   `vendor_pick_outcome`. Then +0A = `0x20`, +00 = 3.
3. Reaction: 32 frames, even/odd frames blit grey (pre-rendered slot 2) vs
   the outcome colour. At 0, idle-blit the outcome colour, +00 = `0x82`,
   `vendor_outcome_dispatch`.

## Whip outcomes (`0xC70C`)

One whip → one dispatch. Mutually exclusive.

| C70C | Handler | Player-facing | Cloak (C70B → `vendor_recolor_tbl`) |
| ---: | --- | --- | --- |
| 0 | `vendor_hit_latch` | open the shop (`0xC40C = FF`, latch id → `0xC703`) | 1 red (`08`) |
| 1 | `vendor_mood_up` | `0xD012++` (cap 3) | 4 blue (`0F`) |
| 2 | `vendor_mood_down` | `0xD012--` (floor 0) | 4 blue (`0F`) |
| 3 | `vendor_give_hearts` | +5 hearts, sfx `0x0F` | 0 magenta (`03`) |
| 4 | `vendor_take_hearts` | −5 hearts, sfx `0x1D` | 0 magenta (`03`) |
| 5 | `vendor_noop` | shrug (`ret`) | 3 white (`0E`) |
| 6 | `vendor_leave` | vanish, sfx `0x10`, **+5000** (`add_score_c0`) | 3 white (`0E`) |

`vendor_state_action_tbl` (`0x9327`): `01 04 04 00 00 03 03` maps C70C
0..6 → C70B. Idle draw always uses slot 3 (white). Flash uses slot 2
(grey `02`) vs that C70B.

Score only moves on leave. Individual whips do not.

### Picking the next outcome

`vendor_pick_outcome` (`0x92C2`):

1. Row = `(ix+5) * 8` into `vendor_transition_tbl` (`0x9307`).
2. Column = DE00 whip counter **before** this hit’s `inc`, clamped to
   `0..7`. After `inc`, `ld a,(hl) / dec a` recovers that value. Hit 1 →
   column 0, … hit 8 → column 7. Further hits stay on column 7.
3. Table byte `0..6` is C70C as-is.
4. Bytes **7 / 8 / 9** are coin-flips on the Z80 **R** refresh register
   (`rra` → CY picks H else L):

   | Table | Flip |
   | ---: | --- |
   | 7 | 3 vs 5 (+5 hearts vs shrug) |
   | 8 | 4 vs 5 (−5 hearts vs shrug) |
   | 9 | 3 vs 4 (+5 vs −5) |

Same whip sequence can therefore differ run to run, but only on those
cells. Everything else is deterministic.

### The four 8-whip scripts

Column 7 is **leave** on every row. Mood (C70C 1 or 2) appears **at most
once**, and only on scripts 1 and 2.

| Whip | Script 0 | Script 1 | Script 2 | Script 3 |
| ---: | --- | --- | --- | --- |
| 1 | shop | shop | 9 (give or steal) | shrug |
| 2 | 7 (hearts or shrug) | **+5** | 9 (give or steal) | shrug |
| 3 | 7 | **+5** | shop | shrug |
| 4 | 7 | **D012++** | shrug | shrug |
| 5 | 8 (steal or shrug) | shrug | shrug | shop |
| 6 | 8 | shrug | shrug | **+5** |
| 7 | shrug | shrug | **D012−−** | shrug |
| 8 | leave | leave | leave | leave |

Script 1 is the “+5 hearts twice, then one difficulty-up” path. Script 2
is two give-or-steal rolls, a shop, then one difficulty-down on whip 7.
Scripts 0 and 3 never touch `0xD012`.

## Difficulty byte `0xD012`

Not vendor-private. It is the global 0..3 **progress / difficulty tier**.
Hub clear (`credits_finish`, seg1 `0x66FC`) also does `min(tier+1, 3)`.
`reset_run_state` (intro, new game) zeros work RAM `0xC405`–`0xDFFF`, so
a fresh run starts at 0. Death respawn and Game Master F5 continue do
**not** clear it. It is not a timer; it lasts the rest of the run unless
a later script-2 whip decrements it or you start over.

**Does not** change shop stock, prices, cloak, Simon damage in or out, or
enemy HP. Contact damage and `weapon_hit_damage` do not read this byte.

Readers (all `ld a,(0d012h)` in `banks_0123.asm`):

| Site | Effect of +1 |
| --- | --- |
| `actor_set_xvel_speedup` (`0xA65A`) | add `tier * 32` to the 16.8 X velocity in the travel direction (~+0.125 px/frame). Callers include zombie, ghost head, axe knight (walk `0x0140`), red skeleton, hanging/placed bat, white skeleton (`0x0240`) |
| `aim_at_simon` / `_spd` (`0xA0EC`) | speed `A + 8*tier` (default base `0x80` → 128, 136, 144, 152). Bone dragon spit, Igor throw, medusa snake, giant bat, etc. Sickle uses base `0x40` |
| `spawn_rate_gate` (`0x9CBE`) | reload delay = `max(0, table − 2*tier) + 1`. Zombie table `0x0C`/`0x12`; merman mostly `0x18`; bat `0x14`/`0x28`; ghost/skull `0x1C`/`0x48`; ghost-head/medusa `0x0C`/`0x18`; roc `0x18` |
| skull pile idle | wait `0x28 − 8*tier` frames (40, 32, 24, 16) |
| merman land | wait `0x30 − 4*tier` frames (48, 44, 40, 36) |

A script-1 whip-4 in the courtyard (`D012 = 0`) is the same bump as
clearing one hub early. At tier 3, `vendor_mood_up` is a no-op.

## Shop (`state_vendor`, main 12)

`vendor_hit_latch` sets `vendor_hit` (`0xC40C`). Play promotes to state
12. `C001` secondary (the `djnz` ladder, B from `ld bc,(0xC000)`):

| C001 | Path | What |
| ---: | --- | --- |
| 0 | `vendor_begin` | clear C40C, `vendor_make_offer`, `main_phase_next` → 1 |
| 1 | fallthrough | `vendor_purchase_tick`; NZ = still open. Z → `main_timer_set 0x0F` (C004 = 15, C001 → 2) |
| 2 | `vendor_hold` | dec C004; at 0, `vendor_offer_dismiss` and `main_state_set` play |

`vendor_make_offer` (`0x938E`): `vendor_set_offer_item` copies DE00 offer id
→ `0xC708`, looks up `vendor_price_tbl`, arms `0xC706 = 0x14` (20), sfx
`0x19`, draws the bubble (`vendor_offer_draw`: HMMM backup, `panel_frame`, HUD glyphs
`vendor_offer_str0` / `_str1`, BCD price, bonus icon).

`vendor_select_price`: `0xC702` bit7 (white bible `0x11`) = halved column,
bit6 (black bible `0x10`) = doubled. Mutually exclusive; each bible collect
clears the other. No bible = normal.

| Item | Id | Normal | White (½) | Black (×2) |
| --- | ---: | ---: | ---: | ---: |
| candle | `0x0E` | 20 | 15 | 60 |
| lockpick | `0x12` | 30 | 20 | 60 |
| red shield | `0x03` | 20 | 10 | 60 |
| yellow shield | `0x04` | 20 | 10 | 80 |
| hourglass | `0x0A` | 40 | 20 | 80 |
| potion | `0x16` | 40 | 15 | 80 |
| holy water | `0x1E` | 30 | 10 | 50 |
| cross | `0x1D` | 20 | 10 | 80 |
| knife | `0x1B` | 50 | 30 | 90 |

Prices are packed BCD (knife `0x50` = 50 hearts).

`vendor_purchase_tick` (`0x94C1`): when `0xC003 & 0x1F == 0` (every 32
frames) dec `0xC706`; at 0, withdraw. Else `vendor_read_buttons`: joystick
TRG1/TRG2 (PSG `0x0E` bits `0x30`) plus keyboard **SPACE** (row 8,
confirm) and **SHIFT** (row 6, refuse), edge via `0xC709`. Confirm and
`hearts >= C707` → `spend_hearts`, `collect_bonus_apply(C708)`, sfx
`0x12`, `res 7` on the DE00 counter. Refuse, can't afford, or timeout →
sfx `0x02` withdraw. Z return ends the purchase phase.

Buying an hourglass from him is not the world-pickup hourglass path (that
list is `0xC500`).

## RAM

| Addr | Meaning |
|------|---------|
| `0xC40C` | `vendor_hit` — play → `state_vendor` |
| `0xC417` | hearts (BCD), compared to price |
| `0xC5B5` / `0xC5C5` | two vendor objects |
| `0xC702` | bible flags (bit7 white ½, bit6 black ×2) |
| `0xC703` | latched compact id |
| `0xC704` / `C705` | bubble origin |
| `0xC706` | offer ticks remaining (20 × 32 frames ≈ 10.7 s at 60 Hz) |
| `0xC707` | price (BCD) |
| `0xC708` | offered bonus id |
| `0xC709` | previous buy/refuse buttons |
| `0xC70B` | which of the five page-1 32×32s to blit (0..4) |
| `0xC70C` | pending whip outcome 0..6 |
| `0xC70D` | spawn scratch (map pos) |
| `0xDE00` | compact `{offer, whip-count}` per room |
| `0xD012` | difficulty tier 0..3 (also hub-advance) |
| `0xE800` | recolor scratch for `vendor_cache_load` |

## SFX

| Id | Name | When |
| ---: | --- | --- |
| `0x02` | `sfx_vendor_withdraw` | refuse / timeout / can't afford |
| `0x0F` | `sfx_heart` | +5 hearts |
| `0x10` | `sfx_money_bag` | leave (+5000) |
| `0x12` | `sfx_collect` | purchase |
| `0x19` | `sfx_vendor_offer` | bubble appears |
| `0x1D` | `sfx_vendor_hearts` | −5 hearts |

## Labels

`vendor_tick`, `vendor_spawn`, `vendor_draw` / `vendor_draw_idle` /
`vendor_redraw_all`, `vendor_force_hit`, `vendor_pick_outcome`,
`vendor_outcome_dispatch`, `vendor_transition_tbl`,
`vendor_state_action_tbl`, `vendor_make_offer`, `vendor_set_offer_item`,
`vendor_select_price`, `vendor_price_tbl`, `vendor_purchase_tick`,
`vendor_read_buttons`, `vendor_offer_id`, `vendor_de00_slot`,
`vendor_cache_load`, `vendor_recolor_tbl`, `vendor_tile_ptr`.
`state_vendor` / `main_vendor` in `segments/state.inc`.
