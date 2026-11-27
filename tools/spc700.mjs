// The sound side of the SNES for this project: a small SPC700 assembler (the instructions the driver uses), and a
// preview player (that CPU subset, its timer, and an approximation of the S-DSP: BRR, pitch, ADSR/gain, noise, echo
// with its FIR) that renders the driver's output to samples. The preview is close, not bit-exact; ares is the reference.

// opcode, mnemonic, operand pattern. d = direct page, a = absolute, i = immediate, r = relative
const OPS = [
  [0xe8, 'mov', 'a,#i'], [0xe4, 'mov', 'a,d'], [0xe5, 'mov', 'a,!a'], [0xf4, 'mov', 'a,d+x'], [0xf5, 'mov', 'a,!a+x'], [0xf6, 'mov', 'a,!a+y'], [0xf7, 'mov', 'a,[d]+y'],
  [0xcd, 'mov', 'x,#i'], [0x8d, 'mov', 'y,#i'], [0xf8, 'mov', 'x,d'], [0xeb, 'mov', 'y,d'], [0xc4, 'mov', 'd,a'], [0xc5, 'mov', '!a,a'], [0xd4, 'mov', 'd+x,a'], [0xd5, 'mov', '!a+x,a'], [0xd6, 'mov', '!a+y,a'],
  [0xd8, 'mov', 'd,x'], [0xcb, 'mov', 'd,y'], [0x8f, 'mov', 'd,#i'], [0x7d, 'mov', 'a,x'], [0x5d, 'mov', 'x,a'], [0xdd, 'mov', 'a,y'], [0xfd, 'mov', 'y,a'], [0xbd, 'mov', 'sp,x'],
  [0xba, 'movw', 'ya,d'], [0xda, 'movw', 'd,ya'], [0x3a, 'incw', 'd'], [0x7a, 'addw', 'ya,d'],
  [0x88, 'adc', 'a,#i'], [0x84, 'adc', 'a,d'], [0xa8, 'sbc', 'a,#i'], [0xa4, 'sbc', 'a,d'], [0x68, 'cmp', 'a,#i'], [0x64, 'cmp', 'a,d'], [0xc8, 'cmp', 'x,#i'], [0xad, 'cmp', 'y,#i'], [0x3e, 'cmp', 'x,d'],
  [0x28, 'and', 'a,#i'], [0x24, 'and', 'a,d'], [0x08, 'or', 'a,#i'], [0x04, 'or', 'a,d'], [0x48, 'eor', 'a,#i'],
  [0xbc, 'inc', 'a'], [0x9c, 'dec', 'a'], [0x3d, 'inc', 'x'], [0x1d, 'dec', 'x'], [0xfc, 'inc', 'y'], [0xdc, 'dec', 'y'], [0xab, 'inc', 'd'], [0x8b, 'dec', 'd'],
  [0x1c, 'asl', 'a'], [0x5c, 'lsr', 'a'], [0x9f, 'xcn', 'a'], [0xcf, 'mul', 'ya'],
  [0x2d, 'push', 'a'], [0x4d, 'push', 'x'], [0x6d, 'push', 'y'], [0xae, 'pop', 'a'], [0xce, 'pop', 'x'], [0xee, 'pop', 'y'],
  [0x60, 'clrc', ''], [0x80, 'setc', ''], [0x20, 'clrp', ''], [0xc0, 'di', ''],
  [0x2f, 'bra', 'r'], [0xf0, 'beq', 'r'], [0xd0, 'bne', 'r'], [0xb0, 'bcs', 'r'], [0x90, 'bcc', 'r'], [0x30, 'bmi', 'r'], [0x10, 'bpl', 'r'], [0xfe, 'dbnz', 'y,r'], [0x6e, 'dbnz', 'd,r'],
  [0x5f, 'jmp', '!a'], [0x3f, 'call', '!a'], [0x6f, 'ret', ''],
];

export function assembleSpc(source, origin) {
  const lines = source.split(/\r?\n/).map((l) => l.replace(/;.*/, '').trim()).filter(Boolean);
  let labels = {};
  const pass = (final) => {
    const out = []; const found = { ...labels };
    const ev = (s) => {
      const js = s.trim().replace(/\$([0-9a-fA-F]+)/g, '0x$1').replace(/\b([A-Za-z_]\w*)\b/g, (m, n) => {
        if (/^0x/i.test(m)) return m; if (n in found) return found[n]; if (final) throw new Error('undefined ' + n); return 0x200;
      });
      return Function(`"use strict"; return (${js});`)();
    };
    for (let line of lines) {
      let m = /^(\w+):\s*(.*)$/.exec(line);
      if (m) { found[m[1]] = origin + out.length; line = m[2]; if (!line) continue; }
      m = /^(\w+)\s*=\s*(.+)$/.exec(line);
      if (m) { found[m[1]] = ev(m[2]); continue; }
      const [, mn0, rest = ''] = /^(\w+)\s*(.*)$/.exec(line);
      const mn = mn0.toLowerCase(), args = rest ? rest.split(',').map((s) => s.trim()) : [];
      let hit = null;
      for (const [code, name, pat] of OPS) {
        if (name !== mn) continue;
        const pats = pat ? pat.split(',') : [];
        if (pats.length !== args.length) continue;
        const vals = [];
        const ok = pats.every((p, k) => {
          const s = args[k], low = s.toLowerCase().replace(/\s/g, '');
          const regs = ['a', 'x', 'y', 'ya', 'sp'];
          if (regs.includes(p)) return low === p;
          if (p === '#i') { if (s[0] !== '#') return false; vals.push(['i', ev(s.slice(1))]); return true; }
          if (p === '!a') { if (s[0] !== '!' || /\+\s*[xyXY]$/.test(s)) return false; vals.push(['a', ev(s.slice(1))]); return true; }
          if (p === '!a+x' || p === '!a+y') { const mm = /^!(.+)\+([xyXY])$/.exec(s); if (!mm || mm[2].toLowerCase() !== p.slice(-1)) return false; vals.push(['a', ev(mm[1])]); return true; }
          if (p === '[d]+y') { const mm = /^\[(.+)\]\+[yY]$/.exec(s); if (!mm) return false; vals.push(['d', ev(mm[1])]); return true; }
          if (p === 'd+x') { const mm = /^([^!#\[].*)\+[xX]$/.exec(s); if (!mm) return false; vals.push(['d', ev(mm[1])]); return true; }
          if (p === 'r') { vals.push(['r', ev(s)]); return true; }
          if (p === 'd') { if (/^[!#\[]/.test(s) || regs.includes(low) || /\+[xy]$/.test(low)) return false; vals.push(['d', ev(s)]); return true; }
          return false;
        });
        if (!ok) continue;
        hit = { code, vals, pat }; break;
      }
      if (!hit) throw new Error('cannot assemble: ' + line);
      const start = out.length; out.push(hit.code);
      const len = 1 + hit.vals.reduce((n, [k]) => n + (k === 'a' ? 2 : 1), 0);
      const enc = hit.pat === 'd,#i' ? [hit.vals[1], hit.vals[0]] : hit.vals;   // (mov d,#i: the immediate first)
      for (const [kind, v] of enc) {
        if (kind === 'a') out.push(v & 255, (v >> 8) & 255);
        else if (kind === 'r') { const d = v - (origin + start + len); if (final && (d < -128 || d > 127)) throw new Error('branch out of range: ' + line); out.push(d & 255); }
        else { if (final && kind === 'd' && (v < 0 || v > 255)) throw new Error('not direct page: ' + line); out.push(v & 255); }
      }
    }
    labels = found;
    return Buffer.from(out);
  };
  pass(false); pass(false);
  return { code: pass(true), labels };
}

// ---------------------------------------------------------------- BRR (the chip's 4-bit sample format)
export function brrDecodeNibble(nyb, shift, filter, p1, p2full) {
  let s = nyb >= 8 ? nyb - 16 : nyb;
  s = shift <= 12 ? (s << shift) >> 1 : (s < 0 ? -2048 : 0);
  const p2 = p2full >> 1;
  if (filter === 1) s += (p1 >> 1) + ((-p1) >> 5);
  else if (filter === 2) s += p1 - p2 + (p2 >> 4) + ((p1 * -3) >> 6);
  else if (filter === 3) s += p1 - p2 + ((p1 * -13) >> 7) + ((p2 * 3) >> 4);
  s = Math.max(-32768, Math.min(32767, s));
  return ((s << 1) << 16) >> 16;
}

/** samples (16-bit, length a multiple of 16) -> BRR blocks. loopAt: sample index (multiple of 16) or -1 */
export function brrEncode(samples, loopAt = -1) {
  const n = samples.length / 16, out = Buffer.alloc(n * 9);
  let p1 = 0, p2 = 0;
  for (let b = 0; b < n; b++) {
    const forced = b === 0 || b * 16 === loopAt;       // (no history to lean on at the start and the loop point)
    let best = null;
    for (let filter = 0; filter < (forced ? 1 : 4); filter++) for (let shift = 0; shift <= 12; shift++) {
      let q1 = p1, q2 = p2, err = 0; const nybs = [];
      for (let i = 0; i < 16; i++) {
        const want = samples[b * 16 + i];
        let bn = 0, bv = 0, be = Infinity;
        for (let c = 0; c < 16; c++) { const v = brrDecodeNibble(c, shift, filter, q1, q2); const e = (v - want) * (v - want); if (e < be) { be = e; bn = c; bv = v; } }
        err += be; nybs.push(bn); q2 = q1; q1 = bv;
        if (best && err >= best.err) break;
      }
      if (nybs.length === 16 && (!best || err < best.err)) best = { err, filter, shift, nybs, q1, q2 };
    }
    const end = b === n - 1;
    out[b * 9] = (best.shift << 4) | (best.filter << 2) | (end && loopAt >= 0 ? 2 : 0) | (end ? 1 : 0);
    for (let i = 0; i < 8; i++) out[b * 9 + 1 + i] = (best.nybs[i * 2] << 4) | best.nybs[i * 2 + 1];
    p1 = best.q1; p2 = best.q2;
  }
  return out;
}

// ---------------------------------------------------------------- the preview player
const RATES = [Infinity, 2048, 1536, 1280, 1024, 768, 640, 512, 384, 320, 256, 192, 160, 128, 96, 80, 64, 48, 40, 32, 24, 20, 16, 12, 10, 8, 6, 5, 4, 3, 2, 1];

export function renderSpc(image, loadAt, entry, seconds) {
  const ram = new Uint8Array(0x10000); ram.set(image, loadAt);
  const dsp = new Uint8Array(128); dsp[0x6c] = 0xe0;
  const ports = [0, 0, 0, 0]; let dspAddr = 0, control = 0, t0target = 0, t0count = 0, t0out = 0, t0acc = 0;
  let A = 0, X = 0, Y = 0, SP = 0xef, PC = entry, N = 0, Z = 0, C = 0, instructions = 0;
  const voices = Array.from({ length: 8 }, () => ({ on: false, addr: 0, buf: [0, 0, 0, 0], block: [], pos: 0, frac: 0, p1: 0, p2: 0, env: 0, phase: 0, ctr: 0, cur: 0, prev: 0, end: false }));
  const rd = (a) => {
    a &= 0xffff;
    if (a === 0xf2) return dspAddr; if (a === 0xf3) return dsp[dspAddr & 127];
    if (a >= 0xf4 && a <= 0xf7) return 0;
    if (a === 0xfd) { const v = t0out & 15; t0out = 0; return v; }
    return ram[a];
  };
  const wr = (a, v) => {
    a &= 0xffff; v &= 255;
    if (a === 0xf1) { if ((v & 1) && !(control & 1)) { t0count = 0; t0out = 0; } control = v; return; }
    if (a === 0xf2) { dspAddr = v; return; }
    if (a === 0xf3) { if (dspAddr < 128) { dsp[dspAddr] = v; if (dspAddr === 0x4c) for (let i = 0; i < 8; i++) if (v & (1 << i)) keyOn(i); if (dspAddr === 0x7c) dsp[0x7c] = 0; } return; }
    if (a >= 0xf4 && a <= 0xf7) { ports[a - 0xf4] = v; return; }
    if (a === 0xfa) { t0target = v; return; }
    ram[a] = v;
  };
  const keyOn = (i) => {
    const v = voices[i], d = dsp[0x5d] * 256 + dsp[i * 16 + 4] * 4;
    Object.assign(v, { on: true, addr: ram[d] | (ram[d + 1] << 8), pos: 16, frac: 0, p1: 0, p2: 0, env: 0, phase: 0, ctr: 0, cur: 0, prev: 0, end: false });
  };
  const fetch = () => { const v = ram[PC]; PC = (PC + 1) & 0xffff; return v; };
  const abs = () => { const l = fetch(); return l | (fetch() << 8); };
  const nz = (v) => { v &= 255; N = v >> 7; Z = v === 0 ? 1 : 0; return v; };
  const push = (v) => { ram[0x100 + SP] = v; SP = (SP - 1) & 255; };
  const pop = () => { SP = (SP + 1) & 255; return ram[0x100 + SP]; };
  const adc = (b) => { const r = A + b + C; C = r > 255 ? 1 : 0; A = nz(r); };
  const cmp = (a, b) => { const r = a - b; C = r >= 0 ? 1 : 0; nz(r); };
  const branch = (c) => { const d = (fetch() << 24) >> 24; if (c) PC = (PC + d) & 0xffff; };
  const step = () => {
    const op = fetch(); instructions++;
    switch (op) {
      case 0xe8: A = nz(fetch()); break; case 0xe4: A = nz(rd(fetch())); break; case 0xe5: A = nz(rd(abs())); break; case 0xf4: A = nz(rd((fetch() + X) & 255)); break;
      case 0xf5: A = nz(rd(abs() + X)); break; case 0xf6: A = nz(rd(abs() + Y)); break; case 0xf7: { const d = fetch(); A = nz(rd((ram[d] | (ram[(d + 1) & 255] << 8)) + Y)); break; }
      case 0xcd: X = nz(fetch()); break; case 0x8d: Y = nz(fetch()); break; case 0xf8: X = nz(rd(fetch())); break; case 0xeb: Y = nz(rd(fetch())); break;
      case 0xc4: wr(fetch(), A); break; case 0xc5: wr(abs(), A); break; case 0xd4: wr((fetch() + X) & 255, A); break; case 0xd5: wr(abs() + X, A); break; case 0xd6: wr(abs() + Y, A); break;
      case 0xd8: wr(fetch(), X); break; case 0xcb: wr(fetch(), Y); break; case 0x8f: { const i = fetch(); wr(fetch(), i); break; }
      case 0x7d: A = nz(X); break; case 0x5d: X = nz(A); break; case 0xdd: A = nz(Y); break; case 0xfd: Y = nz(A); break; case 0xbd: SP = X; break;
      case 0xba: { const d = fetch(); A = rd(d); Y = rd((d + 1) & 255); Z = !A && !Y ? 1 : 0; N = Y >> 7; break; }
      case 0xda: { const d = fetch(); wr(d, A); wr((d + 1) & 255, Y); break; }
      case 0x3a: { const d = fetch(); const v = ((rd(d) | (rd(d + 1) << 8)) + 1) & 0xffff; wr(d, v); wr(d + 1, v >> 8); Z = v ? 0 : 1; N = v >> 15; break; }
      case 0x7a: { const d = fetch(); const r = (A | (Y << 8)) + (rd(d) | (rd(d + 1) << 8)); C = r > 0xffff ? 1 : 0; A = r & 255; Y = (r >> 8) & 255; Z = (r & 0xffff) ? 0 : 1; N = Y >> 7; break; }
      case 0x88: adc(fetch()); break; case 0x84: adc(rd(fetch())); break; case 0xa8: adc(fetch() ^ 255); break; case 0xa4: adc(rd(fetch()) ^ 255); break;
      case 0x68: cmp(A, fetch()); break; case 0x64: cmp(A, rd(fetch())); break; case 0xc8: cmp(X, fetch()); break; case 0xad: cmp(Y, fetch()); break; case 0x3e: cmp(X, rd(fetch())); break;
      case 0x28: A = nz(A & fetch()); break; case 0x24: A = nz(A & rd(fetch())); break; case 0x08: A = nz(A | fetch()); break; case 0x04: A = nz(A | rd(fetch())); break; case 0x48: A = nz(A ^ fetch()); break;
      case 0xbc: A = nz(A + 1); break; case 0x9c: A = nz(A - 1); break; case 0x3d: X = nz(X + 1); break; case 0x1d: X = nz(X - 1); break; case 0xfc: Y = nz(Y + 1); break; case 0xdc: Y = nz(Y - 1); break;
      case 0xab: { const d = fetch(); wr(d, nz(rd(d) + 1)); break; } case 0x8b: { const d = fetch(); wr(d, nz(rd(d) - 1)); break; }
      case 0x1c: C = A >> 7; A = nz(A << 1); break; case 0x5c: C = A & 1; A = nz(A >> 1); break; case 0x9f: A = nz((A >> 4) | (A << 4)); break;
      case 0xcf: { const r = Y * A; A = r & 255; Y = r >> 8; nz(Y); break; }
      case 0x2d: push(A); break; case 0x4d: push(X); break; case 0x6d: push(Y); break; case 0xae: A = pop(); break; case 0xce: X = pop(); break; case 0xee: Y = pop(); break;
      case 0x60: C = 0; break; case 0x80: C = 1; break; case 0x20: case 0xc0: break;
      case 0x2f: branch(true); break; case 0xf0: branch(Z); break; case 0xd0: branch(!Z); break; case 0xb0: branch(C); break; case 0x90: branch(!C); break; case 0x30: branch(N); break; case 0x10: branch(!N); break;
      case 0xfe: Y = (Y - 1) & 255; branch(Y !== 0); break; case 0x6e: { const d = fetch(); const v = (rd(d) - 1) & 255; wr(d, v); branch(v !== 0); break; }
      case 0x5f: PC = abs(); break; case 0x3f: { const t = abs(); push(PC >> 8); push(PC & 255); PC = t; break; } case 0x6f: { const l = pop(); PC = l | (pop() << 8); break; }
      default: throw new Error(`SPC700 opcode ${op.toString(16)} at ${(PC - 1).toString(16)}`);
    }
  };
  // one output sample
  const echoHist = [new Array(8).fill(0), new Array(8).fill(0)]; let echoPos = 0, noise = 0x4000, noiseCtr = 0;
  const total = Math.floor(seconds * 32000), out = new Int16Array(total * 2);
  const clamp = (v) => Math.max(-32768, Math.min(32767, v));
  for (let s = 0; s < total; s++) {
    for (let k = 0; k < 10; k++) step();
    if (control & 1) { t0acc += 8000; while (t0acc >= 32000) { t0acc -= 32000; t0count = (t0count + 1) & 255; if (t0count === (t0target & 255)) { t0count = 0; t0out++; } } }
    const nr = RATES[dsp[0x6c] & 31];
    if (++noiseCtr >= nr) { noiseCtr = 0; const bit = (noise ^ (noise >> 1)) & 1; noise = (noise >> 1) | (bit << 14); }
    let ml = 0, mr = 0, el = 0, er = 0;
    for (let i = 0; i < 8; i++) {
      const v = voices[i]; if (!v.on) { dsp[i * 16 + 8] = 0; continue; }
      const base = i * 16;
      // envelope
      const a1 = dsp[base + 5], a2 = dsp[base + 6], gain = dsp[base + 7];
      let rate, apply;
      if (a1 & 0x80) {
        if (v.phase === 0) { const ar = a1 & 15; rate = ar * 2 + 1; apply = () => { v.env += ar === 15 ? 1024 : 32; if (v.env >= 0x7e0) { v.env = Math.min(v.env, 0x7ff); v.phase = 1; } }; }
        else if (v.phase === 1) { rate = ((a1 >> 4) & 7) * 2 + 16; apply = () => { v.env -= 1; v.env -= v.env >> 8; if (v.env <= (((a2 >> 5) + 1) << 8)) v.phase = 2; }; }
        else { rate = a2 & 31; apply = () => { v.env -= 1; v.env -= v.env >> 8; }; }
      } else if (!(gain & 0x80)) { v.env = (gain & 127) << 4; rate = 0; apply = () => {}; }
      else { rate = gain & 31; const mode = (gain >> 5) & 3; apply = () => { if (mode === 0) v.env -= 32; else if (mode === 1) { v.env -= 1; v.env -= v.env >> 8; } else v.env += (mode === 3 && v.env >= 0x600) ? 8 : 32; }; }
      if (++v.ctr >= RATES[rate]) { v.ctr = 0; apply(); v.env = Math.max(0, Math.min(0x7ff, v.env)); }
      // the sample at the current pitch
      const pitch = (dsp[base + 2] | (dsp[base + 3] << 8)) & 0x3fff;
      v.frac += pitch;
      while (v.frac >= 0x1000) {
        v.frac -= 0x1000;
        if (v.pos >= 16) {
          if (v.end) { const d = dsp[0x5d] * 256 + dsp[base + 4] * 4; if (v.loop) v.addr = ram[d + 2] | (ram[d + 3] << 8); else { v.on = false; break; } }
          const h = ram[v.addr]; v.block = [];
          for (let j = 0; j < 16; j++) { const byte = ram[v.addr + 1 + (j >> 1)]; const nyb = j & 1 ? byte & 15 : byte >> 4; const x = brrDecodeNibble(nyb, h >> 4, (h >> 2) & 3, v.p1, v.p2); v.p2 = v.p1; v.p1 = x; v.block.push(x); }
          v.end = !!(h & 1); v.loop = !!(h & 2); v.addr = (v.addr + 9) & 0xffff; v.pos = 0;
        }
        v.prev = v.cur; v.cur = v.block[v.pos++];
      }
      let smp = dsp[0x3d] & (1 << i) ? ((noise << 1) << 16) >> 16 : v.prev + (((v.cur - v.prev) * v.frac) >> 12);
      smp = (smp * v.env) >> 11;
      dsp[base + 8] = v.env >> 4;
      const vl = (dsp[base] << 24) >> 24, vr = (dsp[base + 1] << 24) >> 24;
      const l = (smp * vl) >> 7, r = (smp * vr) >> 7;
      ml = clamp(ml + l); mr = clamp(mr + r);
      if (dsp[0x4d] & (1 << i)) { el = clamp(el + l); er = clamp(er + r); }
    }
    // echo
    const esa = dsp[0x6d] * 256, len = Math.max(4, (dsp[0x7d] & 15) * 2048);
    const at = (esa + echoPos) & 0xffff;
    const rs = (o) => ((ram[(at + o) & 0xffff] | (ram[(at + o + 1) & 0xffff] << 8)) << 16) >> 16;
    const fir = [0, 1].map((c) => { const h = echoHist[c]; h.shift(); h.push(rs(c * 2) >> 1); let acc = 0; for (let t = 0; t < 8; t++) acc += (h[t] * ((dsp[t * 16 + 15] << 24) >> 24)) >> 6; return clamp(acc); });
    const s8 = (r) => (dsp[r] << 24) >> 24;
    const outL = clamp(((ml * s8(0x0c)) >> 7) + ((fir[0] * s8(0x2c)) >> 7)), outR = clamp(((mr * s8(0x1c)) >> 7) + ((fir[1] * s8(0x3c)) >> 7));
    if (!(dsp[0x6c] & 0x20)) { const wl = clamp(el + ((fir[0] * s8(0x0d)) >> 7)), wr_ = clamp(er + ((fir[1] * s8(0x0d)) >> 7)); ram[at] = wl & 255; ram[(at + 1) & 0xffff] = (wl >> 8) & 255; ram[(at + 2) & 0xffff] = wr_ & 255; ram[(at + 3) & 0xffff] = (wr_ >> 8) & 255; }
    echoPos = (echoPos + 4) % len;
    if (dsp[0x6c] & 0x40) { out[s * 2] = 0; out[s * 2 + 1] = 0; } else { out[s * 2] = outL; out[s * 2 + 1] = outR; }
  }
  return { samples: out, ports, instructions };
}

export function wav(samples, rate = 32000) {
  const b = Buffer.alloc(44 + samples.length * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + samples.length * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(2, 22);
  b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) b.writeInt16LE(samples[i], 44 + i * 2);
  return b;
}
