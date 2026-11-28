// Saved games in the built ROM (the test emulator): saving from the pause menu into the three slots, loading, the
// screen at power on, and slots that are empty or damaged.  node tools/test_saves.mjs [--shots]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot, travel } from './boot.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const rom = fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc'));
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const SHOTS = process.argv.includes('--shots');
const ITEMS = 0x2000, SLOT = 0x2000, PARTS = 51 * 64;
let s;
const power = (sram) => { s = new Snes(rom, { program: 0x200000 }); if (sram) s.sfx.ram.set(sram); boot(s, sy); frames(4); };
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const pw = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
const V = (n, i = 0) => w(sy[n] + i * 2);
const set = (n, v, i = 0) => pw(sy[n] + i * 2, v);
let fails = 0;
const check = (ok, what) => { if (!ok) { fails++; console.log('  FAIL', what); } };
const frames = (n, pad = 0) => { for (let i = 0; i < n; i++) { s.pad = pad; s.runFrame(400000); } };
const press = (pad) => { frames(3, pad); frames(8); };
const A = 0x0080, B = 0x8000, START = 0x1000, UP = 0x0800, DOWN = 0x0400;
const text = (row) => { let t = ''; for (let c = 0; c < 32; c++) { const e = w(sy.hudmap + (row * 32 + c) * 2) & 0x3FF; t += e >= sy.FONT_BASE && e < sy.FONT_BASE + 50 ? " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/:+-.()>'!%,?"[e - sy.FONT_BASE] : ' '; } return t.trim().replace(/ +/g, ' '); };
const shot = (name) => {
  if (!SHOTS) return;
  const ppm = path.join(root, 'out', `save_${name}.ppm`); s.savePPM(ppm);
  execFileSync('python', ['-c', `from PIL import Image; Image.open(r'${ppm}').resize((768,672),Image.NEAREST).save(r'${ppm.replace('.ppm', '.png')}')`]);
  fs.unlinkSync(ppm);
};
const keys = Object.keys(sy);
check(keys.includes('SaveSlot'), 'the symbols');
const WORDS = ['level', 'gold', 'xp', 'xph', 'strb', 'defb', 'lifeb', 'sDex', 'sEne', 'points', 'skillPts', 'heroFlags', 'kills', 'beltsel', 'skActive'];
const DERIVED = ['emaxhp', 'maxStam', 'atkmin', 'atkmax', 'hdef', 'hstr', 'critPm', 'blockPm', 'spellPm'];
const hero = () => ({
  words: WORDS.map((n) => V(n)), ranks: [...Array(36).keys()].map((i) => V('skRank', i)),
  items: Buffer.from(s.wram.slice(ITEMS, ITEMS + PARTS)).toString('hex'), derived: DERIVED.map((n) => V(n)),
});
const same = (a, b, what) => { for (const k of Object.keys(a)) check(JSON.stringify(a[k]) === JSON.stringify(b[k]), `${what}: ${k} differ ${k === 'items' ? '' : JSON.stringify([a[k], b[k]])}`); };
// a hero worth keeping: numbers, skills, and every place of the bag, the worn slots and the belt filled from play
function grow(seed) {
  const n = { level: 9 + seed, gold: 1234 * (seed + 1), xp: 4321 + seed, xph: seed, strb: 22, defb: 17, lifeb: 19 + seed, sDex: 14, sEne: 13, points: 3, skillPts: 2, heroFlags: 1, kills: 77, beltsel: 2, skActive: 0 };
  for (const [k, v] of Object.entries(n)) set(k, v);
  for (let i = 0; i < 36; i++) set('skRank', (i * 7 + seed) % 6, i);
  for (let i = 0; i < PARTS; i += 64) if ((i / 64 + seed) % 3 === 0) { s.wram.copyWithin(ITEMS + i, ITEMS + 47 * 64, ITEMS + 48 * 64); }
}

power();
check(V('mode') === 0, `no screen at power on without a saved game (mode ${V('mode')})`);
travel(s, sy, 2);                                   // (a house: loading must come back to the town)
grow(0);
press(START);
check(V('mode') === 4 && V('bagPage') === 3 && text(4) === 'PAUSED', `the pause menu: ${text(4)}`); shot('pause');
check(text(8) === '> RESUME' && text(11) === 'SAVE GAME' && text(14) === 'LOAD GAME', `its lines: ${[8, 11, 14].map(text)}`);
press(DOWN); press(A);
check(text(4) === 'SAVE THE GAME' && text(8) === '> SLOT 1 EMPTY', `the slots: ${text(4)} / ${text(8)}`);
// the numbers the game works out, as they are for this hero (loading must arrive at the same)
const call = (name) => { const keep = ['PB', 'PC', 'P', 'E', 'D', 'DB', 'S', 'A', 'X', 'Y']; const old = Object.fromEntries(keep.map((k) => [k, s[k]])); const stack = s.wram.slice(0x1f80, 0x2000);
  s.PB = 0xAA; s.PC = sy[name] & 0xFFFF; s.P = 0x04; s.E = 0; s.D = 0; s.DB = 0x80; s.S = 0x1fef; s.push16(0xfff0 - 1); let n = 0; while (s.PC !== 0xfff0) { s.step(); if (++n > 3e6) throw new Error(name); } for (const k of keep) s[k] = old[k]; s.wram.set(stack, 0x1f80); };
call('StatsRecalc');
const first = hero();
press(A); check(text(26) === 'SAVED', `saved: ${text(26)}`); shot('saved');
check(text(8) === `> SLOT 1 LEVEL 9 GOLD 1234`, `slot 1 reads: ${text(8)}`);
const ram = s.sfx.ram;
const word = (a) => ram[a] | (ram[a + 1] << 8);
const BYTES = 17 * 2 + 72 + PARTS;
const sum = (slot) => { let q = 0xA5A5; for (let i = 0; i < BYTES; i += 2) q = (q * 31 + word(slot * SLOT + 6 + i)) & 0xFFFF; return q; };
check(word(0) === 0x4741 && word(2) === 1 && word(4) === sum(0), 'the slot in battery memory: mark, version, checksum');
// another hero into slot 2, then replaced: the second press asks first
press(B); check(text(4) === 'PAUSED', 'back to the pause menu'); press(B); check(V('mode') === 0, 'and to the game');
grow(1); call('StatsRecalc');
press(START); press(DOWN); press(A); press(DOWN); press(A);
check(word(SLOT) === 0x4741 && word(SLOT + 6) === 10, 'slot 2 written');
grow(2); set('level', 99); set('gold', 65535); call('StatsRecalc'); const third = hero();
press(A); check(text(26) === 'A AGAIN TO REPLACE IT' && word(SLOT + 6) === 10, `asked first: ${text(26)}`); shot('replace');
press(A); check(word(SLOT + 6) === 99 && text(26) === 'SAVED', 'then replaced');
check(word(0) === 0x4741 && word(6) === 9 && word(4) === sum(0), 'slot 1 untouched');
press(B); press(B);
// loading slot 1 after everything has changed
for (const n of WORDS) set(n, 1);
for (let i = 0; i < 36; i++) set('skRank', 0, i);
s.wram.fill(0, ITEMS, ITEMS + PARTS);
press(START); press(DOWN); press(DOWN); press(A);
check(text(4) === 'LOAD A GAME', `the load screen: ${text(4)}`); shot('load');
press(DOWN); press(DOWN); press(A); check(V('mode') === 4, 'an empty slot does not load');
press(UP); press(UP); press(A); frames(20);
check(V('mode') === 0 && V('placeId') === 1, `loaded into the town: mode ${V('mode')}, place ${V('placeId')}`); shot('loaded');
same(first, hero(), 'slot 1 loaded');
check(V('ehp') === V('emaxhp') && V('stam') === V('maxStam'), 'whole and rested');
console.log('saved and loaded');

// ---------------------------------------------------------------- power off and on
const kept = Uint8Array.from(s.sfx.ram);
power(kept);
check(V('mode') === 4 && V('bagPage') === 3 && text(4) === 'ANAROCH', `at power on: ${text(4)}`); shot('start');
check(text(8) === '> SLOT 1 LEVEL 9 GOLD 1234' && text(11) === 'SLOT 2 LEVEL 99 GOLD 65535' && text(17) === 'NEW GAME', `its lines: ${[8, 11, 14, 17].map(text)}`);
press(B); press(START); check(V('mode') === 4, 'one must choose');
press(DOWN); press(A); frames(20);
check(V('mode') === 0 && V('placeId') === 1, 'slot 2 at power on'); same(third, hero(), 'slot 2 loaded');
power(kept);
for (let i = 0; i < 3; i++) press(DOWN); press(A); frames(20);
check(V('mode') === 0 && V('level') === 1 && V('gold') === 0, `a new game: level ${V('level')}, gold ${V('gold')}`);
check(Buffer.from(s.sfx.ram).equals(Buffer.from(kept)), 'a new game leaves the saved ones');
// a save in the third slot only: the cursor starts on it
press(START); press(DOWN); press(A); press(DOWN); press(DOWN); press(A);
const only = Uint8Array.from(s.sfx.ram); only.fill(0, 0, 2 * SLOT);
power(only); check(text(14) === '> SLOT 3 LEVEL 1 GOLD 0', `the cursor on the saved game: ${text(14)}`);
// ---------------------------------------------------------------- damaged and empty memory
const bad = Uint8Array.from(kept); bad[100] ^= 1;
power(bad); check(text(8) === 'SLOT 1 EMPTY' && text(11).startsWith('> SLOT 2 LEVEL 99'), `one damaged: ${text(8)} / ${text(11)}`);
bad[SLOT + 3000] ^= 0x80;
power(bad); check(V('mode') === 0, 'all damaged: straight into a new game');
power(new Uint8Array(0x20000).fill(0xFF)); check(V('mode') === 0, 'fresh battery memory');
console.log(fails ? `${fails} checks FAILED` : 'all save checks pass');
process.exit(fails ? 1 : 0);
