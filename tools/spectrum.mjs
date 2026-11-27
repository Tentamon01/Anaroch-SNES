// node tools/spectrum.mjs <file.wav> <out.pgm>: a log-frequency spectrogram, to look at what a track holds
import fs from 'node:fs';
const [file, outFile] = process.argv.slice(2);
const b = fs.readFileSync(file); const n = (b.length - 44) / 4;
const mono = new Float64Array(n); for (let i = 0; i < n; i++) mono[i] = (b.readInt16LE(44 + i * 4) + b.readInt16LE(46 + i * 4)) / 2;
const N = 4096, HOP = 2048;
function fft(re, im) {
  for (let i = 1, j = 0; i < N; i++) { let bit = N >> 1; for (; j & bit; bit >>= 1) j ^= bit; j ^= bit; if (i < j) { [re[i], re[j]] = [re[j], re[i]]; } }
  for (let len = 2; len <= N; len <<= 1) { const a = -2 * Math.PI / len; for (let i = 0; i < N; i += len) for (let k = 0; k < len / 2; k++) { const c = Math.cos(a * k), s = Math.sin(a * k), x = i + k, y = x + len / 2; const tr = re[y] * c - im[y] * s, ti = re[y] * s + im[y] * c; re[y] = re[x] - tr; im[y] = im[x] - ti; re[x] += tr; im[x] += ti; } }
}
const cols = Math.floor((n - N) / HOP), rows = 360, img = Buffer.alloc(cols * rows); const mags = [];
let max = 1;
for (let c = 0; c < cols; c++) { const re = new Float64Array(N), im = new Float64Array(N); for (let i = 0; i < N; i++) re[i] = mono[c * HOP + i] * (0.5 - 0.5 * Math.cos(2 * Math.PI * i / N)); fft(re, im); const m = Array.from({ length: N / 2 }, (_, k) => Math.hypot(re[k], im[k])); mags.push(m); for (const v of m) if (v > max) max = v; }
for (let r = 0; r < rows; r++) { const f0 = 30 * Math.pow(8000 / 30, r / rows), f1 = 30 * Math.pow(8000 / 30, (r + 1) / rows); const k0 = Math.floor(f0 * N / 32000), k1 = Math.max(k0 + 1, Math.ceil(f1 * N / 32000));
  for (let c = 0; c < cols; c++) { let v = 0; for (let k = k0; k < k1; k++) v = Math.max(v, mags[c][k]); const db = 20 * Math.log10(v / max + 1e-9); img[(rows - 1 - r) * cols + c] = Math.round(255 * Math.max(0, Math.min(1, (db + 60) / 60))); } }
fs.writeFileSync(outFile, Buffer.concat([Buffer.from(`P5\n${cols} ${rows}\n255\n`), img]));
