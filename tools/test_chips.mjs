// Runs the chip test cartridge in the test emulator and checks its own counters: node tools/test_chips.mjs [frames]
import fs from 'node:fs';
import { Snes } from './snes.mjs';
const at = (p) => new URL(`../out/${p}`, import.meta.url);
const s = new Snes(fs.readFileSync(at('anaroch_chiptest.sfc')), { program: 0x80000 });
const sym = JSON.parse(fs.readFileSync(at('anaroch_chiptest.sym.json'), 'utf8'));
const w = (n) => s.wram[sym[n]] | (s.wram[sym[n] + 1] << 8);
const N = +(process.argv[2] || 400);
for (let i = 0; i < N; i++) s.runFrame(60000);
const r = { frames: w('frames'), missed: w('missed'), pictures: w('renders'), bootBad: w('bootbad'), unpackedOk: w('loadok'), unpackedBad: w('loadbad'), gsuRuns: s.sfx.runs };
console.log(r);
const ok = r.bootBad === 0 && r.unpackedBad === 0 && r.pictures > 10 && r.unpackedOk > 1;
console.log(ok ? 'chip test passes in the test emulator' : 'chip test FAILS in the test emulator');
process.exit(ok ? 0 : 1);
