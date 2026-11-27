# Anaroch SNES

Anaroch on the Super Nintendo: the graveyard of Act I, with the mechanics of the N64 sprite version
(`../Anaroch_N64_Sprite`), the engine's graveyard layout, and the N64 game's own pre-rendered characters.
Nothing comes from the NES version.

`out/anaroch.sfc`: a 256 KB LoROM cartridge (65816, Mode 1).

## Controls
D-pad: walk (8 directions). B or Y: sword (press again late in a swing to chain the next).
A: pick up the potion or Tome you stand by (gold is picked up by walking over it).
X: drink from the chosen belt slot. L / R: choose a belt slot.
Select: the character window (spend stat points on life, strength or defense with Up / Down and A).
Start: pause; after death, rise again.

## What comes from where
- **Characters**: `Anaroch_N64_Sprite/assets/spr_hero|ghoul|skel_<anim>_<dir>.png` and their cell tables in
  `src/spr_*.h`: 8 directions; per direction 2 idle, 4 walk, 4 attack, 1 recoil and 4 death pictures, scaled to
  32x32 and reduced to 15 colours each (blue champion, red "struck" and white "hit" palettes are made from them).
- **The graveyard**: `Anaroch_N64_Sprite/src/area_graveyard.h` (the engine's layout as the N64 has it): the
  72x72 collision grid (0 free, 1 low, 2 tall), the braziers, the 64 spawn points and the start. 1 m = 16 px.
  The ground tiles are drawn by `tools/build_assets.py` (grass, paths, walls, dead trees, graves, crosses, rocks,
  bones, braziers, the crypt door).
- **HUD**: the N64's life vial (`assets/hud_vial_*.png`) and potion icon (`assets/icons/i120.png`), the belt of four.
- **Mechanics** (`src/main.c`, `src/items.c` of the N64 version):
  - the hero: level 1, 10 in every stat, Wooden Sword (6-11, +3 STR) and Wooden Armor (+5 life, +4 DEF); 3.6 m/s;
    the swing lasts 0.75 s, lands at 0.44 of it, reach 1.8 m + 0.3 in front; chain after 0.92, cancel into walking
    after 0.8; hitstop 0.05 s (0.09 on a crit); 0.25 s recoil when struck unless swinging; 0.5 % life a second
  - damage as `calc_damage`: attack roll minus a defense roll, then `x (1 - def / (def + 80))`, 5 % crits x1.6;
    knockback 0.25 m (0.45 on a crit)
  - monsters: 4 in the graveyard (3 + lvl1 / 3), every third a skeleton archer; levels 1-3, stats from the SP
    table and the Zombie's shares; 8 % champions (blue, x3 life, x1.3 strength)
  - their senses: they wander near home until they see the hero (9 m in a wide cone, 3 m any way round, nothing
    tall in between), call the others within 6 m once a second, forget him after 4 s beyond 16 m; struck, they know
  - ghouls: 1.5 m/s, strike at 1.15 m, the blow lands at 0.42 s if within 1.6 m and in front, 0.8-1.6 s cooldown
  - the archer: shoots whenever it has a line and is within 11 m, keeps 4.5 to 9 m away; arrows at 2.75 m/s,
    14 m, stopped by anything in the grid
  - bodies lie 3.5 s, another rises 6 s later 9 to 24 m from the hero
  - rewards: experience 8 + 4 per level (x3 champion, 20 % less per level below the hero's), levels at
    100 x L^1.5 (two stat points each, a level up heals); gold 15 % (60 % champion), a healing potion 5 %,
    a Tome of Insight 1 % (10 % champion); potions heal 45 %
  - death: "YOU HAVE DIED", START to rise again (here at the graveyard's start; there is no town yet)

## Not here yet
The town and the other places and acts, gates between them, the mercenary, skills and stamina, gear and the bag,
quests, waypoints, saves, the title, weather, and sound (the SPC700 needs its own driver and samples).

## Dual-chip experiment (SuperFX 2 + SPC7110)
No real cartridge ever carried both, so it runs on a custom board in a copy of ares: `ares_dual/` (a copy of
`Anaroch_N64_SDK/ares/ares-v148` with one board, `ANAROCH-DUAL`, added to its `Database/Super Famicom Boards.bml`).
ares loads each chip on its own from the board file, so nothing was rebuilt. (`../ares_dualchip` holds the v148
source, used to read how boards load.) The board entry itself is in `docs/ANAROCH-DUAL.board.bml`.

    node tools/build_dual.mjs     # out/anaroch_dual.sfc (512 KB program + 1 MB data ROM) and out/anaroch_dual.bml
    ares_dual/ares.exe --system "Super Famicom" --no-file-prompt out/anaroch_dual.sfc

Memory map: SuperFX registers $3000-34FF, its RAM $70-71, program ROM $00-3F:8000; SPC7110 registers $4800-483F
and ports $50/$58, its program + data ROM at $C0-FF (data ROM banks via $4831-4833).
So far `src/dual_test.asm` proves both chips work together: the SPC7110 data port and $D0 bank read the data ROM,
and a GSU program runs from SuperFX RAM while the CPU keeps going. The game itself is not on this board yet.
The Mode 7 camera was dropped (its code is still in `src/main.asm` under `.if MODE7`, no longer built).

## Chip test (SuperFX 2 + SPC7110 + sound)
`out/anaroch_chiptest.sfc` runs everything at once on the dual-chip board. Measured in `ares_dual` over about
74 seconds (4419 frames): no dropped frames; the SPC7110 unpacked a 28 KB picture at boot with no wrong byte and
kept unpacking and checking it while running (78 passes, none bad); the SuperFX drew six scaled characters from
cartridge ROM into a 128x128 window about 25 times a second while the CPU ran from WRAM; the music played.

    python tools/build_assets.py && python tools/build_chip_assets.py
    node tools/build_audio.mjs && node tools/build_chip.mjs
    ares_dual/ares.exe --system "Super Famicom" --no-file-prompt out/anaroch_chiptest.sfc

- `tools/spc7110.mjs`: packs graphics for the SPC7110's decompressor (and unpacks, to check).
- `tools/gsuasm.mjs`, `src/gsu_test.s`: a SuperFX assembler and the scaling program.
- `src/chip_test.asm`: the test itself.

## Sound
`src/spc_driver.s` is the sound chip's driver (an event stream: keys, volumes, DSP writes, loop);
`tools/build_audio.mjs` synthesises every instrument, writes the graveyard track "Ashes Under the Yew" (original,
about 61 s, looping), and renders a preview to `out/audio/song_preview.wav` with the small player in
`tools/spc700.mjs` (an approximation; ares is the reference). About 15 KB of the sound chip's 64 KB are used,
plus 16 KB of echo. No sound effects yet, and the game itself does not play it yet.

## The remake: step 0
The plan and the results are in `docs/REMAKE_PLAN.md`.

    node tools/build_step0.mjs && node tools/test_step0.mjs   # code from the SPC7110 window while the SuperFX works
    node tools/test_chips.mjs                                  # the chip test in the test emulator (tools/chips.mjs)
    node tools/make_area_unlit.mjs                             # the N64 graveyard without baked light
    node tools/render_area.mjs gymoon t1 --from=out/step0/graveyard_unlit.glb --flat --moon --exposure=1.9
    python tools/tile_budget.py gymoon_t1_flat_all --exact     # tiles and palettes against the SNES's limits
    python tools/mockup.py                                     # the new look, as a picture

## The skeleton
`node tools/make_skeleton.mjs` builds an anatomical skeleton on the hero rig and renders it with a patched copy of the
N64 sprite renderer (the N64 project is only read) into `out/skel_src/`; the ribcage is drawn in one-pixel rows at
SNES size. The archer uses these sheets, and the remains between the graves are the same model fallen.

## Build
Needs Node.js and Python 3 with Pillow.

    node tools/make_skeleton.mjs      # once: the skeleton's sheets
    python tools/build_assets.py      # out/*.bin + src/data.inc from the N64 version's files
    node tools/build.mjs              # out/anaroch.sfc

`tools/asm816.mjs` is a small 65816 assembler written for this (ca65-like syntax, LoROM output; it stops on a
branch out of range or on code running into data).

## Test
`tools/snes.mjs` is a minimal headless SNES (65816 core, DMA, the PPU registers the game uses, Mode 1 BG1/BG2 and
sprites; not cycle-accurate):

    node tools/run.mjs "60:0 120:L 20:B"   # frames:buttons steps (U D L R B Y A X S=start T=select) -> out/shot_<n>.png
    node tools/autoplay.mjs 12000 2000     # a bot plays: fights, loots, drinks; log + out/auto_<n>.png
    node tools/prof.mjs 120 512            # estimated CPU cycles per routine

Real emulators: ares (Super Famicom) is in `../Anaroch_N64_SDK/ares/ares-v148`; bsnes, Snes9x or Mesen also run it.
