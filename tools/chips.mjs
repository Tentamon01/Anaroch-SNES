// The dual-chip board for the test emulator (tools/snes.mjs): the SPC7110 (data ROM, data port, decompressor) and the
// SuperFX 2 (the instructions our assembler knows), mapped as ares' ANAROCH-DUAL board. Not cycle-accurate.
import { unpackStream } from './spc7110.mjs';

export class Spc7110 {
  constructor(prom, drom) { this.prom = prom; this.drom = drom; this.r = new Uint8Array(64); this.r[0x31] = 0; this.r[0x32] = 1; this.r[0x33] = 2; this.next = null; }
  data(a) { return this.drom[a % this.drom.length]; }
  /** banks $C0-$FF: the program ROM in the first megabyte, then data ROM megabytes chosen by $4831-3 */
  mcu(addr) {
    const o = addr & 0x3FFFFF;
    if (o < 0x100000) return this.prom[o % this.prom.length];
    const sel = this.r[0x31 + (o >> 20) - 1] & 7;
    return this.data((sel << 20) | (o & 0xFFFFF));
  }
  port() { return this.r[0x11] | (this.r[0x12] << 8) | (this.r[0x13] << 16); }
  read(a) {
    a &= 0x3F;
    if (a === 0) return this.next ? this.next() : 0;
    if (a === 0x0C) return this.r[0x0C];
    if (a === 0x10) { const o = this.port(); const v = this.data(o); const n = o + 1; this.r[0x11] = n & 255; this.r[0x12] = (n >> 8) & 255; this.r[0x13] = (n >> 16) & 255; return v; }
    return this.r[a];
  }
  write(a, v) {
    a &= 0x3F; this.r[a] = v;
    if (a === 0x06) {                                    // start decompressing directory entry r4804
      const t = (this.r[1] | (this.r[2] << 8) | (this.r[3] << 16)) + this.r[4] * 4;
      const mode = this.data(t), at = (this.data(t + 1) << 16) | (this.data(t + 2) << 8) | this.data(t + 3);
      this.next = unpackStream((i) => this.data(at + i), 1 << mode);
      this.r[0x0C] = 0x80;
    }
  }
}

export class SuperFx {
  constructor(rom) { this.rom = rom; this.ram = new Uint8Array(0x20000); this.r = new Uint16Array(16); this.running = false; this.scmr = 0; this.pbr = 0; this.scbr = 0; this.instructions = 0; this.runs = 0; this.reset(); this.colr = 0; this.por = 0; this.rombr = 0; this.rambr = 0; }
  get ron() { return this.running && (this.scmr & 0x10); }
  get ran() { return this.running && (this.scmr & 0x08); }
  reset() { this.alt = 0; this.b = false; this.s = 0; this.d = 0; }
  bus(bank, a) {
    if (bank < 0x40) return this.rom[(((bank & 0x3F) << 15) | (a & 0x7FFF)) % this.rom.length];
    if ((bank & 0xFE) === 0x70) return this.ram[((bank & 1) << 16) | a];
    return 0;
  }
  ioRead(a) {
    if (a >= 0x3000 && a <= 0x301F) return (this.r[(a >> 1) & 15] >> ((a & 1) * 8)) & 255;
    if (a === 0x3030) return (this.running ? 0x20 : 0) | (this.z << 1);
    return 0;
  }
  ioWrite(a, v) {
    if (a >= 0x3000 && a <= 0x301F) {
      const n = (a >> 1) & 15;
      this.r[n] = a & 1 ? (this.r[n] & 0xFF) | (v << 8) : (this.r[n] & 0xFF00) | v;
      if (a === 0x301F) { this.running = true; this.runs++; this.reset(); this.pipe = 0x01; this.modified = false; }
      return;
    }
    if (a === 0x3034) this.pbr = v & 0x7F;
    else if (a === 0x3038) this.scbr = v;
    else if (a === 0x303A) this.scmr = v;
  }
  fetch() { return this.bus(this.pbr, this.r[15]); }
  operand() { const v = this.pipe; this.r[15]++; this.pipe = this.fetch(); this.modified = false; return v; }
  set(n, v) { this.r[n] = v; if (n === 15) this.modified = true; if (n === 14) this.romByte = this.bus(this.rombr, this.r[14]); }
  flags(v) { this.z = (v & 0xFFFF) === 0 ? 1 : 0; this.sf = (v >> 15) & 1; }
  ramRead(a) { return this.ram[(this.rambr << 16) | (a & 0xFFFF)]; }
  ramWrite(a, v) { this.ram[(this.rambr << 16) | (a & 0xFFFF)] = v & 255; }
  plot() {
    const x = this.r[1] & 255, y = this.r[2] & 255, c = this.colr;
    if (!(this.por & 1) && !(c & 15)) return;
    const ht = ((this.scmr >> 2) & 1) | ((this.scmr >> 4) & 2);
    const cn = ((x & 0xF8) << 1) + (ht === 1 ? (x & 0xF8) >> 1 : ht === 2 ? x & 0xF8 : 0) + ((y & 0xF8) >> 3);
    const base = cn * 32 + (this.scbr << 10) + (y & 7) * 2, bit = 0x80 >> (x & 7);
    for (let p = 0; p < 4; p++) { const a = base + ((p >> 1) << 4) + (p & 1); this.ram[a] = (c >> p) & 1 ? this.ram[a] | bit : this.ram[a] & ~bit; }
  }
  step() {
    const op = this.pipe; this.pipe = this.fetch(); this.modified = false; this.instructions++;
    this.exec(op);
    if (!this.modified) this.r[15]++;
  }
  exec(op) {
    const n = op & 15, alt = this.alt, sr = this.r[this.s], d = this.d;
    const done = () => this.reset();
    const alu = (v) => { this.set(d, v & 0xFFFF); this.flags(v); done(); };
    const arg = alt & 2 ? n : this.r[n];
    if (op === 0x00) { this.running = false; done(); return; }
    if (op === 0x01 || op === 0x02) return done();
    if (op === 0x03) { this.cy = sr & 1; return alu(sr >> 1); }
    if (op >= 0x05 && op <= 0x0F) {
      const disp = (this.operand() << 24) >> 24, ov = this.ov || 0;
      const take = [true, !((this.sf ^ ov) === 1), (this.sf ^ ov) === 1, !this.z, !!this.z, !this.sf, !!this.sf, !this.cy, !!this.cy, !ov, !!ov][op - 5];
      if (take) this.set(15, (this.r[15] + disp) & 0xFFFF);
      return;                                            // (prefixes survive a branch)
    }
    if (op >= 0x10 && op <= 0x1F) { if (this.b) { this.set(n, this.r[this.s]); return done(); } this.d = n; return; }
    if (op >= 0x20 && op <= 0x2F) { this.s = n; this.d = n; this.b = true; return; }
    if (op >= 0x30 && op <= 0x3B) { const a = this.r[n]; this.ramAddr = a; this.ramWrite(a, sr); if (!(alt & 1)) this.ramWrite(a ^ 1, sr >> 8); return done(); }
    if (op === 0x3C) { this.r[12]--; this.flags(this.r[12]); if (!this.z) this.set(15, this.r[13]); return done(); }
    if (op >= 0x3D && op <= 0x3F) { this.b = false; this.alt = alt | (op - 0x3C); return; }
    if (op >= 0x40 && op <= 0x4B) { const a = this.r[n]; this.ramAddr = a; let v = this.ramRead(a); if (!(alt & 1)) v |= this.ramRead(a ^ 1) << 8; this.set(d, v); return done(); }
    if (op === 0x4C) { if (!(alt & 1)) { this.plot(); this.r[1]++; } return done(); }
    if (op === 0x4D) return alu((sr >> 8) | (sr << 8));
    if (op === 0x4E) { if (alt & 1) this.por = sr & 255; else this.colr = sr & 255; return done(); }
    if (op === 0x4F) return alu(~sr);
    if (op >= 0x50 && op <= 0x5F) { const r = sr + arg + (alt & 1 ? this.cy : 0); this.ov = (~(sr ^ arg) & (arg ^ r) & 0x8000) ? 1 : 0; this.cy = r > 0xFFFF ? 1 : 0; return alu(r); }
    if (op >= 0x60 && op <= 0x6F) {
      const b = alt === 2 ? n : this.r[n], r = sr - b - (alt === 1 ? 1 - this.cy : 0);
      this.ov = ((sr ^ b) & (sr ^ r) & 0x8000) ? 1 : 0; this.cy = r >= 0 ? 1 : 0; this.flags(r); if (alt !== 3) this.set(d, r & 0xFFFF); return done();
    }
    if (op >= 0x71 && op <= 0x7F) return alu(sr & (alt & 1 ? ~arg : arg));
    if (op >= 0x80 && op <= 0x8F) return alu(alt & 1 ? (sr & 255) * (arg & 255) : ((sr << 24) >> 24) * ((arg << 24) >> 24));
    if (op >= 0x91 && op <= 0x94) { this.r[11] = this.r[15] + n; return done(); }
    if (op === 0x95) return alu((sr << 24) >> 24);
    if (op === 0x96) { this.cy = sr & 1; return alu(((sr << 16) >> 16) >> 1); }
    if (op >= 0x98 && op <= 0x9D) { this.set(15, this.r[n]); return done(); }
    if (op === 0x9E) return alu(sr & 255);
    if (op >= 0xA0 && op <= 0xAF) {
      if (alt & 3) { const a = this.operand() << 1; if (alt & 1) this.set(n, this.ramRead(a) | (this.ramRead(a ^ 1) << 8)); else { this.ramWrite(a, this.r[n]); this.ramWrite(a ^ 1, this.r[n] >> 8); } }
      else this.set(n, ((this.operand() << 24) >> 24) & 0xFFFF);
      return done();
    }
    if (op >= 0xB0 && op <= 0xBF) { if (this.b) { this.set(d, this.r[n]); this.flags(this.r[n]); return done(); } this.s = n; return; }
    if (op === 0xC0) return alu(sr >> 8);
    if (op >= 0xC1 && op <= 0xCF) return alu(alt & 1 ? sr ^ arg : sr | arg);
    if (op >= 0xD0 && op <= 0xDE) { this.set(n, (this.r[n] + 1) & 0xFFFF); this.flags(this.r[n]); return done(); }
    if (op === 0xDF) { if (alt === 2) this.rambr = sr & 1; else if (alt === 3) this.rombr = sr & 0x7F; else this.colr = this.romByte & 255; return done(); }
    if (op >= 0xE0 && op <= 0xEE) { this.set(n, (this.r[n] - 1) & 0xFFFF); this.flags(this.r[n]); return done(); }
    if (op === 0xEF) { const v = this.romByte; this.set(d, alt === 1 ? (sr & 255) | (v << 8) : alt === 2 ? (sr & 0xFF00) | v : alt === 3 ? ((v << 24) >> 24) & 0xFFFF : v); return done(); }
    if (op >= 0xF0) {
      const lo = this.operand(), v = lo | (this.operand() << 8);
      if (alt & 1) this.set(n, this.ramRead(v) | (this.ramRead(v ^ 1) << 8));
      else if (alt & 2) { this.ramWrite(v, this.r[n]); this.ramWrite(v ^ 1, this.r[n] >> 8); }
      else this.set(n, v);
      return done();
    }
    throw new Error(`GSU opcode ${op.toString(16)} not in the test emulator`);
  }
}
