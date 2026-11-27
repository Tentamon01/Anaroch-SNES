// Headless test run: node tools/run.mjs [script]  — script is a list of "frames:pad" steps, e.g. "60:0 120:L 30:B"
// Pad letters: U D L R B Y A X S(start). Writes out/shot_<n>.ppm at each step end, prints RAM state and timing.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const rom = fs.readFileSync(path.join(root, 'out', (process.env.ROM || 'anaroch') + '.sfc'));
const syms = JSON.parse(fs.readFileSync(path.join(root, 'out', (process.env.ROM || 'anaroch') + '.sym.json'), 'utf8'));
const s = new Snes(rom);
const BITS = { B: 0x8000, Y: 0x4000, S: 0x1000, U: 0x0800, D: 0x0400, L: 0x0200, R: 0x0100, A: 0x0080, X: 0x0040, T: 0x2000 };
const steps = (process.argv[2] || '90:0').split(/\s+/).map((t) => { const [n, p] = t.split(':'); return { n: +n, pad: [...(p || '0')].reduce((a, c) => a | (BITS[c] || 0), 0) }; });

// timing: cycles from MainLoop until WaitVbl starts spinning
let tStart = 0, worst = 0, sum = 0, cnt = 0;
s.breaks.set(syms.MainLoop, (c) => { tStart = c.cyc; });
s.breaks.set(syms.WaitVbl, (c) => { const d = c.cyc - tStart; worst = Math.max(worst, d); sum += d; cnt++; });
const w16 = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const arr = (name) => Array.from({ length: 5 }, (_, i) => { const v = w16(syms[name] + i * 2); return v > 32767 ? v - 65536 : v; });
let shot = 0;
for (const st of steps) {
  s.pad = st.pad;
  for (let i = 0; i < st.n; i++) s.runFrame();
  const f = path.join(root, 'out', `shot_${shot++}.ppm`);
  s.savePPM(f);
  try { const { execFileSync } = await import('node:child_process'); execFileSync('python', ['-c', `from PIL import Image; Image.open(r'${f}').resize((512,448),Image.NEAREST).save(r'${f.replace('.ppm','.png')}')`]); } catch {}
  console.log(`frame ${s.frame} pc=${s.PB.toString(16)}:${s.PC.toString(16)} hero=(${w16(syms.ex) >> 4},${w16(syms.ey) >> 4}) hp=${arr('ehp')} st=${arr('est')} alert=${arr('ealert')} mode=${w16(syms.mode)} lvl=${w16(syms.level)} xp=${w16(syms.xp)} gold=${w16(syms.gold)} kills=${w16(syms.kills)} belt=${[0,2,4,6].map(o=>w16(syms.belt+o))}`);
}
console.log(`logic cycles per frame: avg ${Math.round(sum / Math.max(1, cnt))}, worst ${worst} (budget ~40000 in active display)`);
console.log('ghoul px:', arr('ex').map((v, i) => `(${(v & 0xFFFF) >> 4},${(arr('ey')[i] & 0xFFFF) >> 4})`).join(' '));
