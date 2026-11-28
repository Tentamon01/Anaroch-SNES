// Renders every place of the game from the N64 version's models: node tools/render_world.mjs
// (needs node tools/make_area_unlit.mjs first, for the graveyard)
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const outdoor = ['--flat', '--moon', '--exposure=1.9'];           // moonlight, flat tints: the tiles repeat
const house = ['--exposure=1.0'];                                // a house keeps the lamplight the N64 baked into it
const places = [
  ['gymoon', '72x72', [...outdoor, '--from=out/step0/graveyard_unlit.glb']],
  ['town', '80x68', outdoor],
  ['sd_i_trade', '16x14', house],
  ['sd_i_scrip', '16x14', house],
  ['sd_i_inn', '18x14', house],
];
for (const [area, size, opts] of places)
  for (const layer of [[], ['--front']])
    execFileSync('node', [path.join(root, 'tools', 'render_area.mjs'), area, 't1', `--size=${size}`, ...opts, ...layer], { cwd: root, stdio: 'inherit' });
