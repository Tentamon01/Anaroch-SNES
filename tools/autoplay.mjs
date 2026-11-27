// A bot plays the ROM headless: walks to the nearest monster, swings, picks up loot, drinks when low.
// node tools/autoplay.mjs [frames] [shotEvery]  -> prints a log, writes out/auto_<n>.png
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const s = new Snes(fs.readFileSync(path.join(root, 'out', 'anaroch.sfc')));
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch.sym.json'), 'utf8'));
const N = +(process.argv[2] || 3600), EVERY = +(process.argv[3] || 600);
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const sw = (a) => { const v = w(a); return v > 32767 ? v - 65536 : v; };
const B = { B: 0x8000, S: 0x1000, U: 0x0800, D: 0x0400, L: 0x0200, R: 0x0100, A: 0x0080, X: 0x0040 };
let shot = 0, swing = 0, deaths = 0, maxArrows = 0, levels = 1, lastKills = 0, pickups = 0, lastGold = 0, potionsUsed = 0;
let tStart = 0, worst = 0, sum = 0, cnt = 0;
s.breaks.set(sy.MainLoop, (c) => { tStart = c.cyc; });
s.breaks.set(sy.WaitVbl, (c) => { const d = c.cyc - tStart; worst = Math.max(worst, d); sum += d; cnt++; });
for (let f = 0; f < N; f++) {
  const hx = w(sy.ex) >> 4, hy = w(sy.ey) >> 4, mode = w(sy.mode), hp = w(sy.ehp), mhp = w(sy.emaxhp);
  let pad = 0;
  if (mode === 1) { if (f % 20 === 0) pad = B.S; if (w(sy.modet) === 1) deaths++; }
  else {
    // loot first, then the nearest live monster
    let tx = null, ty = null, loot = false;
    for (let i = 0; i < 8; i++) if (w(sy.dtyp + i * 2)) { tx = w(sy.dpx + i * 2); ty = w(sy.dpy + i * 2); loot = true; break; }
    if (!loot) {
      let best = 1e9;
      for (let i = 1; i < 5; i++) {
        if (w(sy.est + i * 2) >= 4) continue;
        const mx = w(sy.ex + i * 2) >> 4, my = w(sy.ey + i * 2) >> 4, d = Math.hypot(mx - hx, my - hy);
        if (d < best) { best = d; tx = mx; ty = my; }
      }
    }
    if (tx !== null) {
      const dx = tx - hx, dy = ty - hy, d = Math.hypot(dx, dy);
      if (loot ? d > 8 : d > 22) {
        if (dx > 3) pad |= B.R; if (dx < -3) pad |= B.L; if (dy > 3) pad |= B.D; if (dy < -3) pad |= B.U;
        if (f % 90 < 20 && (f / 90 | 0) % 2) pad ^= (pad & (B.L | B.R)) ? B.U : B.L;   // wiggle round graves now and then
      } else if (loot) { if (f % 8 === 0) pad |= B.A; }
      else {
        if (dx > 6) pad |= B.R; if (dx < -6) pad |= B.L; if (dy > 6) pad |= B.D; if (dy < -6) pad |= B.U;
        if ((swing++ & 7) === 0) pad |= B.B;
      }
    }
    if (hp * 3 < mhp && f % 30 === 0) { pad |= B.X; }
  }
  s.pad = pad;
  const beltBefore = [0, 2, 4, 6].map((o) => w(sy.belt + o)).join('');
  s.runFrame();
  const beltAfter = [0, 2, 4, 6].map((o) => w(sy.belt + o)).join('');
  if (beltAfter !== beltBefore) { if (beltAfter.split('1').length > beltBefore.split('1').length) pickups++; else potionsUsed++; }
  let arrows = 0; for (let i = 0; i < 6; i++) if (w(sy.alife + i * 2)) arrows++;
  maxArrows = Math.max(maxArrows, arrows);
  if (w(sy.level) > levels) { levels = w(sy.level); console.log(`frame ${f}: LEVEL ${levels} (life ${w(sy.emaxhp)})`); }
  if (w(sy.kills) !== lastKills) { lastKills = w(sy.kills); }
  if (w(sy.gold) !== lastGold) { console.log(`frame ${f}: gold ${lastGold} -> ${w(sy.gold)}`); lastGold = w(sy.gold); }
  if (s.halted) { console.log('CPU halted at', s.PC.toString(16)); break; }
  if (f % EVERY === EVERY - 1) {
    const ppm = path.join(root, 'out', `auto_${shot}.ppm`); s.savePPM(ppm);
    execFileSync('python', ['-c', `from PIL import Image; Image.open(r'${ppm}').resize((512,448),Image.NEAREST).save(r'${ppm.replace('.ppm', '.png')}')`]);
    console.log(`frame ${f}: shot ${shot++} hero (${hx},${hy}) life ${hp}/${mhp} lvl ${w(sy.level)} xp ${w(sy.xp)} kills ${w(sy.kills)} gold ${w(sy.gold)} mons ${[1, 2, 3, 4].map((i) => `${w(sy.est + i * 2)}:${w(sy.ehp + i * 2)}${w(sy.echamp + i * 2) ? 'C' : ''}`).join(' ')}`);
  }
}
console.log(`deaths ${deaths}, kills ${w(sy.kills)}, level ${w(sy.level)}, gold ${w(sy.gold)}, belt pickups ${pickups}, potions drunk ${potionsUsed}, most arrows in flight ${maxArrows}`);
console.log(`logic cycles per frame (emulator estimate): avg ${Math.round(sum / Math.max(1, cnt))}, worst ${worst}`);
