// node tools/run_game.mjs "60:0 120:L 20:B" : the remake in the test emulator -> out/game_<n>.png and a state line
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot } from './boot.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const s = new Snes(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc')), { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const B = { B: 0x8000, Y: 0x4000, S: 0x1000, T: 0x2000, U: 0x0800, D: 0x0400, L: 0x0200, R: 0x0100, A: 0x0080, X: 0x0040 };
const steps = (process.argv[2] || '60:0').split(/\s+/).map((t) => { const [n, p] = t.split(':'); return { n: +n, pad: [...(p || '0')].reduce((a, c) => a | (B[c] || 0), 0) }; });
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
let t0 = 0, worst = 0, sum = 0, cnt = 0;
s.breaks.set(sy.MainLoop, (c) => { t0 = c.cyc; });
s.breaks.set(sy.WaitVbl, (c) => { const d = c.cyc - t0; if (d > 0) { worst = Math.max(worst, d); sum += d; cnt++; } });
let shot = 0;
if (!process.argv.includes('--splash')) boot(s, sy);
for (const st of steps) {
  s.pad = st.pad;
  for (let i = 0; i < st.n; i++) s.runFrame(60000);
  const ppm = path.join(root, 'out', `game_${shot}.ppm`);
  s.savePPM(ppm);
  execFileSync('python', ['-c', `from PIL import Image; Image.open(r'${ppm}').resize((768,672),Image.NEAREST).save(r'${ppm.replace('.ppm', '.png')}')`]);
  fs.unlinkSync(ppm);
  const arr = (n) => Array.from({ length: 9 }, (_, i) => w(sy[n] + i * 2)).join(',');
  console.log(`shot ${shot++}: frame ${s.frame} pc ${s.PB.toString(16)}:${s.PC.toString(16)} hero (${w(sy.ex) >> 4},${w(sy.ey) >> 4}) cam (${w(sy.camx)},${w(sy.camy)}) st ${arr('est')} hp ${arr('ehp')}`);
}
console.log(`logic cycles per frame (estimate): avg ${Math.round(sum / Math.max(1, cnt))}, worst ${worst}`);
