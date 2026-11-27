// node tools/build_step0.mjs -> out/anaroch_step0.sfc + .bml (needs the files of build_chip_assets.py and build_chip.mjs)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assemble } from './asm816.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out = path.join(root, 'out'), chip = path.join(out, 'chip');
const table = Buffer.alloc(4096);
let seed = 99; for (let i = 0; i < table.length; i++) { seed = (seed * 16807) % 2147483647; table[i] = seed & 255; }
fs.writeFileSync(path.join(chip, 'table.bin'), table);
let sum = 0; for (let i = 0; i < table.length; i += 2) sum = (sum + table.readUInt16LE(i)) & 0xFFFF;
const { rom, syms } = assemble(path.join(root, 'src', 'step0.asm'), { banks: 16, defines: { SUM: sum } });
const data = Buffer.alloc(0x100000);
fs.writeFileSync(path.join(out, 'anaroch_step0.sfc'), Buffer.concat([rom, data]));
fs.writeFileSync(path.join(out, 'anaroch_step0.sym.json'), JSON.stringify(syms, null, 1));
const mem = (type, size, content, extra = []) => ['    memory', `      type:    ${type}`, `      size:    0x${size.toString(16)}`, `      content: ${content}`, ...extra];
fs.writeFileSync(path.join(out, 'anaroch_step0.bml'), ['game', '  name:   anaroch_step0', '  title:  Anaroch Step Zero', '  region: NTSC', '  board:  ANAROCH-DUAL',
  ...mem('ROM', rom.length, 'Program'), ...mem('ROM', data.length, 'Data'), ...mem('RAM', 0x20000, 'Save', ['      volatile']), '    oscillator', '      frequency: 21440000', ''].join('\n'));
console.log('wrote out/anaroch_step0.sfc, table sum', sum.toString(16));
