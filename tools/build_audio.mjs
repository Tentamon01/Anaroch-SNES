// node tools/build_audio.mjs [seconds]  -> out/audio/spc.bin (loaded at $0200, entry $0200), song_preview.wav
// "Ashes Under the Yew": the graveyard's track, an original piece in a dark ambient style: a low drone, a slow choir,
// a sparse bell with long echoes, a thin glass voice in the second half, a heartbeat drum and wind.
// Every instrument is synthesised here; nothing is sampled from anywhere.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { assembleSpc, brrEncode, renderSpc, wav } from './spc700.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out = path.join(root, 'out', 'audio');
fs.mkdirSync(out, { recursive: true });
const TAU = Math.PI * 2;
let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;

// ---------------------------------------------------------------- instruments
const norm = (f, peak) => { const m = Math.max(...f.map(Math.abs)) || 1; return f.map((v) => Math.round((v / m) * peak)); };
// a looped pad: partials given as [cycles in the loop, level], all whole numbers of cycles so the loop is seamless
const pad = (n, partials, peak) => { const ph = partials.map(() => rnd() * TAU); return norm(Array.from({ length: n }, (_, i) => partials.reduce((s, [c, a], k) => s + a * Math.sin((TAU * c * i) / n + ph[k]), 0)), peak); };

// low strings: a soft saw, three voices a cycle apart (one slow beat)
const strings = () => { const p = []; for (let h = 1; h <= 9; h++) for (const d of [-1, 0, 1]) p.push([32 * h + d, (d ? 0.45 : 1) / Math.pow(h, 1.5)]); return pad(4096, p, 17000); };
// choir "ah": the harmonics of a 250 Hz voice shaped by an open vowel's formants, with detuned singers
const choir = () => {
  const p = [];
  for (let h = 1; h <= 14; h++) {
    const f = 250 * h, a = (1.0 * Math.exp(-(((f - 720) / 220) ** 2)) + 0.65 * Math.exp(-(((f - 1150) / 260) ** 2)) + 0.22 * Math.exp(-(((f - 2750) / 420) ** 2)) + 0.35 / (h * h));
    for (const d of [-2, -1, 0, 1]) p.push([64 * h + d, a * (d === 0 ? 1 : d === -2 ? 0.3 : 0.55)]);
  }
  return pad(8192, p, 15000);
};
const sub = () => pad(512, [[4, 1], [8, 0.32], [12, 0.12], [16, 0.05]], 20000);
// a dim bell: inharmonic partials dying away into a quiet looping tone (the envelope fades the rest)
const bell = () => {
  const head = 3072, loop = 256;
  const f = Array.from({ length: head + loop }, (_, i) => {
    const t = Math.min(i, head), e = (k) => Math.exp((-t * k) / head);
    const x = (TAU * i) / 64;                          // the fundamental: 64 samples a cycle
    return Math.sin(x) * (0.35 + 0.65 * e(1.6)) + 0.55 * Math.sin(x * 2.76) * e(4) + 0.3 * Math.sin(x * 5.4) * e(7) + 0.18 * Math.sin(x * 8.93) * e(10) + 0.12 * Math.sin(x * 2) * e(2);
  });
  // the loop: only the periodic part, matched to the end of the head
  for (let i = head; i < head + loop; i++) f[i] = 0.35 * Math.sin((TAU * i) / 64) + 0.012 * Math.sin((TAU * i * 2) / 64);
  for (let i = head - 512; i < head; i++) { const k = (i - (head - 512)) / 512; f[i] = f[i] * (1 - k) + (0.35 * Math.sin((TAU * i) / 64)) * k; }
  return norm(f, 19000);
};
// glass: an almost pure voice with a slow shimmer
const glass = () => pad(2048, [[32, 1], [64, 0.14], [96, 0.07], [31, 0.22], [33, 0.12], [160, 0.025]], 15000);
// a heartbeat drum: a low thud falling in pitch, with a breath of noise
const drum = () => { let ph = 0, lp = 0; return norm(Array.from({ length: 4800 }, (_, i) => { const t = i / 4800; ph += (TAU * (92 - 48 * Math.min(1, t * 3))) / 32000; lp += (rnd() * 2 - 1 - lp) * 0.08; return (Math.sin(ph) + lp * 1.6 * Math.exp(-t * 18)) * Math.exp(-t * 5) * Math.min(1, i / 40); }), 24000); };
const noiseStub = () => new Array(16).fill(0);

// name, wave, loop start (-1 none), samples per cycle at pitch $1000
const INSTR = [
  ['strings', strings(), 0, 128], ['choir', choir(), 0, 128], ['sub', sub(), 0, 128],
  ['bell', bell(), 3072, 64], ['glass', glass(), 0, 64], ['drum', drum(), -1, 128], ['noise', noiseStub(), 0, 128],
];
const I = Object.fromEntries(INSTR.map(([n], i) => [n, i]));

// ---------------------------------------------------------------- sound effects, synthesised at 16 kHz
const RATE = 16000;
const fx = (seconds, f, peak = 26000) => { const n = Math.round((seconds * RATE) / 16) * 16; return norm(Array.from({ length: n }, (_, i) => f(i / RATE, i / n) * Math.min(1, (n - i) / 160)), peak); };
const white = () => rnd() * 2 - 1;
// a resonant band: centre f Hz (may change), width q
const band = () => { let a = 0, b = 0; return (x, f, q = 0.25) => { const k = 2 * Math.sin((Math.PI * f) / RATE); const hi = x - a * 1 - b * q; b += k * hi; a += k * b; return b; }; };
const low = () => { let y = 0; return (x, k) => (y += (x - y) * k); };
const sweep = () => { let ph = 0; return (f) => { ph += (TAU * f) / RATE; return ph; }; };
const saw = (ph) => ((ph / TAU) % 1) * 2 - 1;
const swingFx = () => { const bp = band(); return fx(0.17, (t, k) => bp(white(), 600 + 2200 * Math.sin(Math.PI * k) ** 2, 0.35) * Math.sin(Math.PI * k) ** 2, 21000); };
const hitFx = () => { const s = sweep(), lp = low(), bp = band(); return fx(0.16, (t, k) => Math.sin(s(170 - 110 * Math.min(1, k * 2))) * Math.exp(-t * 22) + 1.4 * lp(white(), 0.5) * Math.exp(-t * 55) + 0.5 * bp(white(), 1400, 0.4) * Math.exp(-t * 30)); };
const hurtFx = () => { const s = sweep(), bp = band(), bp2 = band(); return fx(0.22, (t, k) => { const v = saw(s(185 - 75 * k)) + 0.35 * white(); return (bp(v, 620, 0.3) + 0.6 * bp2(v, 1100, 0.3)) * Math.min(1, t * 90) * Math.exp(-t * 9); }); };
const dieFx = () => { const s = sweep(), lp = low(), bp = band(); return fx(0.42, (t, k) => { const v = saw(s(150 - 105 * k)) * (0.6 + 0.4 * Math.sin(TAU * 27 * t)) + 0.5 * white() * (1 - k); return (lp(v, 0.16) + 0.5 * bp(v, 500 - 300 * k, 0.25)) * Math.min(1, t * 60) * Math.exp(-t * 4.5); }); };
const bowFx = () => { const s = sweep(), bp = band(); return fx(0.15, (t) => { const ph = s(310 - 40 * t); return (Math.sin(ph) + 0.5 * Math.sin(ph * 2.01) + 0.25 * Math.sin(ph * 3.9)) * Math.exp(-t * 28) + 0.8 * bp(white(), 2600, 0.4) * Math.exp(-t * 70); }, 21000); };
const pickFx = () => fx(0.2, (t) => { const f = t < 0.06 ? 880 : 1320, u = t < 0.06 ? t : t - 0.06; return (Math.sin(TAU * f * t) + 0.25 * Math.sin(TAU * f * 2.76 * t)) * Math.exp(-u * 20) * Math.min(1, u * 900); }, 20000);
const drinkFx = () => { const s = sweep(); return fx(0.33, (t) => { const u = t % 0.11; return Math.sin(s(210 + 3600 * u)) * Math.sin(Math.PI * Math.min(1, u / 0.085)) ** 2; }, 22000); };
const levelFx = () => fx(0.55, (t) => [[587, 0], [880, 0.09], [1175, 0.18]].reduce((a, [f, at]) => { const u = t - at; return u < 0 ? a : a + (Math.sin(TAU * f * u) + 0.3 * Math.sin(TAU * f * 2 * u) + 0.15 * Math.sin(TAU * f * 2.76 * u)) * Math.exp(-u * 6) * Math.min(1, u * 600); }, 0), 22000);
const screamFx = () => { const s = sweep(), bp = band(), bp2 = band(), bp3 = band(); return fx(0.62, (t, k) => { const f = 430 + 330 * Math.min(1, t * 5) - 260 * Math.max(0, k - 0.55) + 14 * Math.sin(TAU * 11 * t); const v = saw(s(f)) + 0.45 * white(); return (bp(v, 900, 0.22) + 0.8 * bp2(v, 1500, 0.2) + 0.45 * bp3(v, 2700, 0.25)) * Math.min(1, t * 40) * (1 - 0.7 * k * k); }); };
const SOUNDS = [['scream', screamFx()], ['swing', swingFx()], ['hit', hitFx()], ['hurt', hurtFx()], ['die', dieFx()], ['bow', bowFx()], ['pick', pickFx()], ['drink', drinkFx()], ['level', levelFx()]];
const S = Object.fromEntries(SOUNDS.map(([n], i) => [n, INSTR.length + i]));
// the effects in the game's order (a higher number wins when two are asked for in one frame): name, sound, pitch, volume, spread
const EFFECTS = [
  ['swing', 'swing', 0x800, 46, 0x7f], ['coin', 'pick', 0xb00, 40, 0x3f], ['bow', 'bow', 0x800, 44, 0x7f], ['pickup', 'pick', 0x800, 52, 0],
  ['hit', 'hit', 0x800, 72, 0x7f], ['drink', 'drink', 0x800, 56, 0], ['hurt', 'hurt', 0x800, 70, 0x3f], ['mdie', 'die', 0x800, 66, 0x7f],
  ['level', 'level', 0x800, 64, 0], ['herodie', 'die', 0x500, 90, 0],
  ['growl', 'die', 0x5a0, 84, 0], ['scream', 'scream', 0x800, 80, 0],
];
const sfxtab = EFFECTS.flatMap(([, snd, pitch, vol, mask]) => {
  const ticks = Math.min(255, Math.ceil((SOUNDS[S[snd] - INSTR.length][1].length / RATE) * (0x800 / pitch) * 200) + 2);
  return [S[snd], pitch & 255, pitch >> 8, vol, 0x8f, 0xe0, ticks, mask];
});

// ---------------------------------------------------------------- the song
const TICKS_PER_BEAT = 192;                 // 200 ticks a second: 62.5 beats a minute
const NOTE = { C: 0, 'C#': 1, Db: 1, D: 2, Eb: 3, E: 4, F: 5, 'F#': 6, G: 7, 'G#': 8, Ab: 8, A: 9, Bb: 10, B: 11 };
const hz = (name) => { const m = /^([A-G][#b]?)(\d)$/.exec(name); return 440 * Math.pow(2, (NOTE[m[1]] + (+m[2] + 1) * 12 - 69) / 12); };
const events = [];                          // [tick, order, bytes]
const at = (beat, order, bytes) => events.push([Math.round(beat * TICKS_PER_BEAT), order, bytes]);
const echoPitch = (name, instr) => { const p = Math.round((hz(name) * INSTR[instr][3] * 4096) / 32000); if (p > 0x3fff) throw new Error('too high: ' + name); return p; };
// envelope bytes: attack 0..15 (15 fastest), decay 0..7, sustain level 0..7, sustain fall 0..31
const env = (a, d, sl, sr) => [0x80 | (d << 4) | a, (sl << 5) | sr];
function note(v, beat, beats, name, instr, vol, e, { pan = 0, release = 0xaf } = {}) {
  const p = instr === I.drum ? Math.round(4096 * hz(name) / hz('D2')) : echoPitch(name, instr);
  const l = Math.round(vol * Math.min(1, 1 - pan)), r = Math.round(vol * Math.min(1, 1 + pan));
  at(beat, 2, [1, v, p & 255, p >> 8, instr, l, r, ...e]);
  if (release !== null) at(beat + beats - 0.02, 1, [2, v, release]);
}
const BARS = 16, BAR = 4;
// harmony, a bar or two each: the bass, a low fifth, and two choir voices
const chords = [
  // bar, bars, bass,  strings, choir low, choir high
  [0, 4, 'D1', 'A2', 'D3', 'F3'],
  [4, 2, 'D1', 'Bb2', 'D3', 'E3'],
  [6, 2, 'D1', 'A2', 'C#3', 'E3'],
  [8, 2, 'Bb1', 'F2', 'D3', 'A3'],
  [10, 2, 'Eb1', 'Bb2', 'D3', 'G3'],
  [12, 2, 'G1', 'D3', 'Bb2', 'F3'],
  [14, 1, 'A1', 'E3', 'Bb2', 'D3'],
  [15, 1, 'A1', 'E3', 'A2', 'C#3'],
];
for (const [bar, bars, bass, str, lo, hi] of chords) {
  const b = bar * BAR, len = bars * BAR;
  note(0, b, len, bass, I.sub, 34, env(7, 3, 7, 0));
  note(1, b, len, str, I.strings, 24, env(5, 2, 7, 0), { pan: -0.35, release: 0xb1 });
  note(2, b + 0.06, len - 0.06, lo, I.choir, 26, env(4, 1, 7, 0), { pan: 0.45, release: 0xb2 });
  note(3, b + 0.5, len - 0.5, hi, I.choir, 22, env(3, 1, 7, 0), { pan: -0.5, release: 0xb2 });
}
// the bell: a few notes with room round them
const bellLine = [[2.0, 'D5', -0.4], [3.5, 'A5', 0.35], [9.0, 'Bb5', 0.5], [10.5, 'F5', -0.2], [17.0, 'E5', 0.3], [19.5, 'D5', -0.45], [25.0, 'C#5', 0.2], [26.5, 'E5', -0.3], [30.0, 'A4', 0.0],
  [34.0, 'D5', -0.4], [35.5, 'A5', 0.35], [43.0, 'G5', 0.45], [51.0, 'Bb4', -0.3], [59.5, 'E5', 0.4], [62.0, 'C#5', -0.2]];
for (const [b, n, pan] of bellLine) note(4, b, 2.6, n, I.bell, 48, env(15, 6, 5, 17), { pan, release: 0xb4 });
// the glass voice: the tune, in the second half
const tune = [[32, 3, 'A4'], [35, 1, 'Bb4'], [36, 2.5, 'A4'], [38.5, 0.75, 'F4'], [39.25, 0.75, 'E4'], [40, 4, 'D4'], [44, 2, 'F4'], [46, 2, 'G4'],
  [48, 3, 'Bb4'], [51, 1, 'A4'], [52, 2, 'G4'], [54, 2, 'D4'], [56, 2.5, 'E4'], [58.5, 1.5, 'F4'], [60, 4, 'E4']];
for (const [b, len, n] of tune) note(5, b, len, n, I.glass, 30, env(8, 2, 6, 6), { pan: 0.1, release: 0xb0 });
// a second, soft answer from the glass in the first half
for (const [b, len, n] of [[12, 2, 'A4'], [14, 2, 'G#4'], [22, 3, 'F4'], [27, 3, 'E4']]) note(5, b, len, n, I.glass, 17, env(6, 2, 6, 5), { pan: -0.25, release: 0xb0 });
// the heartbeat, every other bar; heavier at the turn
for (let bar = 0; bar < BARS; bar += 2) {
  note(6, bar * BAR, 0.6, 'D2', I.drum, 56, env(15, 7, 7, 0), { release: null });
  note(6, bar * BAR + 0.55, 0.6, 'C2', I.drum, 34, env(15, 7, 7, 0), { release: null });
}
for (const b of [30.5, 31, 62.5, 63, 63.5]) note(6, b, 0.4, 'A1', I.drum, 30, env(15, 7, 7, 0), { release: null });
// the wind: noise on voice 7, swelling and dropping all through
at(0, 2, [1, 7, 0, 0x10, I.noise, 2, 2, ...env(2, 1, 7, 0)]);
for (let b = 0; b < BARS * BAR; b++) {
  const swell = 3.2 + 2.6 * Math.sin((b / 13) * TAU) + 1.2 * Math.sin((b / 5) * TAU);
  at(b + 0.01, 3, [3, 7, Math.max(1, Math.round(swell * (1 + 0.5 * Math.sin(b / 7)))), Math.max(1, Math.round(swell * (1 - 0.5 * Math.sin(b / 7))))]);
}

// compile to the driver's stream
events.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
const stream = [];
let now = 0;
const wait = (to) => { let d = to - now; while (d > 0) { const w = Math.min(255, d); stream.push(0, w); d -= w; } now = to; };
for (const [t, , bytes] of events) { if (t >= BARS * BAR * TICKS_PER_BEAT) continue; wait(t); stream.push(...bytes); }
wait(BARS * BAR * TICKS_PER_BEAT);
stream.push(5);

// ---------------------------------------------------------------- memory and the driver
const DIR = 0x0200 >> 8;                     // the sample directory: page 2; the code from $0300
const ECHO_START = 0xc000, EDL = 8;          // 128 ms of echo, 16 KB at the top
const dsptab = [
  [0x6c, 0x60], [0x4c, 0], [0x5c, 0xff], [0x5c, 0], [0x5d, DIR], [0x0c, 0x70], [0x1c, 0x70], [0x2c, 0x34], [0x3c, 0x34], [0x0d, 0x46],
  [0x6d, ECHO_START >> 8], [0x7d, EDL], [0x4d, 0b10111110], [0x3d, 0x80], [0x2d, 0],
  ...[0x0c, 0x21, 0x2b, 0x2b, 0x13, 0xfe, 0xf3, 0xf9].map((v, i) => [i * 16 + 15, v]),
];
const CODE = 0x0300;
// the tables follow the code (bits, the DSP settings, the song); assembled once to find where the code ends
const build = (songAt, loopAt, dspAt, fxAt, hold = 0) => assembleSpc(`NOISECLK = $0e\nHOLDSTART = ${hold}\nsong = ${songAt}\nsongloop = ${loopAt}\ndsptab = ${dspAt}\nsfxtab = ${fxAt}\n` + fs.readFileSync(path.join(root, 'src', 'spc_driver.s'), 'utf8'), CODE);
let probe = build(0x2000, 0x2000, 0x1000, 0x1000);
const bitsAt = CODE + probe.code.length, dspAt = bitsAt + 8, fxAt = dspAt + dsptab.length * 2 + 1, songAt = fxAt + sfxtab.length;
const { code, labels } = build(songAt, songAt, dspAt, fxAt);
if (code.length !== probe.code.length) throw new Error('driver size changed between passes');
const image = new Uint8Array(0x10000);
image.set(code, CODE);
image.set([1, 2, 4, 8, 16, 32, 64, 128], bitsAt);
image.set(dsptab.flat().concat(0xff), dspAt);
image.set(sfxtab, fxAt);
image.set(stream, songAt);
let free = (songAt + stream.length + 0xff) & ~0xff;
[...INSTR, ...SOUNDS.map(([n, w]) => [n, w, -1])].forEach(([name, wave, loop], i) => {
  const brr = brrEncode(wave, loop);
  const start = free; free += brr.length;
  const lp = loop >= 0 ? start + (loop / 16) * 9 : start;
  image.set(brr, start);
  image.set([start & 255, start >> 8, lp & 255, lp >> 8], DIR * 256 + i * 4);
  console.log(`  ${name.padEnd(8)} ${brr.length} bytes at ${start.toString(16)}`);
});
if (free > ECHO_START) throw new Error(`sound memory full: ${free.toString(16)} past ${ECHO_START.toString(16)}`);
// the upload starts at $0200; the first bytes of the driver's entry are at $0300
const upload = Buffer.from(image.slice(0x0200, free));
fs.writeFileSync(path.join(out, 'spc.bin'), upload);
fs.writeFileSync(path.join(out, 'spc_0.bin'), upload.subarray(0, 0x8000));          // (the game's ROM banks hold 32 KB)
fs.writeFileSync(path.join(out, 'spc_1.bin'), upload.length > 0x8000 ? upload.subarray(0x8000) : Buffer.alloc(1));
fs.writeFileSync(path.join(out, 'spc.json'), JSON.stringify({ load: 0x0200, entry: CODE, size: upload.length, seconds: (BARS * BAR * TICKS_PER_BEAT) / 200 }));
console.log(`driver ${code.length} B, song ${stream.length} B, upload ${upload.length} B of ${ECHO_START - 0x200}, loop ${(BARS * BAR * TICKS_PER_BEAT) / 200} s`);

// the same image with the music playing from the start: for the chip test (which never asks for it) and the previews
const played = Buffer.from(image.slice(0x0200, free));
build(songAt, songAt, dspAt, fxAt, 1).code.copy(played, CODE - 0x0200);
fs.writeFileSync(path.join(out, 'spc_chip.bin'), played.subarray(0, 0x8000));

// ---------------------------------------------------------------- the preview
const secs = +(process.argv[2] || 72);
const r = renderSpc(played, 0x0200, CODE, secs);
fs.writeFileSync(path.join(out, 'song_preview.wav'), wav(r.samples));
let peak = 0, clipped = 0; const rms = [];
for (let s = 0; s < r.samples.length; s += 2) { const v = Math.abs(r.samples[s]); peak = Math.max(peak, v); if (v >= 32760) clipped++; }
for (let t = 0; t + 8 <= secs; t += 8) { let sum = 0; for (let s = t * 64000; s < (t + 8) * 64000; s++) sum += r.samples[s] ** 2; rms.push(Math.round(Math.sqrt(sum / 512000))); }
console.log(`preview ${secs} s: peak ${peak}, clipped samples ${clipped}, loudness per 8 s ${rms.join(' ')}; driver ports ${r.ports.join(' ')}`);

// each effect in turn, a second and a half apart, over the music
const asks = EFFECTS.flatMap((_, i) => [[2 + i * 1.5, 1, i + 1], [2.001 + i * 1.5, 2, i + 1]]);
const f = renderSpc(played, 0x0200, CODE, 2 + EFFECTS.length * 1.5, asks);
fs.writeFileSync(path.join(out, 'effects_preview.wav'), wav(f.samples));
const plain = renderSpc(played, 0x0200, CODE, 2 + EFFECTS.length * 1.5);
const diff = EFFECTS.map(([n], i) => { const a = Math.round((2 + i * 1.5) * 32000) * 2; let m = 0; for (let s = a; s < a + 16000; s++) m = Math.max(m, Math.abs(f.samples[s] - plain.samples[s])); return `${n} ${m}`; });
console.log('effects heard (largest change in the quarter second after each):', diff.join(', '));
