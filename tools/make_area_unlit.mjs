// The N64 graveyard built without baked light, so its ground and walls can repeat: the renderer lights each face by
// the moon (--moon), and the braziers' glow is added on the SNES by palette. Runs a patched copy of the N64 builder; every file it writes goes to out/step0.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const n64 = path.join(path.dirname(root), 'Anaroch_N64_Sprite');
const out = path.join(root, 'out', 'step0'); fs.mkdirSync(out, { recursive: true });
let src = fs.readFileSync(path.join(n64, 'tools', 'build_area.mjs'), 'utf8').replace(/\r\n/g, '\n');
const url = (p) => pathToFileURL(path.join(n64, p)).href;
src = src.replace("from './glb.mjs';", `from '${url('tools/glb.mjs')}';`).replace("from './meshlib.mjs';", `from '${url('tools/meshlib.mjs')}';`);
const fwd = out.split(path.sep).join('/');
src = src.replace(/(['`])(assets|src)\//g, (m, q) => `${q}${fwd}/`);
if (!src.includes('function bakeLight(m) {')) throw new Error('builder changed: bakeLight');
src = src.replace('function bakeLight(m) {', 'function bakeLight(m) { return;');
if (/['`](assets|src)\//.test(src)) throw new Error('a write path was not redirected');
const tool = path.join(out, '_build_area_unlit.mjs');
fs.writeFileSync(tool, src);
execFileSync('node', [tool], { cwd: out, stdio: 'inherit' });
fs.copyFileSync(path.join(out, 'graveyard.glb'), path.join(out, 'graveyard_unlit.glb'));
