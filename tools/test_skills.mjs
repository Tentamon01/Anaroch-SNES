// Casts every skill in the built ROM (the test emulator) with monsters held in front of the hero, and checks what
// happens: the stamina it takes, the blows that land, the cry, the heal, the leap, the passives.  node tools/test_skills.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot, travel } from './boot.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const s = new Snes(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc')), { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const R = JSON.parse(fs.readFileSync(path.join(root, 'out', 'rules.json'), 'utf8'));
boot(s, sy);
travel(s, sy, 0);                    // (the graveyard: the town has no monsters)
const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
const pw = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
const V = (n, i = 0) => w(sy[n] + i * 2);
const set = (n, v, i = 0) => pw(sy[n] + i * 2, v);
const keep = ['PB', 'PC', 'P', 'E', 'D', 'DB', 'S', 'A', 'X', 'Y'];
function call(name, { a = 0, x = 0, y = 0 } = {}) {           // a routine of the rules, between two frames
  const old = Object.fromEntries(keep.map((k) => [k, s[k]]));
  const stack = s.wram.slice(0x1f80, 0x2000);
  s.PB = 0xAA; s.PC = sy[name] & 0xFFFF; s.P = 0x04; s.E = 0; s.D = 0; s.DB = 0x80; s.S = 0x1fef; s.A = a; s.X = x; s.Y = y;
  s.push16(0xfff0 - 1);
  let n = 0; while (s.PC !== 0xfff0) { s.step(); if (++n > 3e6) throw new Error(name + ' did not come back'); }
  const out = { a: s.A, c: s.P & 1 }; for (const k of keep) s[k] = old[k]; s.wram.set(stack, 0x1f80); return out;
}
let fails = 0;
const check = (ok, what) => { if (!ok) { fails++; console.log('  FAIL', what); } };
const frame = (pad = 0) => { s.pad = pad; s.runFrame(400000); };
const HX = 1000, HZ = 560;
const wx = (d) => (w(sy.wspd_hx + d * 2) << 16) >> 16, wy = (d) => (w(sy.wspd_hy + d * 2) << 16) >> 16;
const romWord = (a) => s.rd(a) | (s.rd(a + 1) << 8);
const speed = (table, d) => (romWord(table + d * 2) << 16) >> 16;
const EAST = 6;
const ux = speed(sy.wspd_hx, EAST), uy = speed(sy.wspd_hy, EAST), ul = Math.hypot(ux, uy);
const bow = R.bases.findIndex((b) => b[2] === 8), sword = 1;
function ready(skill, rank = 3) {
  const k = R.skills[skill];
  call('NewKit'); call('SkillsCalm');
  call('MakeNormal', { a: k[6] === 2 ? bow : sword });
  call('ItemCopy', { x: 59 * 64, y: 40 * 64 });
  set('level', 30);
  pw(sy.skRank + skill * 2, rank); set('skActive', skill);
  set('strb', 40); call('StatsRecalc'); set('stam', V('maxStam'));
  set('mode', 0); set('hitstop', 0);
  for (let i = 0; i < 14; i++) set('alife', 0, i);
  set('ex', HX * 16); set('ey', HZ * 16); set('edir', EAST); set('est', 0); set('etm', 0);
}
// three monsters on the line ahead, held there
const spots = [20, 34, 56];
function hold() {
  for (let m = 1; m < 9; m++) {
    if (m > 3) { set('est', 5, m); set('etm', 0, m); continue; }
    const d = spots[m - 1];
    set('ex', Math.round((HX + (ux / ul) * d)) * 16, m); set('ey', Math.round((HZ + (uy / ul) * d)) * 16, m);
    if (V('est', m) >= 4) set('est', 0, m);
    set('edef', 0, m); set('emaxhp', 20000, m); set('ealert', 0, m); set('ecool', 200, m);
  }
}
const KIND = ['slam', 'cone', 'cry', 'spin', 'line', 'leap', 'fan', 'pierce', 'fire arrow', 'strafe', 'explode', 'fire bolt', 'nova', 'heal', 'fireball', 'chain', 'teleport', 'stomp', 'ice arrow', 'meteor', 'passive'];
const scale = 3;
R.skills.forEach((k, i) => {
  const [name, , , , , , , kind, cost, mult] = k;
  if (kind === 20) return;
  ready(i);
  for (let m = 1; m <= 3; m++) set('ehp', 20000, m);
  hold(); frame(); hold(); frame();
  set('stam', V('maxStam'));
  if (kind === 13) set('ehp', 2); else set('ehp', V('emaxhp'));
  const stam0 = V('stam'), want = Math.floor(Math.round(cost * scale) * (100 + 12) / 100);
  let damage = 0, spent = 0, seen = { cry: 0, stun: 0, chill: 0, shots: 0, sparks: 0, air: 0 };
  const hp = [0, 20000, 20000, 20000], x0 = HX, y0 = HZ; let lowest = 99999;
  for (let f = 0; f < 200; f++) {
    if (kind !== 13) set('ehp', V('emaxhp'));
    hold();
    for (let m = 1; m <= 3; m++) hp[m] = V('ehp', m);
    frame(f < 2 ? 0x4000 : 0);
    for (let m = 1; m <= 3; m++) { const d = hp[m] - V('ehp', m); if (d > 0) damage += d; seen.stun = Math.max(seen.stun, V('estun', m)); seen.chill = Math.max(seen.chill, V('echill', m)); set('ehp', 20000, m); }
    spent = Math.max(spent, stam0 - V('stam'));
    seen.cry = Math.max(seen.cry, V('cryLeft'));
    let shots = 0; for (let n = 0; n < 14; n++) if (V('alife', n)) shots++; seen.shots = Math.max(seen.shots, shots);
    let sp = 0; for (let n = 0; n < 16; n++) if (V('fxl', n)) sp++; seen.sparks = Math.max(seen.sparks, sp);
    seen.air = Math.max(seen.air, V('heroLift'));
    lowest = Math.min(lowest, V('ehp'));
  }
  const moved = Math.round(Math.hypot((V('ex') >> 4) - x0, (V('ey') >> 4) - y0));
  const line = `${name.padEnd(16)} ${KIND[kind].padEnd(10)} stamina ${String(spent).padStart(2)} damage ${String(damage).padStart(5)} shots ${seen.shots} sparks ${String(seen.sparks).padStart(2)} stun ${seen.stun} chill ${seen.chill} moved ${moved} lift ${seen.air} life ${V('ehp')}`;
  console.log(line);
  check(Math.abs(spent - want) <= 1, `${name}: stamina ${spent}, rules ${want}`);
  if (![2, 13, 16].includes(kind)) check(damage > 0, `${name}: nothing was hurt`);
  if (kind === 0) check(seen.stun > 60, `${name}: no stun`);
  if (kind === 2) check(seen.cry > 500, `${name}: no cry`);
  if (kind === 5) check(moved >= 6 && seen.air > 15, `${name}: no leap`);
  if (kind === 6) check(seen.shots === k[10], `${name}: ${seen.shots} arrows, rules ${k[10]}`);
  if (kind === 12 || kind === 18) check(seen.chill > 100, `${name}: no chill`);
  if (kind === 13) check(V('ehp') > 2 + Math.floor(V('emaxhp') * 0.25), `${name}: life ${V('ehp')} of ${V('emaxhp')}`);
  if (kind === 16) check(moved >= 60, `${name}: moved ${moved}`);
  if (kind === 17) check(seen.stun > 60, `${name}: no stun`);
  check(V('est') === 0 || V('est') === 1, `${name}: the hero is left in state ${V('est')}`);
  check(V('casting') === 0xffff && V('spinLeft') === 0 && V('leapLeft') === 0, `${name}: still casting`);
});
// refusals: the wrong weapon, no stamina, nothing learned
ready(6); call('MakeNormal', { a: sword }); call('ItemCopy', { x: 59 * 64, y: 40 * 64 }); call('StatsRecalc'); set('stam', V('maxStam'));
let before = V('stam'); frame(0x4000); frame(); check(V('stam') >= before && V('casting') === 0xffff, 'a bow skill without a bow');
ready(0); set('stam', 1); frame(0x4000); frame(); check(V('casting') === 0xffff && V('est') === 0, 'a skill without stamina');
ready(0); set('skActive', 0xffff); frame(0x4000); frame(); check(V('casting') === 0xffff, 'no skill chosen');
// learning: a point, the level, the skill above
ready(0, 0); set('level', 1); set('skillPts', 1);
check(!call('CanLearn', { a: 2 }).c, 'Battle Cry before its level');
set('level', 6); check(!call('CanLearn', { a: 2 }).c, 'Battle Cry before Bash');
call('Learn', { a: 0 }); check(V('skRank') === 1 && V('skillPts') === 0 && V('skActive') === 0xffff ? false : V('skRank') === 1 && V('skillPts') === 0, 'learning Bash');
set('skillPts', 20); call('Learn', { a: 2 }); check(w(sy.skRank + 4) === 1, 'learning Battle Cry');
// the passives work as the rules say (rank 5 of each)
const pm = (n) => w(sy.pmods + R.enums[n] * 2);
const base = () => ({ enh: pm('K_ENHANCE_DAMAGE_PERCENT'), def: pm('K_DEFENSE_PERCENT'), steal: pm('K_LIFESTEAL_PERCENT'), speed: pm('K_ATTACK_SPEED_PERCENT'), life: pm('K_MAX_LIFE_PERCENT'), crit: pm('K_CRIT_CHANCE_PERCENT'), evade: pm('K_EVADE_CHANCE_PERCENT'), move: pm('K_MOVE_SPEED_PERCENT'), block: pm('K_BLOCK_CHANCE_PERCENT'), fire: pm('K_FIRE_DAMAGE'), regen: pm('K_LIFE_REGEN_PERCENT'), spell: V('spellPm'), stam: V('stamRegen') });
const key = ['enh', 'def', 'steal', 'speed', 'life', 'enh', 'crit', 'evade', 'speed', 'move', 'spell', 'stam', 'block', 'fire', 'regen'];
let passives = 0;
R.skills.forEach((k, i) => {
  if (k[7] !== 20) return;
  const code = Math.floor(k[10]), ranged = code === 5 || code === 8;
  ready(i, 0); call('MakeNormal', { a: ranged ? bow : sword }); call('ItemCopy', { x: 59 * 64, y: 40 * 64 }); call('StatsRecalc');
  const a = base(); pw(sy.skRank + i * 2, 5); call('StatsRecalc'); const b = base();
  let want = Math.floor(5 * k[9]); if (code === 2) want = Math.min(15, want); if (code === 10) want *= 10;
  check(b[key[code]] - a[key[code]] === want, `${k[0]}: ${key[code]} +${b[key[code]] - a[key[code]]}, rules +${want}`);
  passives++;
});
console.log(`${passives} passives checked`);
console.log(fails ? `${fails} checks FAILED` : 'all skill checks pass');
process.exit(fails ? 1 : 0);
