// Renders a realistic skeleton for the SNES version: an anatomical model (skull, ribs over a dark chest, spine,
// pelvis, paired forearm and shin bones, hands, feet, rags) bound to the hero rig's bones, posed by the engine's clips
// and drawn by the N64 sprite version's renderer. The N64 project is only read: this writes a patched copy of its
// tools/build_sprites.mjs into out/ and runs it. Output: out/skel_src/spr_skel_*.png + spr_skel.h
// usage: node tools/make_skeleton.mjs
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const n64 = path.join(path.dirname(root), 'Anaroch_N64_Sprite');
const out = path.join(root, 'out'), dst = path.join(out, 'skel_src');
fs.mkdirSync(dst, { recursive: true });
let src = fs.readFileSync(path.join(n64, 'tools', 'build_sprites.mjs'), 'utf8').replace(/\r\n/g, '\n');
const url = (p) => pathToFileURL(path.join(n64, p)).href;
const sub = (a, b) => { if (!src.includes(a)) throw new Error('renderer changed, not found: ' + a.slice(0, 60)); src = src.replace(a, b); };
sub("from 'three';", `from '${url('node_modules/three/build/three.module.js')}';`);
sub("from './glb.mjs';", `from '${url('tools/glb.mjs')}';`);
sub("from './iconlib.mjs';", `from '${url('tools/iconlib.mjs')}';`);
sub('const wg = readGLB(`assets/${weaponName}.glb`);', `const wg = readGLB(\`${n64.replace(/\\/g, '/')}/assets/\${weaponName}.glb\`);`);
sub('if (pbr.baseColorTexture) {', "if (pbr.baseColorTexture && !process.argv.includes('--anatomy')) {");
sub('for (const att of [weapon, skull]) if (att) {', 'for (const att of [weapon, skull, ...bones]) if (att) {');
// the ribcage in rows: one pixel of rib, one of shadow, at the SNES's size (18 px a metre), whatever the angle
sub('return shade(alb, n, pt.shine);', `if (pt.stripe) { const y = sp[ia].y * w0 + sp[ib].y * w1 + sp[ic].y * w2, row = Math.floor(y / SS * (18 / PPM));
            const c = row & 1 ? [0.012, 0.008, 0.005] : [0.42, 0.34, 0.18]; return shade(c, n, false); }
          return shade(alb, n, pt.shine);`);
sub('const K = 1.15;', 'const K = process.argv.includes("--anatomy") ? 1.3 : 1.15;');

const anatomy = String.raw`
// ---------------------------------------------------------------- --anatomy: the body is a skeleton
let bones = [];
if (process.argv.includes('--anatomy')) {
  prims = [];
  const lin = c => [((c >> 16) & 255) / 255, ((c >> 8) & 255) / 255, (c & 255) / 255].map(v => Math.pow(v, 2.2));
  const BONE = lin(0xa8976c), OLD = lin(0x776443), DARK = lin(0x0c0906), RAG = lin(0x33231a), RAG2 = lin(0x221812), IRON = lin(0x4a3a30);
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  const at = r => new THREE.Vector3().setFromMatrixPosition(restWorld[humanBones[r].node]);
  const has = r => !!humanBones[r];
  const le = at('leftUpperArm'), ri = at('rightUpperArm'), head = at('head'), hips = at('hips');
  const side = Math.sign(le.x - ri.x) || 1;                                   // +x is the model's left or right
  const fwd = has('leftToes') && has('leftFoot') ? (Math.sign(at('leftToes').z - at('leftFoot').z) || 1) : 1;
  let seed = 5; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const parts = new Map();
  const attach = role => { const node = humanBones[role].node; if (!parts.has(node)) parts.set(node, { parts: [], node, local: restWorld[node].clone().invert() }); return parts.get(node).parts; };
  const mesh = role => { const m = { P: [], N: [], C: [], I: [], shine: false }; attach(role).push(m); return m; };
  const vert = (m, p, n, col) => { const k = 0.82 + 0.3 * rnd(); m.P.push(p.x, p.y, p.z); m.N.push(n.x, n.y, n.z); m.C.push(col[0] * k, col[1] * k, col[2] * k, 1); };
  const ell = (role, c, rx, ry, rz, col, segs = 8) => { const m = mesh(role);
    for (let a = 0; a <= segs; a++) for (let b = 0; b <= segs; b++) { const th = a / segs * Math.PI, ph = b / segs * Math.PI * 2, n = V(Math.sin(th) * Math.cos(ph), Math.cos(th), Math.sin(th) * Math.sin(ph));
      vert(m, V(c.x + n.x * rx, c.y + n.y * ry, c.z + n.z * rz), V(n.x / rx, n.y / ry, n.z / rz).normalize(), col); }
    for (let a = 0; a < segs; a++) for (let b = 0; b < segs; b++) { const i = a * (segs + 1) + b; m.I.push(i, i + segs + 1, i + 1, i + 1, i + segs + 1, i + segs + 2); } return m; };
  // a tube through the points, its radius from the list (spread evenly along it)
  const tube = (role, pts, radii, col, segs = 7) => { const m = mesh(role), n = pts.length;
    const rAt = t => { const f = t * (radii.length - 1), i = Math.min(radii.length - 2, Math.floor(f)); return radii[i] + (radii[i + 1] - radii[i]) * (f - i); };
    for (let k = 0; k < n; k++) { const d = pts[Math.min(n - 1, k + 1)].clone().sub(pts[Math.max(0, k - 1)]).normalize();
      const u = Math.abs(d.y) < 0.9 ? V(0, 1, 0) : V(1, 0, 0), a = u.clone().cross(d).normalize(), b = d.clone().cross(a), r = rAt(k / (n - 1));
      for (let s = 0; s <= segs; s++) { const ph = s / segs * Math.PI * 2, nn = a.clone().multiplyScalar(Math.cos(ph)).addScaledVector(b, Math.sin(ph)); vert(m, pts[k].clone().addScaledVector(nn, r), nn, col); } }
    for (let k = 0; k < n - 1; k++) for (let s = 0; s < segs; s++) { const i = k * (segs + 1) + s; m.I.push(i, i + segs + 1, i + 1, i + 1, i + segs + 1, i + segs + 2); } return m; };
  const line = (a, b, n = 6) => Array.from({ length: n }, (_, i) => a.clone().lerp(b, i / (n - 1)));
  const longBone = (role, a, b, end, mid, col = BONE) => { tube(role, line(a, b, 9), [end, mid * 1.15, mid, mid, mid, mid * 1.1, end * 0.95], col);
    ell(role, a, end * 1.1, end, end * 1.1, col, 6); ell(role, b, end, end * 0.9, end, col, 6); };
  const knob = 0.036;

  // the spine: vertebrae from the pelvis to the skull
  const chain = ['hips', 'spine', 'chest', 'upperChest', 'neck', 'head'].filter(has);
  const back = p => V(p.x, p.y, p.z - fwd * 0.035);
  for (let i = 0; i + 1 < chain.length; i++) { const a = back(at(chain[i])), b = back(at(chain[i + 1])), n = Math.max(2, Math.round(a.distanceTo(b) / 0.036));
    for (let k = 0; k < n; k++) { const p = a.clone().lerp(b, (k + 0.5) / n), role = chain[i];
      ell(role, p, 0.03, 0.015, 0.03, OLD, 6); ell(role, V(p.x, p.y - 0.004, p.z - fwd * 0.03), 0.01, 0.009, 0.022, BONE, 5); } }

  // the ribcage: a dark chest inside, eight ribs a side sweeping from the spine round to the breastbone
  const chestRole = has('upperChest') ? 'upperChest' : 'chest';
  const topY = (le.y + ri.y) / 2 - 0.02, botY = at('spine').y + 0.04, cz = back(at(chestRole)).z, cx = (le.x + ri.x) / 2, H = topY - botY;
  const halfW = Math.abs(le.x - ri.x) * 0.46;
  ell(chestRole, V(cx, topY - H * 0.5, cz + fwd * 0.07), halfW * 0.74, H * 0.47, 0.058, DARK, 10).stripe = true;
  const NR = +(process.env.RIBS || 3), thick = NR > 5 ? 1 : 1.35;   // (small sprites: fewer, heavier ribs, wider gaps)
  for (let i = 0; i < NR; i++) {
    const t = i / (NR - 1), y = topY - 0.012 - t * H * 0.86, w = halfW * (0.55 + 0.45 * Math.sin(Math.PI * (0.18 + t * 0.62))), dp = 0.085 + 0.035 * Math.sin(Math.PI * (0.2 + t * 0.6));
    const role = t < 0.55 ? chestRole : 'chest' in humanBones ? 'chest' : chestRole;
    for (const s of [-1, 1]) { const pts = [];
      for (let k = 0; k <= 10; k++) { const a = k / 10 * Math.PI * (i === NR - 1 ? 0.72 : 0.94);
        pts.push(V(cx + s * Math.sin(a) * w, y - 0.05 * (k / 10) * (k / 10), cz + fwd * (dp - Math.cos(a) * dp))); }
      tube(role, pts, [0.017, 0.0135, 0.0125, 0.011].map(r => r * thick), BONE, 6).stripe = true; }
  }
  tube(chestRole, line(V(cx, topY, cz + fwd * 0.165), V(cx, topY - H * 0.62, cz + fwd * 0.2)), [0.022, 0.024, 0.014], BONE);   // the breastbone
  for (const [sh, up] of [['leftShoulder', 'leftUpperArm'], ['rightShoulder', 'rightUpperArm']]) { const p = at(up);
    tube(chestRole, [V(cx + Math.sign(p.x - cx) * 0.02, topY + 0.01, cz + fwd * 0.15), V((cx + p.x) / 2, topY + 0.035, cz + fwd * 0.12), V(p.x, p.y + 0.012, p.z)], [0.017, 0.013, 0.019], BONE);   // the collar bone
    ell(chestRole, V((cx + p.x * 2) / 3, topY - 0.06, cz - fwd * 0.02), 0.05, 0.075, 0.014, OLD);                 // the shoulder blade
  }

  // the pelvis: two flared wings, the sacrum, the arch in front
  const ul = at('leftUpperLeg'), ur = at('rightUpperLeg');
  ell('hips', V(hips.x, hips.y - 0.005, hips.z - fwd * 0.045), 0.045, 0.055, 0.028, OLD);
  for (const u of [ul, ur]) { const s = Math.sign(u.x - hips.x);
    ell('hips', V(hips.x + s * 0.085, hips.y + 0.012, hips.z - fwd * 0.012), 0.066, 0.058, 0.026, BONE, 9);
    ell('hips', V(hips.x + s * 0.078, hips.y + 0.005, hips.z + fwd * 0.012), 0.032, 0.03, 0.012, DARK, 7);
    tube('hips', [V(hips.x + s * 0.12, hips.y + 0.02, hips.z), V(u.x, u.y + 0.01, u.z), V(hips.x + s * 0.045, u.y - 0.045, hips.z + fwd * 0.035), V(hips.x, u.y - 0.035, hips.z + fwd * 0.05)], [0.022, 0.026, 0.016, 0.018], BONE); }
  // rags round the hips, torn at the bottom, and a rusty buckle
  for (const [z, col] of [[0.075, RAG], [-0.085, RAG2]]) { const m = mesh('hips'), n = 9, y0 = hips.y + 0.035;
    for (let i = 0; i <= n; i++) { const x = hips.x - 0.11 + 0.22 * i / n, len = (z > 0 ? 0.17 : 0.2) * (0.45 + 0.55 * rnd()) * (1 - 0.35 * Math.abs(i / n - 0.5) * 2) + (i > 2 && i < 7 && z > 0 ? 0.08 : 0);
      vert(m, V(x, y0, hips.z + fwd * z * 0.8), V(0, 0.1, fwd * Math.sign(z)).normalize(), col); vert(m, V(x * 1.04, y0 - len, hips.z + fwd * z * 1.15), V(0, -0.1, fwd * Math.sign(z)).normalize(), col); }
    for (let i = 0; i < n; i++) { const a = i * 2; m.I.push(a, a + 1, a + 2, a + 2, a + 1, a + 3); } }
  tube('hips', Array.from({ length: 17 }, (_, i) => { const a = i / 16 * Math.PI * 2; return V(hips.x + Math.sin(a) * 0.125, hips.y + 0.036, hips.z + Math.cos(a) * 0.085 * fwd); }), [0.012, 0.012], IRON, 6);

  // the arms and legs
  for (const s of ['left', 'right']) {
    const sh = at(s + 'UpperArm'), el = at(s + 'LowerArm'), hand = at(s + 'Hand');
    longBone(s + 'UpperArm', sh, el, knob * 0.85, 0.019);
    const across = hand.clone().sub(el).cross(V(0, 0, 1)).normalize().multiplyScalar(0.017);
    longBone(s + 'LowerArm', el.clone().add(across), hand.clone().add(across.clone().multiplyScalar(0.8)), 0.019, 0.0115);
    longBone(s + 'LowerArm', el.clone().sub(across), hand.clone().sub(across.clone().multiplyScalar(0.8)), 0.017, 0.0105, OLD);
    ell(s + 'Hand', hand, 0.022, 0.018, 0.022, OLD, 6);
    const dir = hand.clone().sub(el).normalize();
    for (let f = -1.5; f <= 1.5; f++) { const a = hand.clone().addScaledVector(across.clone().normalize(), f * 0.013);
      tube(s + 'Hand', [a, a.clone().addScaledVector(dir, 0.055), a.clone().addScaledVector(dir, 0.095).add(V(0, -0.018, 0))], [0.0085, 0.0075, 0.0055], BONE, 5); }
    const hip = at(s + 'UpperLeg'), knee = at(s + 'LowerLeg'), foot = at(s + 'Foot');
    const neckPt = V(hip.x + Math.sign(hip.x - hips.x) * 0.035, hip.y - 0.045, hip.z);
    ell(s + 'UpperLeg', V(hip.x - Math.sign(hip.x - hips.x) * 0.008, hip.y - 0.005, hip.z), 0.033, 0.033, 0.033, BONE);
    tube(s + 'UpperLeg', [hip, neckPt], [0.024, 0.026], BONE);
    longBone(s + 'UpperLeg', neckPt, knee.clone().add(V(0, 0.012, 0)), knob, 0.0225);
    ell(s + 'LowerLeg', V(knee.x, knee.y, knee.z + fwd * 0.035), 0.024, 0.027, 0.016, OLD);          // the knee cap
    longBone(s + 'LowerLeg', knee.clone().add(V(0, -0.016, fwd * 0.008)), foot, knob * 0.8, 0.0175);
    const o = Math.sign(foot.x - hips.x) * 0.03;
    longBone(s + 'LowerLeg', knee.clone().add(V(o, -0.04, -fwd * 0.012)), foot.clone().add(V(o * 0.8, 0.01, -fwd * 0.012)), 0.015, 0.0095, OLD);
    ell(s + 'Foot', V(foot.x, foot.y - 0.025, foot.z - fwd * 0.025), 0.026, 0.026, 0.036, BONE);     // the heel
    const toes = has(s + 'Toes') ? at(s + 'Toes') : V(foot.x, foot.y - 0.06, foot.z + fwd * 0.12);
    for (let f = -1; f <= 1; f++) tube(s + 'Foot', [V(foot.x + f * 0.012, foot.y - 0.025, foot.z), V(toes.x + f * 0.024, toes.y, toes.z), V(toes.x + f * 0.028, toes.y - 0.008, toes.z + fwd * 0.055)], [0.014, 0.011, 0.007], f ? OLD : BONE, 5);
  }
  bones = [...parts.values()];
}

// ---------------------------------------------------------------- the renderer`;
sub('\n// ---------------------------------------------------------------- the renderer', anatomy);
const tool = path.join(out, '_skel_render.mjs');
fs.writeFileSync(tool, src);
execFileSync('node', [tool, 'skel', '--model', 'archer', '--anatomy', '--undead', '--weapon', 'gear_w8_1', '--size', process.env.SIZE || '96x120', '--ppm', process.env.PPM || '48',
  '--anims', 'Idle_Loop:6,Walk_Loop:12,Atk_hbow:12,Hit_Chest:3,Death01:12', '--out', dst], { cwd: root, stdio: 'inherit' });
// a close-up for looking at the model
if (process.argv.includes('--closeup'))
  execFileSync('node', [tool, 'skelbig', '--model', 'archer', '--anatomy', '--undead', '--weapon', 'gear_w8_1', '--size', '96x144', '--ppm', '70', '--pitch', '0.45', '--anims', 'Idle_Loop:1,Death01:2', '--out', dst], { cwd: root, stdio: 'inherit' });
