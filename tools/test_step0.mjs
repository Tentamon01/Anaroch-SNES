// node tools/test_step0.mjs [frames]: runs the step 0 cartridge in the test emulator and checks its counters
import fs from 'node:fs';
import { Snes } from './snes.mjs';
const at = (p) => new URL(`../out/${p}`, import.meta.url);
const s = new Snes(fs.readFileSync(at('anaroch_step0.sfc')), { program: 0x80000 });
const sym = JSON.parse(fs.readFileSync(at('anaroch_step0.sym.json'), 'utf8'));
const w = (n) => s.wram[sym[n]] | (s.wram[sym[n] + 1] << 8);
const N = +(process.argv[2] || 400);
for (let i = 0; i < N; i++) s.runFrame(60000);
const r = Object.fromEntries(['frames', 'pictures', 'irqs', 'busy', 'held', 'passes', 'bad', 'spareslow', 'sparefast'].map((n) => [n, w(n)]));
console.log(r, 'pc', s.PB.toString(16) + ':' + s.PC.toString(16));
process.exit(r.bad === 0 && r.passes > 10 && r.held > 10 && r.irqs > 10 ? 0 : 1);
