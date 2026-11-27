// Moves the hero at random (and through deaths) for thousands of frames and checks every shown tile against the world
// data, every few frames. node tools/test_game.mjs [frames]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const rom = fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc'));
const s = new Snes(rom, { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const rd = (bank, addr) => rom[bank * 0x8000 + (addr & 0x7FFF)];
const { MAP_W, MAP_H, TILE_BANK } = sy;
const cell = (c, r) => {
  if (c >= MAP_W || r >= MAP_H) return 0;
  const p = sy.rowptr + r * 3, lo = rd(p >> 16, p) | (rd(p >> 16, p + 1) << 8), bank = rd(p >> 16, p + 2), a = lo + c * 2;
  return rd(bank, a) | (rd(bank, a + 1) << 8);
};
let seed = 5; const rnd = (n) => (seed = (seed * 16807) % 2147483647) % n;
const PADS = [0x0800, 0x0400, 0x0200, 0x0100, 0x0A00, 0x0900, 0x0600, 0x0500];
let checked = 0, bad = 0, firstBad = null, deaths = 0, pad = 0, worstQ = 0;
s.breaks.set(sy.FlushQueue, () => { worstQ = Math.max(worstQ, w(sy.sq) / sy.QREC); });
const N = +(process.argv[2] || 3000);
for (let f = 0; f < N; f++) {
  if (f % 90 === 0) pad = PADS[rnd(8)];
  s.pad = pad | (f % 23 < 3 ? 0x8000 : 0);
  if (w(sy.mode) === 1) { s.pad = f % 20 < 4 ? 0x1000 : 0; }
  const m0 = w(sy.mode);
  s.runFrame(60000);
  if (m0 !== 1 && w(sy.mode) === 1) deaths++;
  if (f % 5 !== 4 || w(sy.sq) || !(s.reg[0x420C] & 0x80)) continue;
  const camx = w(sy.camx), camy = w(sy.camy);
  // (the camera in the variables may be a frame ahead of what has been sent: check what the scroll registers show)
  const hx = s.scroll.h & 0x3FF, vy = s.scroll.v & 0x3FF;
  if ((camx & 0x3FF) !== hx || (camy & 0x3FF) !== vy) continue;
  for (let r = (camy + 9) >> 3; r <= (camy + 216) >> 3; r++) for (let c = camx >> 3; c <= (camx + 255) >> 3; c++) {
    const mapAt = (0x4000 + ((r & 31) * 32) + (c & 31) + (c & 32 ? 0x400 : 0)) * 2;
    const e = s.vram[mapAt] | (s.vram[mapAt + 1] << 8), slot = e & 0x3FF, pal = (e >> 10) & 7;
    const word = cell(c, r), id = word & 0x1FFF, want = id ? (word >> 13) + 2 : -1;
    let ok = id === 0 || pal === want;
    if (ok) for (let i = 0; i < 32; i++) { const b = rd(TILE_BANK + (id >> 10), 0x8000 + (id & 1023) * 32 + i); if (s.vram[slot * 32 + i] !== b) { ok = false; break; } }
    checked++;
    if (!ok) { bad++; if (!firstBad) firstBad = { f, c, r, slot, pal, want, id, camx, camy }; }
  }
}
console.log(`checked ${checked} shown tiles over ${N} frames: ${bad} wrong; deaths ${deaths}; most stream records in a frame ${worstQ}; slowdowns ${w(sy.lagc)}; kills ${w(sy.kills)}`);
if (firstBad) console.log('first wrong', firstBad);
process.exit(bad ? 1 : 0);
