// Cycle profile per routine (estimated by the emulator): node tools/prof.mjs <frames> <padmask>
import fs from 'node:fs';
import { Snes } from './snes.mjs';
const rom = fs.readFileSync(new URL('../out/' + (process.env.ROM || 'anaroch') + '.sfc', import.meta.url));
const syms = JSON.parse(fs.readFileSync(new URL('../out/' + (process.env.ROM || 'anaroch') + '.sym.json', import.meta.url), 'utf8'));
const labels = Object.entries(syms).filter(([k, v]) => v >= 0x8000 && v < 0xE000 && !k.includes('@')).sort((a, b) => a[1] - b[1]);
const s = new Snes(rom);
for (let i = 0; i < 30; i++) s.runFrame();
s.pad = +(process.argv[3] || 0x0200);
const prof = {}; let last = s.cyc, lastName = '?';
s.trace = (pc) => { const c = s.cyc; prof[lastName] = (prof[lastName] || 0) + (c - last); last = c;
  let lo = 0, hi = labels.length - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (labels[m][1] <= pc) lo = m; else hi = m - 1; } lastName = labels[lo][0]; };
const N = +(process.argv[2] || 60);
for (let i = 0; i < N; i++) { last = 0; s.runFrame(); }
for (const [k, v] of Object.entries(prof).sort((a, b) => b[1] - a[1]).slice(0, 14)) console.log(k.padEnd(14), Math.round(v / N));
