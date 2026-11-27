// Pre-renders an area of the N64 version (its GLB) for the SNES remake: an orthographic picture where one metre
// steps by whole pixels, so ground and walls repeat. The N64 project is only read.
// node tools/render_area.mjs <area> <projection> [--flat]   -> out/step0/<area>_<projection>[_flat]_<layer>.png
//   projections: t1 (turned, close to the N64 camera), t2 (turned, taller), iso (2:1), straight, n64 (the exact camera)
//   --flat: no baked light (each material one tint), which repeats better
//   layers: all, ground (what lies flat on the floor), objects (the rest, clear elsewhere)
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const n64 = path.join(path.dirname(root), 'Anaroch_N64_Sprite');
const { readGLB, accessor } = await import(pathToFileURL(path.join(n64, 'tools', 'glb.mjs')).href);
const { writePNG } = await import(pathToFileURL(path.join(n64, 'tools', 'iconlib.mjs')).href);
const out = path.join(root, 'out', 'step0'); fs.mkdirSync(out, { recursive: true });
const [area = 'graveyard', proj = 't1'] = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const flat = process.argv.includes('--flat');
const EXPOSURE = +((process.argv.find((a) => a.startsWith('--exposure=')) || '--exposure=1.7').slice(11));

// pixels per metre on screen: x axis, z axis, height
export const PROJ = {
  t1: { x: [16, 8], z: [-8, 8], h: 12 },
  big: { x: [24, 12], z: [-12, 12], h: 18 },        // t1 with everything half as big again (metres repeat on tiles in twos)
  t2: { x: [16, 8], z: [-8, 16], h: 11 },
  iso: { x: [16, 8], z: [-16, 8], h: 14 },
  straight: { x: [16, 0], z: [0, 16], h: 12 },
  n64: { x: [14.65, 8.2], z: [-10.46, 11.46], h: 11.2 },
};
const P = PROJ[proj];
const from = (process.argv.find((a) => a.startsWith('--from=')) || '').slice(7);
const g = readGLB(from || path.join(n64, 'assets', `${area}.glb`)), J = g.json;
const textures = new Map();
const texture = (name) => {
  if (!textures.has(name)) {
    const file = path.join(n64, 'assets', `tex_${name}.png`);
    textures.set(name, fs.existsSync(file) ? execFileSync('magick', [file, '-resize', '64x64!', '-depth', '8', 'rgba:-'], { maxBuffer: 1 << 22 }) : null);
  }
  return textures.get(name);
};
// all triangles with their material
const tris = [];
for (const mesh of J.meshes) for (const prim of mesh.primitives) {
  const mat = (J.materials[prim.material].name.split('_')[1]) || 'plain';
  const pos = accessor(g, prim.attributes.POSITION).data, nrm = accessor(g, prim.attributes.NORMAL).data, col = accessor(g, prim.attributes.COLOR_0).data;
  const uv = prim.attributes.TEXCOORD_0 !== undefined ? accessor(g, prim.attributes.TEXCOORD_0).data : null;
  const idx = accessor(g, prim.indices, true).data;
  for (let t = 0; t < idx.length; t += 3) {
    const v = [0, 1, 2].map((k) => { const i = idx[t + k]; return { p: [pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]], n: [nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2]], c: [col[i * 4], col[i * 4 + 1], col[i * 4 + 2]], uv: uv ? [uv[i * 2], uv[i * 2 + 1]] : null }; });
    const flatGround = v.every((a) => a.p[1] < 0.12) && Math.abs(v[0].n[1]) > 0.7;
    // the floor laid flat (its small bumps would shift every sample and make each tile its own); paths a hair above grass
    if (flatGround) for (const a of v) a.p = [a.p[0], mat === 'grass' ? 0 : a.p[1] > 0.02 ? 0.004 : 0.002, a.p[2]];
    tris.push({ mat, v, ground: flatGround });
  }
}
// without baked light: every material takes its median tint (flames and lit things keep theirs)
if (flat) {
  const by = new Map();
  for (const t of tris) { if (!by.has(t.mat)) by.set(t.mat, [[], [], []]); for (const a of t.v) a.c.forEach((c, k) => by.get(t.mat)[k].push(c)); }
  const med = new Map([...by].map(([m, ch]) => [m, ch.map((c) => c.sort((a, b) => a - b)[c.length >> 1])]));
  for (const t of tris) { if (t.mat === 'plain') continue; const m = med.get(t.mat); const up = Math.abs(t.v[0].n[1]) > 0.7; const k = process.argv.includes('--moon') || up ? 1 : Math.abs(t.v[0].n[0]) > Math.abs(t.v[0].n[2]) ? 0.62 : 0.8; for (const a of t.v) a.c = m.map((c) => c * k); }
}
// --moon: the N64 builder's moonlight (build_area.mjs bakeLight), one value a face, so equal faces stay equal
if (process.argv.includes('--moon')) {
  const AMB = [46, 50, 74].map((v) => v / 255), MOON = [120, 130, 175].map((v) => v / 255), d = [-0.45, 0.8, 0.4], l = Math.hypot(...d);
  for (const t of tris) {
    const [a, b, c] = t.v.map((q) => q.p), u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], w = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    let n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]; const len = Math.hypot(...n) || 1; n = n.map((v) => v / len);
    if (n[0] * t.v[0].n[0] + n[1] * t.v[0].n[1] + n[2] * t.v[0].n[2] < 0) n = n.map((v) => -v);
    const nd = t.ground ? d[1] / l : Math.max(0, (n[0] * d[0] + n[1] * d[1] + n[2] * d[2]) / l);
    const flame = t.v[0].c[0] > 0.55 && t.v[0].c[0] > t.v[0].c[2] * 2.5;
    if (!flame) for (const q of t.v) q.c = q.c.map((v, k) => v * Math.pow((AMB[k] + MOON[k] * nd) * EXPOSURE, 2.2));
  }
}
const SS = 2;
const sx = (p) => p[0] * P.x[0] + p[2] * P.z[0], sy = (p) => p[0] * P.x[1] + p[2] * P.z[1] - p[1] * P.h;
// the way to the viewer: the direction the projection cannot see, pointing upward
let view = [0 * -P.h - P.z[0] * -P.h, P.z[0] * P.x[1] - P.x[0] * P.z[1], P.x[0] * -P.h - 0 * P.x[1]];
view = [(0) * P.z[1] - P.z[0] * (-P.h), P.z[0] * P.x[1] - P.x[0] * P.z[1], P.x[0] * (-P.h) - 0 * P.x[1]];
if (view[1] < 0) view = view.map((v) => -v);
const depth = (p) => p[0] * view[0] + p[1] * view[1] + p[2] * view[2];
const half = 36, corners = [[-half, 0, -half], [half, 0, -half], [-half, 0, half], [half, 0, half]];
const minX = Math.floor(Math.min(...corners.map(sx)) / 8) * 8, maxX = Math.ceil(Math.max(...corners.map(sx)) / 8) * 8;
const minY = Math.floor((Math.min(...corners.map(sy)) - 6 * P.h) / 8) * 8, maxY = Math.ceil(Math.max(...corners.map(sy)) / 8) * 8;
const W = maxX - minX, H = maxY - minY;
fs.writeFileSync(path.join(out, `${area}_${proj}.json`), JSON.stringify({ minX, minY, W, H, ...P }));
const lin = (c) => Math.pow(c / 255, 2.2), srgb = (c) => Math.round(255 * Math.pow(Math.max(0, Math.min(1, c)), 1 / 2.2));
for (const layer of ['all', 'ground', 'objects']) {
  const w = W * SS, h = H * SS, col = new Float32Array(w * h * 3), zb = new Float32Array(w * h).fill(-Infinity), cov = new Uint8Array(w * h);
  for (const t of tris) {
    if (layer === 'ground' && !t.ground) continue;
    if (layer === 'objects' && t.ground) continue;
    const s = t.v.map((a) => ({ x: (sx(a.p) - minX) * SS, y: (sy(a.p) - minY) * SS, z: depth(a.p) }));
    const [a, b, c] = s;
    const area2 = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    if (Math.abs(area2) < 1e-9) continue;
    const card = t.mat === 'leaves' || t.mat === 'pine', tex = t.mat === 'plain' ? null : texture(t.mat);
    // our own texture coordinates, a repeat every 2 m, so the pattern comes round on whole metres
    const n = t.v[0].n;
    const uvs = t.v.map((q) => card && q.uv ? q.uv : Math.abs(n[1]) >= 0.7 ? [q.p[0] / 2, q.p[2] / 2] : Math.abs(n[0]) >= Math.abs(n[2]) ? [q.p[2] / 2, -q.p[1] / 2] : [q.p[0] / 2, -q.p[1] / 2]);
    const x0 = Math.max(0, Math.floor(Math.min(a.x, b.x, c.x))), x1 = Math.min(w - 1, Math.ceil(Math.max(a.x, b.x, c.x)));
    const y0 = Math.max(0, Math.floor(Math.min(a.y, b.y, c.y))), y1 = Math.min(h - 1, Math.ceil(Math.max(a.y, b.y, c.y)));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + 0.5, py = y + 0.5;
      const w0 = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) / area2, w1 = ((c.x - px) * (a.y - py) - (c.y - py) * (a.x - px)) / area2, w2 = 1 - w0 - w1;
      if (w0 < -1e-6 || w1 < -1e-6 || w2 < -1e-6) continue;
      const z = a.z * w0 + b.z * w1 + c.z * w2, o = y * w + x;
      if (z <= zb[o]) continue;
      let texel = [1, 1, 1];
      if (tex) {
        const u = uvs[0][0] * w0 + uvs[1][0] * w1 + uvs[2][0] * w2, v = uvs[0][1] * w0 + uvs[1][1] * w1 + uvs[2][1] * w2;
        const tx = ((Math.floor(u * 64 + 0.013) % 64) + 64) % 64, ty = ((Math.floor(v * 64 + 0.013) % 64) + 64) % 64, i = (ty * 64 + tx) * 4;   // (off the texel edges: the same place samples the same texel)
        if (card && tex[i + 3] < 128) continue;
        texel = [lin(tex[i]), lin(tex[i + 1]), lin(tex[i + 2])];
      }
      zb[o] = z; cov[o] = 1;
      for (let k = 0; k < 3; k++) col[o * 3 + k] = texel[k] * (t.v[0].c[k] * w0 + t.v[1].c[k] * w1 + t.v[2].c[k] * w2);
    }
  }
  const img = new Uint8Array(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let m = 0; const s = [0, 0, 0];
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) { const o = (y * SS + j) * w + x * SS + i; if (cov[o]) { m++; for (let k = 0; k < 3; k++) s[k] += col[o * 3 + k]; } }
    if (m * 2 >= SS * SS) img.set([srgb(s[0] / m), srgb(s[1] / m), srgb(s[2] / m), 255], (y * W + x) * 4);
  }
  const file = path.join(out, `${area}_${proj}${flat ? '_flat' : ''}_${layer}.png`);
  writePNG(file, W, H, img);
  if (layer === 'all') fs.writeFileSync(path.join(out, `${area}_${proj}.json`), JSON.stringify({ minX, minY, W, H, ...P }));
}
console.log(`${area} ${proj}${flat ? ' flat' : ''}: ${W} x ${H} px, ${tris.length} triangles`);
