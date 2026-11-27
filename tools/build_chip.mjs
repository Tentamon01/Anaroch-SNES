// node tools/build_chip.mjs -> out/anaroch_chiptest.sfc + .bml: the three-chip test cartridge for ares_dual
// (needs: python tools/build_assets.py, then python tools/build_chip_assets.py and node tools/build_audio.mjs)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assemble } from './asm816.mjs';
import { assembleGsu } from './gsuasm.mjs';
import { compressTiles4, unpackPixels, tilesToPixels } from './spc7110.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out = path.join(root, 'out'), chip = path.join(out, 'chip');
const gsu = assembleGsu('TEXBANK = 1\n' + fs.readFileSync(path.join(root, 'src', 'gsu_test.s'), 'utf8'), 0xC000);
fs.writeFileSync(path.join(chip, 'gsu.bin'), gsu.code);
const picture = fs.readFileSync(path.join(chip, 'picture.bin'));
const packed = compressTiles4(picture);
const back = unpackPixels(packed, 4, picture.length * 2), want = tilesToPixels(picture);
if (!want.every((v, i) => v === back[i])) throw new Error('the packed picture does not unpack to itself');
const data = Buffer.alloc(0x100000);
data.set([2, 0x00, 0x10, 0x00], 0);                    // directory entry 0: 4 bits a pixel, at $001000
packed.copy(data, 0x1000);
picture.copy(data, 0x80000);                           // the original, to compare with
const spc = JSON.parse(fs.readFileSync(path.join(out, 'audio', 'spc.json'), 'utf8'));
const sum = picture.reduce((a, b) => (a + b) & 0xFFFF, 0);
const { rom, syms } = assemble(path.join(root, 'src', 'chip_test.asm'), { banks: 16, defines: { SPC_SIZE: Math.min(spc.size, 0x8000), SPC_ENTRY: spc.entry, PIC_BYTES: picture.length, PIC_SUM: sum } });
const sfc = Buffer.concat([rom, data]);
fs.writeFileSync(path.join(out, 'anaroch_chiptest.sfc'), sfc);
fs.writeFileSync(path.join(out, 'anaroch_chiptest.sym.json'), JSON.stringify(syms, null, 1));
const mem = (type, size, content, extra = []) => ['    memory', `      type:    ${type}`, `      size:    0x${size.toString(16)}`, `      content: ${content}`, ...extra];
fs.writeFileSync(path.join(out, 'anaroch_chiptest.bml'), ['game', '  name:   anaroch_chiptest', '  title:  Anaroch Chip Test', '  region: NTSC', '  board:  ANAROCH-DUAL',
  ...mem('ROM', rom.length, 'Program'), ...mem('ROM', data.length, 'Data'), ...mem('RAM', 0x20000, 'Save', ['      volatile']), '    oscillator', '      frequency: 21440000', ''].join('\n'));
console.log(`picture ${picture.length} -> ${packed.length} B packed; GSU ${gsu.code.length} B; frame loop ${syms.loop_size} B; wrote out/anaroch_chiptest.sfc`);
