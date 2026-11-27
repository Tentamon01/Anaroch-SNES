// node tools/build_game.mjs -> out/anaroch_game.sfc + .bml: the remake (needs build_assets.py, build_world.py and build_audio.mjs)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assemble } from './asm816.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out = path.join(root, 'out');
const spc = JSON.parse(fs.readFileSync(path.join(out, 'audio', 'spc.json'), 'utf8'));          // (tools/build_audio.mjs)
const { rom, syms } = assemble(path.join(root, 'src', 'game.asm'), { banks: 64, defines: { MODE7: 0, SPC_SIZE: spc.size, SPC_ENTRY: spc.entry } });
const data = Buffer.alloc(0x100000);
fs.writeFileSync(path.join(out, 'anaroch_game.sfc'), Buffer.concat([rom, data]));
fs.writeFileSync(path.join(out, 'anaroch_game.sym.json'), JSON.stringify(syms, null, 1));
const mem = (type, size, content, extra = []) => ['    memory', `      type:    ${type}`, `      size:    0x${size.toString(16)}`, `      content: ${content}`, ...extra];
fs.writeFileSync(path.join(out, 'anaroch_game.bml'), ['game', '  name:   anaroch_game', '  title:  Anaroch', '  region: NTSC', '  board:  ANAROCH-DUAL',
  ...mem('ROM', rom.length, 'Program'), ...mem('ROM', data.length, 'Data'), ...mem('RAM', 0x20000, 'Save', ['      volatile']), '    oscillator', '      frequency: 21440000', ''].join('\n'));
const top = Math.max(...Object.entries(syms).filter(([k, v]) => v < 0x100 && /^[a-z]/.test(k) && k.length > 1).map(([, v]) => v));
console.log('wrote out/anaroch_game.sfc', rom.length, 'bytes of program; direct page used to $' + top.toString(16));
