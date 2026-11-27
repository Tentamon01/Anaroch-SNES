// node tools/build.mjs  -> out/anaroch.sfc (+ out/anaroch.sym.json)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assemble } from './asm816.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
// the cartridge
for (const [name, MODE7] of [['anaroch', 0]]) {   // (the Mode 7 camera was dropped)
  const { rom, syms } = assemble(path.join(root, 'src', 'main.asm'), { banks: 16, defines: { MODE7 } });
  fs.writeFileSync(path.join(root, 'out', name + '.sfc'), rom);
  fs.writeFileSync(path.join(root, 'out', name + '.sym.json'), JSON.stringify(syms, null, 1));
  console.log('wrote out/' + name + '.sfc', rom.length, 'bytes');
}
