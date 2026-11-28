// The places in the built ROM (the test emulator): every shown tile against the place's data, every gate walked into
// and where it leaves the hero, a walkable way from there to every gate and person, the townspeople's words, the
// merchant, the appraiser, the town portal and rising after death.  node tools/test_places.mjs [--shots]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Snes } from './snes.mjs';
import { boot } from './boot.mjs';
import { world } from './worldcheck.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const rom = fs.readFileSync(path.join(root, 'out', 'anaroch_game.sfc'));
const s = new Snes(rom, { program: 0x200000 });
const sy = JSON.parse(fs.readFileSync(path.join(root, 'out', 'anaroch_game.sym.json'), 'utf8'));
const W = world(s, sy, rom);
const SHOTS = process.argv.includes('--shots');
boot(s, sy);
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
const frames = (n, pad = 0) => { for (let i = 0; i < n; i++) { s.pad = pad; s.runFrame(400000); } };
const press = (pad) => { frames(3, pad); frames(5); };
const shot = (name) => {
  if (!SHOTS) return;
  const ppm = path.join(root, 'out', `place_${name}.ppm`); s.savePPM(ppm);
  execFileSync('python', ['-c', `from PIL import Image; Image.open(r'${ppm}').resize((768,672),Image.NEAREST).save(r'${ppm.replace('.ppm', '.png')}')`]);
  fs.unlinkSync(ppm);
};
const hero = () => [V('ex') >> 4, V('ey') >> 4];
const put = (x, y) => { set('ex', x * 16); set('ey', y * 16); };
const G = (i) => Array.from({ length: 8 }, (_, k) => w(0x1C800 + i * 16 + k * 2));       // x0 z0 x1 z1 to ax az dir
const NAMES = ['graveyard', 'town', 'trade', 'scrip', 'inn'];
const settle = () => { for (let n = 0; n < 200 && (V('mode') === 5 || V('rebuild')); n++) frames(1); frames(4); };

// where the hero can stand (collide.asm CheckFoot: four points round the feet), and everything reachable from a spot
function reach(from) {
  const AW = V('areaW'), AH = V('areaH'), gw = V('gridW');
  const cell = (x, y) => (x < 0 || y < 0 || x >= AW || y >= AH ? 2 : s.wram[0x1A000 + (y >> 4) * gw + (x >> 4)]);
  const free = (x, y) => !cell(x - 4, y - 3) && !cell(x + 4, y - 3) && !cell(x + 4, y + 3) && !cell(x - 4, y + 3);
  const seen = new Set(); const q = [from];
  while (q.length) {
    const [x, y] = q.pop(); const k = y * 4096 + x;
    if (seen.has(k) || !free(x, y)) continue;
    seen.add(k); q.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  return { size: seen.size, has: (x, y) => seen.has(y * 4096 + x), near: (x, y, r) => [...seen].some((k) => Math.hypot((k % 4096) - x, Math.floor(k / 4096) - y) < r) };
}
const inRect = (g, x, y) => x > g[0] && x < g[2] && y > g[1] && y < g[3];
function lookAround(name) {
  const here = hero(), r = reach(here);
  check(r.size > 500, `${name}: the hero stands in a pocket of ${r.size} px at ${here}`);
  for (let i = 0; i < V('nGates'); i++) {
    const g = G(i); let ok = false;
    for (let y = g[1] + 1; y < g[3] && !ok; y++) for (let x = g[0] + 1; x < g[2]; x++) if (r.has(x, y)) { ok = true; break; }
    check(ok, `${name}: no way to the gate to ${NAMES[g[4]]}`);
    check(!inRect(g, ...here), `${name}: arrives inside a gate`);
  }
  for (let m = 1; m < 9; m++) if (V('est', m) === 6) check(r.near(V('ex', m) >> 4, V('ey', m) >> 4, 30), `${name}: no way to person ${m}`);
  const bad = W.tiles();
  check(bad.bad === 0, `${name}: ${bad.bad} of ${bad.checked} tiles wrong ${JSON.stringify(bad.first)}`);
  return bad.checked;
}
function through(i) {                       // into gate i of this place
  const g = G(i);
  put((g[0] + g[2]) >> 1, (g[1] + g[3]) >> 1); frames(2); settle();
  check(V('placeId') === g[4], `gate ${i}: in ${NAMES[V('placeId')]}, not ${NAMES[g[4]]}`);
  const [x, y] = hero(); check(Math.hypot(x - g[5], y - g[6]) < 3, `gate to ${NAMES[g[4]]}: at ${x},${y}, not ${g[5]},${g[6]}`);
}
const people = () => [...Array(8).keys()].map((k) => k + 1).filter((m) => V('est', m) === 6);

// ---------------------------------------------------------------- the town, every gate there and back
check(V('placeId') === 1, 'a new game starts in Stormreach');
check(people().length === 3, `three in the streets: ${people().length}`);
let tiles = lookAround('town'); shot('town');
for (let i = 0; i < 4; i++) {
  const to = G(i)[4];
  through(i);
  tiles += lookAround(NAMES[to]); shot(NAMES[to]);
  check(people().length === [0, 3, 1, 1, 2][to], `${NAMES[to]}: ${people().length} people`);
  if (to === 0) {
    let mon = 0; for (let m = 1; m < 9; m++) if (V('est', m) < 4) mon++;
    check(mon === 8, `graveyard: ${mon} monsters`);
    for (let m = 1; m < 9; m++) set('est', 5, m), set('etm', 0, m);
  }
  const back = [...Array(V('nGates')).keys()].find((k) => G(k)[4] === 1);
  through(back);
  tiles += lookAround('town again');
}
// walked, not placed: out of the west gate and back by the pad
const g0 = G(0); put(g0[2] + 6, (g0[1] + g0[3]) >> 1); frames(2);
for (let n = 0; n < 120 && V('placeId') === 1; n++) frames(1, 0x0200 | 0x0800);      // west on the picture is up and left
settle(); check(V('placeId') === 0, 'walking west out of the town');
console.log(`gates walked; ${tiles} tiles checked`);

// ---------------------------------------------------------------- the portal, from the graveyard
for (let m = 1; m < 9; m++) set('est', 5, m), set('etm', 0, m);
set('edir', 2); const from = hero();
call('MakeThing', { a: 3, y: 0 }); call('ItemCopy', { x: 59 * 64, y: 47 * 64 }); set('beltsel', 0);
press(0x0040); check(V('portalOn') === 1 && w(0x2000 + 47 * 64) === 0, 'reading the portal scroll');
const portal = [V('portalX'), V('portalY')];
check(Math.hypot(portal[0] - from[0], portal[1] - from[1]) > 14, 'the portal opens ahead');
frames(70); shot('portal'); check(V('placeId') === 0, 'not taken while away from it');
put(...portal); frames(2); settle(); check(V('placeId') === 1, 'into the portal: the town');
shot('portal_town'); tiles = lookAround('town by the portal');
put(V('startX') + 26, V('startY') - 16); frames(70); settle();
check(V('placeId') === 0 && V('portalOn') === 0, `back through it: place ${V('placeId')}, portal ${V('portalOn')}`);
check(Math.hypot(hero()[0] - portal[0], hero()[1] - portal[1] - 14) < 3, 'beside where it was');
console.log('portal checked');

// ---------------------------------------------------------------- death: up again in Stormreach, with level and gold
set('gold', 700); set('level', 4); set('ehp', 0); set('est', 4); set('mode', 1); set('modet', 0);
frames(170); press(0x1000); frames(10);
check(V('placeId') === 1 && V('mode') === 0 && V('ehp') === V('emaxhp') && V('gold') === 700 && V('level') === 4, 'rising in town');

// ---------------------------------------------------------------- the people's words
const text = (row) => { let t = ''; for (let c = 0; c < 32; c++) { const e = w(sy.hudmap + (row * 32 + c) * 2) & 0x3FF; t += e >= sy.FONT_BASE && e < sy.FONT_BASE + 50 ? " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/:+-.()>'!%,?"[e - sy.FONT_BASE] : ' '; } return t.trim(); };
const standBy = (m) => { const x = V('ex', m) >> 4, y = V('ey', m) >> 4; const r = reach(hero()); for (let d = 14; d < 36; d += 2) for (const [dx, dy] of [[0, 1], [1, 0], [-1, 0], [0, -1], [1, 1], [-1, 1]]) if (r.has(x + dx * d, y + dy * d)) { put(x + dx * d, y + dy * d); frames(3); return true; } return false; };
const hear = (n) => { const m = people()[n]; set('ewt', 0, m); set('ecool', 600, m); check(standBy(m), 'a place beside them'); frames(3); const asks = text(21); press(0x0080); return { asks, name: text(3), words: [4, 5, 6, 7].map(text).join(' ').trim() }; };
const oda = hear(0); check(oda.asks === 'A  TALK TO ODA THE FARMER' && oda.name === 'ODA THE FARMER' && oda.words.startsWith('GIDEON TRADES'), `Oda: ${JSON.stringify(oda)}`); shot('talk');
press(0x0080); check([4, 5, 6, 7].map(text).join(' ').startsWith('NOTHING GROWS'), 'her next words');
for (let n = 1; n < 3; n++) { const t = hear(n); check(t.name && t.words, `street ${n}: ${JSON.stringify(t)}`); console.log(`  ${t.name}: ${t.words}`); }
frames(400); check(text(3) === '', 'the words go');
through(3); for (let n = 0; n < 2; n++) { const t = hear(n); check(t.name && t.words, `inn ${n}: ${JSON.stringify(t)}`); console.log(`  ${t.name}: ${t.words}`); }
shot('talk_inn');
through(0);

// ---------------------------------------------------------------- the merchant
through(1); set('gold', 1000);
const bag = () => [...Array(40).keys()].map((i) => i * 64).filter((o) => w(0x2000 + o));
const wares = () => [...Array(24).keys()].map((i) => (64 + i) * 64).filter((o) => w(0x2000 + o));
check(wares().length === 17, `his table holds ${wares().length}`);
const g = hear(0); check(g.asks === 'A  TRADE WITH GIDEON', `his prompt: ${g.asks}`);
check(V('mode') === 4 && V('bagPage') === 2, 'the trade screen'); frames(10); shot('shop');
const had = bag().length;
press(0x0080); check(V('gold') === 970 && bag().length === had + 1, `a potion for 30: gold ${V('gold')}, bag ${bag().length}`);
check(wares().length === 17, 'the potions do not run out');
// every price against items.c item_value
const value = (o) => {
  const f = (k) => w(0x2000 + o + k); const kind = f(0), base = f(4);
  if (kind === 2) return base === 2 ? 3000 : 30;
  if (kind === 4) return 75;
  if (kind === 3) return base >= 2 ? 3000 : base === 0 ? 60 : 45;
  const L = f(6) || 1, v = 20 + 6 * L + Math.floor(L * L / 4), r = f(2);
  return r === 0 ? Math.floor(v * 2 / 5) : r === 2 ? Math.floor(v * (25 + 4 * f(14)) / 10) : r === 3 ? v * 5 : r === 4 ? v * 10 : v;
};
for (const o of wares()) { const got = call('ItemValue', { a: o }).a; check(got === value(o), `price of the ware at ${o}: ${got}, rules ${value(o)}`); }
for (let i = 0; i < 5; i++) press(0x0400);
const cost = value(wares()[5]);
const gear = w(sy.shopCur); const before = V('gold'); press(0x0080); frames(5); shot('shop_gear');
check(gear === 5 && V('gold') < before && wares().length === 16 && bag().length === had + 2, `a piece of gear: gold ${before} -> ${V('gold')}, table ${wares().length}`);
const paid = before - V('gold');
check(paid === cost, `paid ${paid}, the price ${cost}`);
press(0x0020); check(V('shopSell') === 1, 'the selling side'); shot('shop_sell');
const g1 = V('gold'), n1 = bag().length;
press(0x0080); check(V('gold') === g1 && bag().length === n1, 'once only asks');
press(0x0080); check(V('gold') > g1 && bag().length === n1 - 1, `sold: gold ${g1} -> ${V('gold')}`);
set('gold', 2); press(0x0020); for (let i = 0; i < 5; i++) press(0x0400); press(0x0080); check(V('gold') === 2, 'too dear');
press(0x8000); frames(10); check(V('mode') === 0, 'leaving the table'); tiles = lookAround('trade after the shop');
console.log(`merchant checked (a piece cost ${paid})`);
through(0);

// ---------------------------------------------------------------- the appraiser
through(2);
for (const o of bag()) call('ItemClear', { x: o });
call('BagRebuild');
const unread = (at, level) => { call('MakeNormal', { a: 1 }); pw(0x2000 + 59 * 64 + 2, 3); pw(0x2000 + 59 * 64 + 6, level); pw(0x2000 + 59 * 64 + 8, 0); call('ItemCopy', { x: 59 * 64, y: at }); };
unread(0, 5); unread(64, 10);                     // two Rares: (40 + 4 L) * 3 / 2 = 90 and 120
set('gold', 100);
let a = hear(0); check(a.asks === 'A  TALK TO BROTHER ANSEL' && a.words.startsWith('2 TO READ: 210 GOLD'), `quote: ${a.words}`); shot('appraise');
press(0x0080); check(w(0x2000 + 8) === 1 && w(0x2000 + 64 + 8) === 0 && V('gold') === 10, `the cheaper one read: gold ${V('gold')}`);
console.log(`  ${text(3)}: ${text(4)}`);
set('gold', 5); frames(10); press(0x0080); press(0x0080); check(text(4) === 'YOU CANNOT PAY FOR ONE', `no gold: ${text(4)}`);
set('gold', 500); press(0x0080); press(0x0080); check(w(0x2000 + 64 + 8) === 1 && V('gold') === 380, `the other: gold ${V('gold')}`);
press(0x0080); check(text(4) === 'YOUR PACK HOLDS NO SECRETS', `nothing left: ${text(4)}`);
press(0x8000); through(0);

// ---------------------------------------------------------------- blows and skills pass the townspeople by
const m = people()[0]; set('ewt', 0, m); set('ecool', 900, m); set('level', 30);
check(standBy(m), 'beside a townsperson');
const gold0 = V('gold'), kills0 = V('kills');
for (const k of [0, 3, 13, 15, 23, 35]) {
  for (let i = 0; i < 36; i++) set('skRank', 3, i);
  set('skActive', k); set('stam', V('maxStam'));
  put((V('ex', m) >> 4), (V('ey', m) >> 4) - 18); set('edir', 0);
  frames(3, 0x4000); frames(80); frames(3, 0x8000); frames(60);
}
check(V('est', m) === 6 && V('ekind', m) >= 3 && V('estun', m) === 0 && V('kills') === kills0 && V('gold') === gold0, `a townsperson after blows: state ${V('est', m)}, stun ${V('estun', m)}`);

// ---------------------------------------------------------------- the portal scroll: not in town; from the bag in the field
const scroll = (at) => { call('MakeThing', { a: 3, y: 0 }); call('ItemCopy', { x: 59 * 64, y: at }); };
scroll(47 * 64); set('beltsel', 0); press(0x0040); frames(4);
check(V('portalOn') === 0 && w(0x2000 + 47 * 64) === 3 && text(20) !== '', 'no portal in town, the scroll kept');
through(0);
for (let k = 1; k < 9; k++) set('est', 5, k), set('etm', 0, k);
for (const o of bag()) call('ItemClear', { x: o });
scroll(0); call('BagRebuild');
press(0x2000); frames(20); check(V('mode') === 4, 'the bag');
press(0x0040); frames(10);
check(V('mode') === 0 && V('portalOn') === 1 && w(0x2000) === 0, `read from the bag: mode ${V('mode')}, portal ${V('portalOn')}`);
console.log('townspeople unharmed; portal scroll checked');
console.log(fails ? `${fails} checks FAILED` : 'all place checks pass');
process.exit(fails ? 1 : 0);
