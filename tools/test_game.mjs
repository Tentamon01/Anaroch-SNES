// Plays at random for thousands of frames (walking, fighting, picking up, deaths, the bag, the character window, the
// town, its houses and the trade screen), and checks every shown tile against the place's data, every few frames.
// node tools/test_game.mjs [frames]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot, travel } from './boot.mjs';
import { world } from './worldcheck.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const rom = fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc'));
const s = new Snes(rom, { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
let seed = 5; const rnd = (n) => (seed = (seed * 16807) % 2147483647) % n;
const pw0 = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
const PADS = [0x0800, 0x0400, 0x0200, 0x0100, 0x0A00, 0x0900, 0x0600, 0x0500];
let casts = 0, sparksMost = 0, textBad = 0, opened = 0, bagFrames = 0, winFrames = 0, most = 0, checked = 0, bad = 0, firstBad = null, deaths = 0, pad = 0, worstQ = 0;
s.breaks.set(sy.FlushQueue, () => { worstQ = Math.max(worstQ, w(sy.sq) / sy.QREC); });
const N = +(process.argv[2] || 3000);
boot(s, sy);
travel(s, sy, 0);
const W = world(s, sy, rom);
const visits = [0, 0, 0, 0, 0];
for (let f = 0; f < N; f++) {
  if (f % 90 === 0) pad = PADS[rnd(8)];
  s.pad = pad | (f % 23 < 3 ? 0x8000 : 0);
  // now and then through a gate: three parts of the time in the graveyard, the rest in the town and its houses
  if (f % 400 === 399 && w(sy.mode) === 0) {
    const at = w(sy.placeId);
    travel(s, sy, at === 0 ? 1 : at === 1 ? [0, 0, 2, 3, 4][rnd(5)] : 1); visits[w(sy.placeId)]++;
    if (w(sy.placeId) === 0 && rnd(2)) pw0(sy.gold, 500);
  }
  if (w(sy.mode) === 1) { s.pad = f % 20 < 4 ? 0x1000 : 0; }
  const pw = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
  if (f % 150 === 20 && w(sy.mode) === 0 && !w(sy.safeArea)) {          // a weakened monster in front of the hero: kills, so pieces drop
    const m = 1 + rnd(8);
    if (w(sy.est + m * 2) < 4) { pw(sy.ex + m * 2, w(sy.ex)); pw(sy.ey + m * 2, w(sy.ey) + 200); pw(sy.ehp + m * 2, 1); pw(sy.echamp + m * 2, rnd(2)); pw(sy.edir, 0); }
  }
  if (f % 7 === 0 && w(sy.mode) === 0) s.pad |= 0x0080;                  // A: pick up
  if (f % 601 === 300 && w(sy.mode) === 0) s.pad = 0x2000;               // Select: the bag
  if (w(sy.mode) === 4) {                                                // in the bag: buttons at random, then close
    const keys = [0x0800, 0x0400, 0x0200, 0x0100, 0x0200, 0x0080, 0x0040, 0x4000, 0x0020, 0x0010, 0];
    s.pad = f % 4 === 0 ? keys[rnd(11)] : 0; if (f % 601 > 450 && f % 8 < 2) s.pad = 0x8000; bagFrames++;
  }
  if (w(sy.mode) === 3) { const keys = [0x0800, 0x0400, 0x0080, 0x0020, 0x8000, 0]; s.pad = f % 6 === 0 ? keys[rnd(6)] : 0; winFrames++; }
  // skills: every one known, stamina kept up, a random one on the button now and then and cast
  if (w(sy.mode) === 0) {
    if (f % 240 === 0) { for (let k = 0; k < 36; k++) pw(sy.skRank + k * 2, 1 + rnd(5)); const act = [0, 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 23, 35]; pw(sy.skActive, act[rnd(act.length)]); pw(sy.stam, w(sy.maxStam)); }
    if (f % 37 === 5) { s.pad = pad | 0x4000; casts++; }
    if (f % 311 === 100) s.pad = 0x0010;
  }
  let sparkN = 0; for (let k = 0; k < 16; k++) if (w(sy.fxl + k * 2)) sparkN++; sparksMost = Math.max(sparksMost, sparkN);
  const m0 = w(sy.mode);
  s.runFrame(60000);
  if (m0 !== 1 && w(sy.mode) === 1) deaths++;
  if (m0 === 0 && w(sy.mode) === 4) opened++;
  let pieces = 0; for (let p = 0; p < 40; p++) if (w(0x2000 + p * 64)) pieces++; most = Math.max(most, pieces);
  // the text layer in video memory is what the game's own copy says (nothing left over from other screens)
  if (f % 50 === 49 && !w(sy.inMenu) && !w(sy.rebuild) && (s.reg[0x420C] & 0x80)) {
    let pending = false; for (let r = 0; r < 32; r++) if (s.wram[sy.hudd + r]) pending = true;
    if (!pending) for (let i = 0; i < 2048; i++) if (s.vram[0x9000 + i] !== s.wram[sy.hudmap + i]) { textBad++; break; }
  }
  if (f % 5 !== 4) continue;
  const t = W.tiles();
  checked += t.checked; bad += t.bad; firstBad ||= t.first && { f, place: w(sy.placeId), ...t.first };
}
console.log(`places entered: graveyard ${visits[0]}, town ${visits[1]}, houses ${visits[2] + visits[3] + visits[4]}`);
console.log(`text layer checked: ${textBad} times unlike the game's copy`);
if (textBad || bad) process.exitCode = 1;
console.log(`skill button pressed ${casts} times; most sparks at once ${sparksMost}`);
console.log(`bag opened ${opened} times (${bagFrames} frames, character window ${winFrames}); most pieces carried ${most}; level ${w(sy.level)}; gold ${w(sy.gold)}`);
console.log(`checked ${checked} shown tiles over ${N} frames: ${bad} wrong; deaths ${deaths}; most stream records in a frame ${worstQ}; slowdowns ${w(sy.lagc)}; kills ${w(sy.kills)}`);
if (firstBad) console.log('first wrong', firstBad);
process.exit(bad || textBad ? 1 : 0);
