// node tools/build_dual.mjs  -> out/anaroch_dual.sfc (program 512 KB + SPC7110 data ROM 1 MB) + its ares manifest
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assemble } from './asm816.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const { rom, syms } = assemble(path.join(root, 'src', 'dual_test.asm'), { banks: 16, defines: { MODE7: 0 } });
const data = Buffer.alloc(0x100000);
for (let i = 0; i < data.length; i++) data[i] = (i * 7 + 3) & 0xFF;
data.write('SPC7110 DATA ROM OK\0', 0, 'ascii');
const sfc = Buffer.concat([rom, data]);
fs.writeFileSync(path.join(root, 'out', 'anaroch_dual.sfc'), sfc);
fs.writeFileSync(path.join(root, 'out', 'anaroch_dual.sym.json'), JSON.stringify(syms, null, 1));
fs.writeFileSync(path.join(root, 'out', 'anaroch_dual.bml'), [
  'game',
  '  name:   anaroch_dual',
  '  title:  Anaroch Dual',
  '  region: NTSC',
  '  board:  ANAROCH-DUAL',
  '    memory',
  '      type:    ROM',
  `      size:    0x${rom.length.toString(16)}`,
  '      content: Program',
  '    memory',
  '      type:    ROM',
  `      size:    0x${data.length.toString(16)}`,
  '      content: Data',
  '    memory',
  '      type:    RAM',
  '      size:    0x20000',
  '      content: Save',
  '      volatile',
  '    oscillator',
  '      frequency: 21440000',
  '',
].join('\n'));
console.log('wrote out/anaroch_dual.sfc', sfc.length, 'bytes (program', rom.length, '+ data', data.length, ')');
