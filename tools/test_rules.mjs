// Calls the rules' routines inside the built ROM (the test emulator) and checks what they leave in memory against the
// N64 version's rules (out/rules.json, written by tools/build_rules.py).  node tools/test_rules.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot } from './boot.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const s = new Snes(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc')), { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const R = JSON.parse(fs.readFileSync(path.join(root, 'out', 'rules.json'), 'utf8'));
const E = R.enums;
boot(s, sy);

const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const pw = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
const V = (name) => w(sy[name]);
const set = (name, v) => pw(sy[name], v);
const BASE = 0x2000;                                   // ITEMS in $7E:2000
const F = { kind: 0, rar: 2, base: 4, ilvl: 6, ident: 8, x: 10, y: 12, n: 14, pre: 16, suf: 18, w1: 20, w2: 22 };
const item = (off) => { const o = {}; for (const [k, d] of Object.entries(F)) o[k] = w(BASE + off + d); o.mods = []; for (let m = 0; m < Math.min(o.n, 6); m++) o.mods.push([w(BASE + off + 24 + m * 2), w(BASE + off + 36 + m * 2)]); return o; };
const putItem = (off, o) => { for (let i = 0; i < 64; i += 2) pw(BASE + off + i, 0); for (const [k, d] of Object.entries(F)) pw(BASE + off + d, o[k] || 0); (o.mods || []).forEach(([k, v], m) => { pw(BASE + off + 24 + m * 2, k); pw(BASE + off + 36 + m * 2, v); }); pw(BASE + off + F.n, (o.mods || []).length); };

// runs a routine that ends in rts; returns A, X, Y and the carry
function call(name, { a = 0, x = 0, y = 0 } = {}) {
  const addr = sy[name]; if (addr === undefined) throw new Error('no ' + name);
  s.PB = 0xAA; s.PC = addr & 0xFFFF; s.P = 0x04; s.E = 0; s.D = 0; s.DB = 0x80; s.S = 0x1fef; s.A = a; s.X = x; s.Y = y;
  s.push16(0xfff0 - 1);
  for (let n = 0; n < 3000000; n++) { if (s.PC === 0xfff0) return { a: s.A, x: s.X, y: s.Y, c: s.P & 1 }; s.step(); }
  throw new Error(name + ' did not come back (at ' + s.PB.toString(16) + ':' + s.PC.toString(16) + ')');
}
let fails = 0;
const check = (ok, what) => { if (!ok) { fails++; if (fails < 15) console.log('  FAIL', what); } };
const pmods = (k) => sy.pmods + k * 2;
const clearMods = () => { for (let k = 0; k < 33; k++) pw(pmods(k), 0); };

// ---------------------------------------------------------------- arithmetic
let seed = 11; const rnd = (n) => (seed = (seed * 16807) % 2147483647) % n;
for (let i = 0; i < 400; i++) {
  const a = rnd(65536), b = i < 20 ? 65535 : rnd(65536);
  set('rm', b); call('Mul16', { a });
  const got = V('rh') * 65536 + V('rl'); check(got === a * b, `Mul16 ${a} * ${b} = ${a * b}, got ${got}`);
  const d = 1 + rnd(i & 1 ? 65535 : 300);
  call('Div32', { a: d }); const q = V('rh') * 65536 + V('rl'); check(q === Math.floor(got / d) && V('rem') === got % d, `Div32 ${got} / ${d}: ${q} r ${V('rem')}`);
}
console.log('arithmetic checked');

// ---------------------------------------------------------------- drops
const base = (k) => { const b = R.bases[k]; return { slot: b[1], fam: b[2], tier: b[3], req: b[4], wmin: b[5], wmax: b[6], str: b[7], hp: b[8], def: b[9] }; };
const tags = (slot, fam) => slot === 0 ? 1 | (R.families[fam][4] ? 4 : 2) : slot === 4 ? 8 | 16 : slot === 3 ? 8 | 32 : slot === 1 || slot === 2 ? 8 : 64;
for (const [src, level, mf] of [[0, 3, 0], [1, 20, 0], [2, 45, 100], [1, 99, 0]]) {
  const count = [0, 0, 0, 0, 0]; let made = 0; const N = 2500;
  for (let i = 0; i < N; i++) {
    clearMods(); pw(pmods(E.K_MAGIC_FIND_PERCENT), mf); set('rlvl', level); set('rsrc', src); set('rng', 1 + rnd(65535));
    if (!call('RollDrop').c) continue;
    const it = item(59 * 64); made++; count[it.rar]++;
    check(it.kind === 1 && it.rar <= 4 && it.ilvl === Math.min(level, 120), `drop header ${JSON.stringify(it)}`);
    check(it.ident === (it.rar <= 1 ? 1 : 0), `ident ${it.rar} ${it.ident}`);
    if (it.rar === 4) {
      const u = R.uniques[it.base]; check(u && u[3] <= level + 3, `unique ${it.base} at ${level}`);
      if (u) check(it.n === u[10] && it.mods.every(([k, v], m) => k === u[11][m] && v === u[12][m]), `unique properties ${JSON.stringify(it.mods)} ${JSON.stringify(u)}`);
      continue;
    }
    check(it.base < 120, 'base ' + it.base); const b = base(it.base);
    check(Math.abs(R.tierLevels[b.tier] - level) <= 14 || level > 80, `tier ${b.tier} for level ${level}`);
    const want = it.rar === 0 || it.rar === 1 ? [0, 0] : it.rar === 2 ? [1, 2] : [3, 6];
    check(it.n >= want[0] && it.n <= want[1], `rarity ${it.rar} with ${it.n} properties`);
    const keys = new Set(it.mods.map((m) => m[0])); check(keys.size === it.n, 'property twice ' + JSON.stringify(it.mods));
    for (const [k, v] of it.mods) {
      const ok = R.affixes.some((a, ai) => a[1] === k && (a[2] & tags(b.slot, b.fam)) && a[5] <= it.ilvl && v >= R.values[(ai * 121 + it.ilvl) * 2] && v <= R.values[(ai * 121 + it.ilvl) * 2 + 1]);
      check(ok, `property ${k} = ${v} on slot ${b.slot} item level ${it.ilvl}`);
    }
    if (it.rar === 3) check(it.w1 < 12 && it.w2 < 12, 'rare words');
  }
  // the expected shares
  const q = R.quality[src], m = mf / 100, wq = [q[0] / (1 + m), q[1], q[2] * (1 + m * 0.5), q[3] * (1 + m * 1.2)], tot = wq.reduce((a, b) => a + b, 0);
  const uc = R.uniques.some((u) => u[3] <= level + 3) ? R.uchance[src] * (1 + mf / 300) : 0;
  const expect = [...wq.map((v) => (1 - uc) * v / tot), uc];
  const share = count.map((c) => c / made);
  console.log(`drops source ${src} level ${level} find ${mf}: ${made}/${N}; poor normal magic rare unique ${share.map((v) => (100 * v).toFixed(1)).join(' ')} (rules ${expect.map((v) => (100 * v).toFixed(1)).join(' ')})`);
  if (src === 0) check(Math.abs(made / N - 0.05) < 0.02, 'gear chance ' + made / N);
  else { check(made === N, 'champions and bosses always drop'); share.forEach((v, k) => check(Math.abs(v - expect[k]) < 0.035, `share of quality ${k}: ${v} vs ${expect[k]}`)); }
}

// ---------------------------------------------------------------- the bag: pieces never overlap, none is lost
const sizeOf = (it) => { if (it.kind !== 1) return [1, 1]; const slot = it.rar === 4 ? R.uniques[it.base][1] : R.bases[it.base][1], fam = it.rar === 4 ? R.uniques[it.base][2] : R.bases[it.base][2]; return slot === 0 ? [R.families[fam][5], R.families[fam][6]] : R.slotGrid[slot]; };
const census = () => { const list = []; for (let p = 0; p < 51; p++) { const it = item(p * 64); if (it.kind) list.push({ p, ...it }); } return list; };
function sane(what) {
  const grid = new Array(40).fill(null);
  for (const it of census()) {
    if (it.p < 40) { const [wd, h] = sizeOf(it); check(it.x + wd <= 10 && it.y + h <= 4, `${what}: outside the bag`); for (let y = it.y; y < it.y + h; y++) for (let x = it.x; x < it.x + wd; x++) { check(grid[y * 10 + x] === null, `${what}: two pieces on one cell`); grid[y * 10 + x] = it.p; } }
    else if (it.p < 47) check(it.kind === 1 && (it.rar === 4 ? R.uniques[it.base][1] : R.bases[it.base][1]) === it.p - 40, `${what}: wrong piece worn in ${it.p - 40}`);
    else check(it.kind !== 1, `${what}: gear on the belt`);
  }
  for (let c = 0; c < 40; c++) { const got = w(sy.bagmap + c * 2); check(got === (grid[c] === null ? 0xffff : grid[c] * 64), `${what}: bag map cell ${c}`); }
}
call('NewKit'); sane('a new hero');
set('level', 99);
let ops = { add: 0, full: 0, wear: 0, refused: 0, off: 0, belt: 0 };
for (let i = 0; i < 2500; i++) {
  const before = census().length, r = rnd(10);
  if (r < 4) {
    clearMods(); set('rlvl', 1 + rnd(60)); set('rsrc', 1 + rnd(2)); set('rng', 1 + rnd(65535));
    if (rnd(4) === 0) call('MakeThing', { a: 2 + rnd(2), y: rnd(2) }); else call('RollDrop');
    set('bsrc', 59 * 64); const ok = call('BagAdd').c; ok ? ops.add++ : ops.full++;
    check(census().length === before + (ok ? 1 : 0), 'add changes the count');
  } else if (r < 7) {
    const list = census().filter((p) => p.p < 40 && p.kind === 1); if (!list.length) continue;
    const pick = list[rnd(list.length)]; const ok = call('Equip', { x: pick.p * 64 }).c; ok ? ops.wear++ : ops.refused++;
    check(census().length === before, 'wearing changes the count');
  } else if (r === 7) {
    const list = census().filter((p) => p.p >= 40); if (!list.length) continue;
    if (call('BackToBag', { x: list[rnd(list.length)].p * 64 }).c) ops.off++; call('StatsRecalc'); check(census().length === before, 'taking off changes the count');
  } else if (r === 8) {
    const list = census().filter((p) => p.p < 40 && p.kind > 1); if (!list.length) continue;
    if (call('BeltPut', { x: list[rnd(list.length)].p * 64 }).c) ops.belt++; check(census().length === before, 'the belt changes the count');
  } else {
    const list = census().filter((p) => p.p < 40); if (!list.length) continue;
    call('ItemClear', { x: list[rnd(list.length)].p * 64 }); call('BagRebuild');
  }
  sane('step ' + i);
  if (fails > 20) break;
}
console.log('bag:', JSON.stringify(ops));

// ---------------------------------------------------------------- the hero's numbers (stats_recalc)
const numbers = (it) => {
  if (it.rar === 4) { const u = R.uniques[it.base]; return { wmin: u[5], wmax: u[6], str: u[7], hp: u[8], def: u[9], slot: u[1], fam: u[2] }; }
  const b = base(it.base), k = it.rar === 0 ? 0.75 : 1, o = { wmin: Math.floor(b.wmin * k), wmax: Math.floor(b.wmax * k), str: Math.floor(b.str * k), hp: Math.floor(b.hp * k), def: Math.floor(b.def * k), slot: b.slot, fam: b.fam };
  for (const [key, v] of it.mods) { if (key === E.K_HP) o.hp += v; if (key === E.K_STR) o.str += v; if (key === E.K_DEF) o.def += v; }
  return o;
};
for (let t = 0; t < 250; t++) {
  for (let p = 40; p < 47; p++) {
    putItem(p * 64, { kind: 0 });
    if (rnd(3) === 0) continue;
    for (let tries = 0; tries < 300; tries++) {
      clearMods(); set('rlvl', 1 + rnd(90)); set('rsrc', 1 + rnd(2)); set('rng', 1 + rnd(65535)); call('RollDrop');
      const it = item(59 * 64); if (numbers(it).slot === p - 40) { putItem(p * 64, it); break; }
    }
  }
  const a = { strb: 10 + rnd(80), defb: 10 + rnd(80), lifeb: 10 + rnd(80), sDex: 10 + rnd(60), sEne: 10 + rnd(60), level: 1 + rnd(98) };
  for (const [k, v] of Object.entries(a)) set(k, v);
  set('heroFlags', t & 1); set('ehp', 1); set('stam', 0);
  call('StatsRecalc');
  let str = a.strb, def = a.defb, hp = a.lifeb, wmin = 0, wmax = 0, fam = 9; const m = new Array(33).fill(0);
  for (let p = 40; p < 47; p++) { const it = item(p * 64); if (!it.kind) continue; const n = numbers(it); str += n.str; def += n.def; hp += n.hp; if (p === 40) { wmin = n.wmin; wmax = n.wmax; fam = n.fam; } for (const [k, v] of it.mods) if (k !== E.K_HP && k !== E.K_STR && k !== E.K_DEF) m[k] += v; }
  const pc = (v, p) => Math.min(65535, Math.floor(v * (100 + p) / 100));
  const S = pc(str, m[E.K_STRENGTH_PERCENT]), D = pc(def, m[E.K_DEFENSE_PERCENT]), L = pc(hp, m[E.K_MAX_LIFE_PERCENT]);
  const dx = Math.max(0, a.sDex - 10), en = Math.max(0, a.sEne - 10);
  const swing = fam === 9 ? 42 : Math.round(R.families[fam][1] * 60), speed = Math.min(500, dx * 5);
  const frames = Math.max(12, Math.floor(swing * 1000 / (1000 + m[E.K_ATTACK_SPEED_PERCENT] * 10 + speed)));
  const power = fam !== 9 && R.families[fam][4] ? a.sDex : S;
  const want = { hstr: S, hdef: D, ehpmax: L, critPm: 50 + (m[E.K_CRIT_CHANCE_PERCENT] + m[E.K_DEADLY_STRIKE_PERCENT]) * 10 + dx, evadePm: m[E.K_EVADE_CHANCE_PERCENT] * 10 + dx, blockPm: m[E.K_BLOCK_CHANCE_PERCENT] * 10,
    maxStam: 100 + 2 * (a.level - 1) + 2 * en, swingF: frames, atkmin: Math.floor(wmin * (100 + power) / 100), atkmax: power + Math.floor(wmax * (100 + power) / 100) };
  for (const [k, v] of Object.entries(want)) { const got = k === 'ehpmax' ? w(sy.emaxhp) : V(k); check(got === v, `stats ${k}: ${got}, rules ${v} (try ${t}, family ${fam})`); }
  for (let e = 0; e < 4; e++) { const r = Math.min(75, m[E.K_FIRE_RESIST_PERCENT + e] + m[E.K_RESIST_ALL_PERCENT] + (t & 1 ? 10 : 0)); check(w(sy.resist + e * 2) === r, `resistance ${e}: ${w(sy.resist + e * 2)} vs ${r}`); }
  if (fails > 20) break;
}
console.log('hero numbers checked');

// ---------------------------------------------------------------- the damage formula (calc_damage)
for (const [str, lo, hi, def, crit] of [[0, 6, 25, 14, 50], [0, 40, 90, 60, 250], [0, 100, 400, 200, 0], [0, 0, 12, 0, 50]]) {
  const N = 4000; let sum = 0, crits = 0;
  for (let i = 0; i < N; i++) { set('tmpC', lo); set('tmpD', hi); set('tmpF', def); set('cEnh', 0); set('cCrit', crit); set('cEvade', 0); set('cBlock', 0); set('rng', 1 + rnd(65535)); sum += call('Damage').a; crits += V('hcrit'); }
  let want = 0, n = 0;
  for (let a = lo; a <= hi; a++) for (let d = 0; d <= def; d++) { const raw = Math.max(0, a - d), dr = Math.min(0.65, def / (def + 80)), v = Math.round(raw * (1 - dr)); want += v * (1 - crit / 1000) + Math.round(v * 1.6) * crit / 1000; n++; }
  console.log(`damage ${lo}-${hi} against ${def}: average ${(sum / N).toFixed(2)}, rules ${(want / n).toFixed(2)}; criticals ${(100 * crits / N).toFixed(1)}% (${crit / 10}%)`);
  check(Math.abs(sum / N - want / n) < Math.max(0.6, want / n * 0.05), 'damage average'); check(Math.abs(crits / N - crit / 1000) < 0.015, 'critical share');
}

// ---------------------------------------------------------------- experience
clearMods(); call('NewKit'); set('level', 1); set('xp', 0); set('xph', 0); set('points', 0); set('skillPts', 0);
let total = 0;
for (let i = 0; i < 900 && V('level') < 99; i++) { const g = rnd(2) ? 60000 : 3000; total += g; call('GainXp', { a: g }); }
let L = 1, left = total; while (L < 99 && left >= Math.round(100 * L ** 1.5)) { left -= Math.round(100 * L ** 1.5); L++; }
check(V('level') === L && (L === 99 || V('xph') * 65536 + V('xp') === left), `experience: level ${V('level')} (+${V('xph') * 65536 + V('xp')}), rules ${L} (+${left})`);
check(V('points') === 2 * (L - 1) && V('skillPts') === L - 1, 'points per level');
console.log(`experience: ${total} reaches level ${V('level')}`);

console.log(fails ? `${fails} checks FAILED` : 'all rule checks pass');
process.exit(fails ? 1 : 0);
