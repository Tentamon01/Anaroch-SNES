// A minimal headless SNES for testing this ROM: 65816 core (native + enough emulation mode to boot), LoROM bus,
// DMA, the PPU registers the game uses, and a Mode 1 BG1 + sprite renderer. Not cycle-accurate: a frame is a fixed
// budget of CPU cycles (estimated per instruction), then NMI.
import fs from 'node:fs';
import { T, IMP, REL, RELL } from './asm816.mjs';
import { Spc7110, SuperFx } from './chips.mjs';

// ---- opcode table from the assembler's tables
const OP = new Array(256);
for (const [mn, modes] of Object.entries(T)) for (const [mode, code] of Object.entries(modes)) if (!OP[code] || mode !== 'immb') OP[code] = OP[code] || { mn, mode };
for (const [mn, code] of Object.entries(IMP)) OP[code] = { mn, mode: 'imp' };
for (const [mn, code] of Object.entries(REL)) if (!OP[code]) OP[code] = { mn: mn === 'BLT' ? 'BCC' : mn === 'BGE' ? 'BCS' : mn, mode: 'rel' };
OP[0x82] = { mn: 'BRL', mode: 'rell' }; OP[0x62] = { mn: 'PER', mode: 'rell' };
OP[0x89] = { mn: 'BIT', mode: 'imm' };
OP[0xC2] = { mn: 'REP', mode: 'immb' }; OP[0xE2] = { mn: 'SEP', mode: 'immb' };
OP[0x02] = { mn: 'COP', mode: 'immb' }; OP[0x42] = { mn: 'WDM', mode: 'immb' };
OP[0xF4] = { mn: 'PEA', mode: 'pea' }; OP[0xD4] = { mn: 'PEI', mode: 'dp' };
OP[0x22] = { mn: 'JSL', mode: 'long' }; OP[0x5C] = { mn: 'JML', mode: 'long' }; OP[0xDC] = { mn: 'JML', mode: 'absindl' };
OP[0x4C] = { mn: 'JMP', mode: 'abs' }; OP[0x6C] = { mn: 'JMP', mode: 'absind' }; OP[0x7C] = { mn: 'JMP', mode: 'absindx' };
OP[0x20] = { mn: 'JSR', mode: 'abs' }; OP[0xFC] = { mn: 'JSR', mode: 'absindx' };
OP[0x54] = { mn: 'MVN', mode: 'mvn' }; OP[0x44] = { mn: 'MVP', mode: 'mvn' };
for (let i = 0; i < 256; i++) if (!OP[i]) OP[i] = { mn: 'NOP', mode: 'imp' };

export class Snes {
  // options.program: the size of the program ROM on the dual-chip board (the rest is the SPC7110's data ROM)
  constructor(rom, options = {}) {
    const program = options.program || 0;
    this.sfx = program ? new SuperFx(rom.subarray(0, program)) : null;
    this.spc = program ? new Spc7110(rom.subarray(0, program), rom.subarray(program)) : null;
    this.apu = [0xAA, 0xBB, 0, 0]; this.irqFlag = 0;
    if (program) rom = rom.subarray(0, program);
    this.rom = rom; this.wram = new Uint8Array(0x20000); this.vram = new Uint8Array(0x10000); this.cgram = new Uint8Array(512);
    this.oam = new Uint8Array(544); this.reg = new Uint8Array(0x10000); this.pad = 0; this.frame = 0; this.nmiFlag = 0;
    this.vaddr = 0; this.cgaddr = 0; this.cglatch = null; this.oamaddr = 0; this.scroll = { h: 0, v: 0, hl: 0, vl: 0, prev: 0 };
    this.A = 0; this.X = 0; this.Y = 0; this.S = 0x1FF; this.D = 0; this.DB = 0; this.PB = 0; this.P = 0x34; this.E = 1;
    this.PC = this.rd(0xFFFC) | (this.rd(0xFFFD) << 8); this.cyc = 0; this.halted = false; this.waiting = false;
    this.trace = null; this.breaks = new Map(); this.m7 = {}; this.m7latch = 0;
  }
  // ---- bus
  romAt(b, a) { return this.rom[(((b & 0x7F) * 0x8000) + (a & 0x7FFF)) % this.rom.length]; }
  rd(addr) {
    addr &= 0xFFFFFF; const b = addr >> 16, a = addr & 0xFFFF;
    if (b === 0x7E || b === 0x7F) return this.wram[addr - 0x7E0000];
    if (this.sfx) {
      if (b >= 0xC0) return this.spc.mcu(addr);
      if (b === 0x50) return this.spc.read(0);
      if (b === 0x70 || b === 0x71) return this.sfx.ran ? 0 : this.sfx.ram[addr - 0x700000];
      if ((b & 0x7F) < 0x40) {
        if (a >= 0x3000 && a < 0x3500) return this.sfx.ioRead(a);
        if (a >= 0x4800 && a < 0x4840) return this.spc.read(a);
        if (a >= 0x8000 && this.sfx.ron) return [0x00, 0x01, 0x00, 0x01, 0x04, 0x01, 0x00, 0x01, 0x00, 0x01, 0x08, 0x01, 0x00, 0x01, 0x0C, 0x01][a & 15];
        if (a >= 0x2140 && a <= 0x2143) return this.apu[a - 0x2140];
        if (a === 0x4211) { const v = this.irqFlag; this.irqFlag = 0; return v; }
      }
    }
    if ((b & 0x7F) < 0x40) {
      if (a < 0x2000) return this.wram[a];
      if (a >= 0x8000) return this.romAt(b, a);
      if (a === 0x4210) { const v = this.nmiFlag ? 0x80 : 0; this.nmiFlag = 0; return v | 2; }
      if (a === 0x4212) return 0;
      if (a === 0x4218) return this.pad & 0xFF;
      if (a === 0x4219) return this.pad >> 8;
      if (a >= 0x4214 && a <= 0x4217) return this.mathRd(a);
      return this.reg[a];
    }
    return this.romAt(b, a);
  }
  mathRd(a) { const v = a >= 0x4216 ? this.mul : this.div; return a & 1 ? v >> 8 : v & 0xFF; }
  wr(addr, v) {
    addr &= 0xFFFFFF; v &= 0xFF; const b = addr >> 16, a = addr & 0xFFFF;
    if (b === 0x7E || b === 0x7F) { this.wram[addr - 0x7E0000] = v; return; }
    if (this.sfx) {
      if (b === 0x70 || b === 0x71) { if (!this.sfx.ran) this.sfx.ram[addr - 0x700000] = v; return; }
      if ((b & 0x7F) < 0x40) {
        if (a >= 0x3000 && a < 0x3500) return this.sfx.ioWrite(a, v);
        if (a >= 0x4800 && a < 0x4840) return this.spc.write(a, v);
        if (a >= 0x2140 && a <= 0x2143) { this.apu[a - 0x2140] = v; return; }
      }
    }
    if ((b & 0x7F) >= 0x40 || a >= 0x8000) return;
    if (a < 0x2000) { this.wram[a] = v; return; }
    this.reg[a] = v;
    switch (a) {
      case 0x2102: this.oamaddr = (this.oamaddr & 0x200) | (v << 1); break;
      case 0x2103: this.oamaddr = (this.oamaddr & 0x1FE) | ((v & 1) << 9); break;
      case 0x2104: if (this.oamaddr < 544) this.oam[this.oamaddr] = v; this.oamaddr = (this.oamaddr + 1) % 544; break;
      case 0x211B: case 0x211C: case 0x211D: case 0x211E: case 0x211F: case 0x2120: this.m7[a] = (v << 8) | this.m7latch; this.m7latch = v; break;
      case 0x210D: this.m7[a] = (v << 8) | this.m7latch; this.m7latch = v; this.scroll.h = (v << 8) | (this.scroll.prev & ~7) | ((this.scroll.h >> 8) & 7); this.scroll.prev = v; break;
      case 0x210E: this.m7[a] = (v << 8) | this.m7latch; this.m7latch = v; this.scroll.v = (v << 8) | this.scroll.prev; this.scroll.prev = v; break;
      case 0x2111: { const q = this.scroll3 || (this.scroll3 = { h: 0, v: 0 }); q.h = (v << 8) | (this.scroll.prev & ~7) | ((q.h >> 8) & 7); this.scroll.prev = v; break; }
      case 0x2112: { const q = this.scroll3 || (this.scroll3 = { h: 0, v: 0 }); q.v = (v << 8) | this.scroll.prev; this.scroll.prev = v; break; }
      case 0x2116: this.vaddr = (this.vaddr & 0xFF00) | v; break;
      case 0x2117: this.vaddr = (this.vaddr & 0xFF) | (v << 8); break;
      case 0x2118: case 0x2119: {
        const hi = a === 0x2119; this.vram[((this.vaddr << 1) | (hi ? 1 : 0)) & 0xFFFF] = v;
        const vm = this.reg[0x2115];
        if (((vm & 0x80) !== 0) === hi) this.vaddr = (this.vaddr + [1, 32, 128, 128][vm & 3]) & 0x7FFF;
        break;
      }
      case 0x2121: this.cgaddr = v << 1; this.cglatch = null; break;
      case 0x2122: this.cgram[this.cgaddr & 511] = v; this.cgaddr++; break;
      case 0x4203: this.mul = this.reg[0x4202] * v; break;
      case 0x4206: { const dd = this.reg[0x4204] | (this.reg[0x4205] << 8); if (v === 0) { this.div = 0xFFFF; this.mul = dd; } else { this.div = Math.floor(dd / v); this.mul = dd % v; } break; }
      case 0x420B: for (let c = 0; c < 8; c++) if (v & (1 << c)) this.dma(c); break;
    }
  }
  dma(c) {
    const base = 0x4300 + c * 16, ctl = this.reg[base], breg = 0x2100 | this.reg[base + 1];
    let src = this.reg[base + 2] | (this.reg[base + 3] << 8); const bank = this.reg[base + 4];
    let n = this.reg[base + 5] | (this.reg[base + 6] << 8); if (n === 0) n = 0x10000;
    const pat = [[0], [0, 1], [0, 0], [0, 0, 1, 1], [0, 1, 2, 3], [0, 1, 0, 1], [0, 0], [0, 0, 1, 1]][ctl & 7];
    const fixed = ctl & 8, dec = ctl & 16;
    if (ctl & 0x80) throw new Error('B->A DMA not supported');
    for (let i = 0; i < n; i++) {
      this.wr(breg + pat[i % pat.length], this.rd((bank << 16) | src));
      if (!fixed) src = (src + (dec ? -1 : 1)) & 0xFFFF;
    }
    this.cyc += n * 2;
    this.reg[base + 5] = 0; this.reg[base + 6] = 0;
  }
  // ---- CPU helpers
  get m8() { return this.E || (this.P & 0x20); }
  get x8() { return this.E || (this.P & 0x10); }
  fetch() { const v = this.rd((this.PB << 16) | this.PC); this.PC = (this.PC + 1) & 0xFFFF; return v; }
  fetch16() { const l = this.fetch(); return l | (this.fetch() << 8); }
  rd16(a) { return this.rd(a) | (this.rd((a + 1) & 0xFFFFFF) << 8); }
  rd16b0(a) { return this.rd(a & 0xFFFF) | (this.rd((a + 1) & 0xFFFF) << 8); }
  wr16(a, v) { this.wr(a, v); this.wr((a + 1) & 0xFFFFFF, v >> 8); }
  push(v) { this.wr(this.S, v); this.S = this.E ? 0x100 | ((this.S - 1) & 0xFF) : (this.S - 1) & 0xFFFF; }
  pull() { this.S = this.E ? 0x100 | ((this.S + 1) & 0xFF) : (this.S + 1) & 0xFFFF; return this.rd(this.S); }
  push16(v) { this.push(v >> 8); this.push(v); }
  pull16() { const l = this.pull(); return l | (this.pull() << 8); }
  nz(v, w8) { this.P &= ~0x82; if (w8) { v &= 0xFF; if (!v) this.P |= 2; if (v & 0x80) this.P |= 0x80; } else { v &= 0xFFFF; if (!v) this.P |= 2; if (v & 0x8000) this.P |= 0x80; } }
  setP(v) { this.P = v; if (this.E) this.P |= 0x30; if (this.P & 0x10) { this.X &= 0xFF; this.Y &= 0xFF; } }
  ea(mode, mn) {
    const D = this.D, DB = this.DB << 16;
    switch (mode) {
      case 'dp': return (D + this.fetch()) & 0xFFFF;
      case 'dpx': return (D + this.fetch() + this.X) & 0xFFFF;
      case 'dpy': return (D + this.fetch() + this.Y) & 0xFFFF;
      case 'abs': { const o = this.fetch16(); return (mn === 'JMP' || mn === 'JSR') ? (this.PB << 16) | o : DB | o; }
      case 'absx': return (DB | this.fetch16()) + this.X & 0xFFFFFF;
      case 'absy': return (DB | this.fetch16()) + this.Y & 0xFFFFFF;
      case 'long': { const l = this.fetch16(); return l | (this.fetch() << 16); }
      case 'longx': { const l = this.fetch16(); return ((l | (this.fetch() << 16)) + this.X) & 0xFFFFFF; }
      case 'ind': return DB | this.rd16b0(D + this.fetch());
      case 'indx': return DB | this.rd16b0(D + this.fetch() + this.X);
      case 'indy': return ((DB | this.rd16b0(D + this.fetch())) + this.Y) & 0xFFFFFF;
      case 'indl': { const p = (D + this.fetch()) & 0xFFFF; return this.rd16b0(p) | (this.rd(p + 2) << 16); }
      case 'indly': { const p = (D + this.fetch()) & 0xFFFF; return ((this.rd16b0(p) | (this.rd(p + 2) << 16)) + this.Y) & 0xFFFFFF; }
      case 'sr': return (this.S + this.fetch()) & 0xFFFF;
      case 'sry': return ((DB | this.rd16b0(this.S + this.fetch())) + this.Y) & 0xFFFFFF;
      case 'absind': return (this.PB << 16) | this.rd16b0(this.fetch16());
      case 'absindx': return (this.PB << 16) | this.rd16((this.PB << 16) | ((this.fetch16() + this.X) & 0xFFFF));
      case 'absindl': { const p = this.fetch16(); return this.rd16b0(p) | (this.rd(p + 2) << 16); }
    }
    throw new Error('mode ' + mode);
  }
  nmi() {
    this.waiting = false;
    this.push(this.PB); this.push16(this.PC); this.push(this.P);
    this.P |= 0x04; this.P &= ~0x08; this.PB = 0;
    this.PC = this.rd16(0xFFEA);
  }
  step() {
    const pc0 = (this.PB << 16) | this.PC;
    const hit = this.breaks.get(pc0) || this.breaks.get(pc0 & 0x7FFFFF);
    if (hit) hit(this);
    const opc = this.fetch(); const { mn, mode } = OP[opc];
    if (this.trace) this.trace(pc0, mn, mode);
    this.cyc += 3;
    const m8 = this.m8, x8 = this.x8;
    let addr = 0, imm = null;
    const isX = /^(LDX|LDY|CPX|CPY)$/.test(mn);
    if (mode === 'imm' || mode === 'immx') { const w8 = mode === 'immx' || isX ? x8 : m8; imm = w8 ? this.fetch() : this.fetch16(); }
    else if (mode === 'immb') imm = this.fetch();
    else if (mode === 'pea') imm = this.fetch16();
    else if (mode === 'rel') { const d = this.fetch(); addr = (this.PC + ((d << 24) >> 24)) & 0xFFFF; }
    else if (mode === 'rell') { const d = this.fetch16(); addr = (this.PC + ((d << 16) >> 16)) & 0xFFFF; }
    else if (mode === 'mvn') { imm = [this.fetch(), this.fetch()]; }
    else if (mode !== 'imp' && mode !== 'acc') { addr = this.ea(mode, mn); this.cyc += 2; }
    const RD = (w8) => imm !== null ? imm : (w8 ? this.rd(addr) : this.rd16(addr));
    const WR = (v, w8) => { if (w8) this.wr(addr, v); else this.wr16(addr, v); };
    const C = () => this.P & 1;
    const setC = (c) => { this.P = c ? this.P | 1 : this.P & ~1; };
    const rmw = (f) => {
      if (mode === 'acc') { if (m8) { const r = f(this.A & 0xFF, true); this.A = (this.A & 0xFF00) | (r & 0xFF); } else this.A = f(this.A, false) & 0xFFFF; return; }
      const v = RD(m8); WR(f(v, m8), m8);
    };
    const ldA = (v) => { if (m8) this.A = (this.A & 0xFF00) | (v & 0xFF); else this.A = v & 0xFFFF; this.nz(v, m8); };
    const a = () => m8 ? this.A & 0xFF : this.A;
    const cmp = (r, v, w8) => { const mask = w8 ? 0xFF : 0xFFFF; const d = (r & mask) - (v & mask); setC(d >= 0); this.nz(d, w8); };
    const adc = (v) => {
      const w = m8 ? 8 : 16, mask = (1 << w) - 1, sign = 1 << (w - 1);
      const r = a() + v + C(); const res = r & mask;
      setC(r > mask); this.P = ((~(a() ^ v) & (a() ^ res) & sign) ? this.P | 0x40 : this.P & ~0x40);
      ldA(res);
    };
    switch (mn) {
      case 'LDA': ldA(RD(m8)); break;
      case 'LDX': { const v = RD(x8); this.X = v; this.nz(v, x8); break; }
      case 'LDY': { const v = RD(x8); this.Y = v; this.nz(v, x8); break; }
      case 'STA': WR(this.A, m8); break;
      case 'STX': WR(this.X, x8); break;
      case 'STY': WR(this.Y, x8); break;
      case 'STZ': WR(0, m8); break;
      case 'ADC': adc(RD(m8)); break;
      case 'SBC': adc(RD(m8) ^ (m8 ? 0xFF : 0xFFFF)); break;
      case 'AND': ldA(a() & RD(m8)); break;
      case 'ORA': ldA(a() | RD(m8)); break;
      case 'EOR': ldA(a() ^ RD(m8)); break;
      case 'CMP': cmp(this.A, RD(m8), m8); break;
      case 'CPX': cmp(this.X, RD(x8), x8); break;
      case 'CPY': cmp(this.Y, RD(x8), x8); break;
      case 'BIT': { const v = RD(m8); const r = a() & v; this.P = (r & (m8 ? 0xFF : 0xFFFF)) ? this.P & ~2 : this.P | 2;
        if (imm === null) { const s = m8 ? 0x80 : 0x8000; this.P = (this.P & ~0xC0) | ((v & s) ? 0x80 : 0) | ((v & (s >> 1)) ? 0x40 : 0); } break; }
      case 'TSB': case 'TRB': { const v = RD(m8); this.P = (v & a()) ? this.P & ~2 : this.P | 2; WR(mn === 'TSB' ? v | a() : v & ~a(), m8); break; }
      case 'ASL': rmw((v, w8) => { const s = w8 ? 0x80 : 0x8000; setC(v & s); const r = (v << 1) & (w8 ? 0xFF : 0xFFFF); this.nz(r, w8); return r; }); break;
      case 'LSR': rmw((v, w8) => { setC(v & 1); const r = v >> 1; this.nz(r, w8); return r; }); break;
      case 'ROL': rmw((v, w8) => { const s = w8 ? 0x80 : 0x8000; const c = C(); setC(v & s); const r = ((v << 1) | c) & (w8 ? 0xFF : 0xFFFF); this.nz(r, w8); return r; }); break;
      case 'ROR': rmw((v, w8) => { const s = w8 ? 0x80 : 0x8000; const c = C(); setC(v & 1); const r = (v >> 1) | (c ? s : 0); this.nz(r, w8); return r; }); break;
      case 'INC': rmw((v, w8) => { const r = (v + 1) & (w8 ? 0xFF : 0xFFFF); this.nz(r, w8); return r; }); break;
      case 'DEC': rmw((v, w8) => { const r = (v - 1) & (w8 ? 0xFF : 0xFFFF); this.nz(r, w8); return r; }); break;
      case 'INX': this.X = (this.X + 1) & (x8 ? 0xFF : 0xFFFF); this.nz(this.X, x8); break;
      case 'INY': this.Y = (this.Y + 1) & (x8 ? 0xFF : 0xFFFF); this.nz(this.Y, x8); break;
      case 'DEX': this.X = (this.X - 1) & (x8 ? 0xFF : 0xFFFF); this.nz(this.X, x8); break;
      case 'DEY': this.Y = (this.Y - 1) & (x8 ? 0xFF : 0xFFFF); this.nz(this.Y, x8); break;
      case 'TAX': this.X = x8 ? this.A & 0xFF : this.A; this.nz(this.X, x8); break;
      case 'TAY': this.Y = x8 ? this.A & 0xFF : this.A; this.nz(this.Y, x8); break;
      case 'TXA': ldA(this.X); break;
      case 'TYA': ldA(this.Y); break;
      case 'TXY': this.Y = this.X; this.nz(this.Y, x8); break;
      case 'TYX': this.X = this.Y; this.nz(this.X, x8); break;
      case 'TSX': this.X = x8 ? this.S & 0xFF : this.S; this.nz(this.X, x8); break;
      case 'TXS': this.S = this.E ? 0x100 | (this.X & 0xFF) : this.X; break;
      case 'TCD': this.D = this.A; this.nz(this.D, false); break;
      case 'TDC': this.A = this.D; this.nz(this.A, false); break;
      case 'TCS': this.S = this.E ? 0x100 | (this.A & 0xFF) : this.A; break;
      case 'TSC': this.A = this.S; this.nz(this.A, false); break;
      case 'XBA': this.A = ((this.A >> 8) | (this.A << 8)) & 0xFFFF; this.nz(this.A & 0xFF, true); break;
      case 'XCE': { const c = C(); setC(this.E); this.E = c; if (this.E) { this.P |= 0x30; this.S = 0x100 | (this.S & 0xFF); this.X &= 0xFF; this.Y &= 0xFF; } break; }
      case 'REP': this.setP(this.P & ~imm); break;
      case 'SEP': this.setP(this.P | imm); break;
      case 'CLC': setC(0); break; case 'SEC': setC(1); break;
      case 'CLI': this.P &= ~4; break; case 'SEI': this.P |= 4; break;
      case 'CLD': this.P &= ~8; break; case 'SED': this.P |= 8; break;
      case 'CLV': this.P &= ~0x40; break;
      case 'PHA': if (m8) this.push(this.A); else this.push16(this.A); break;
      case 'PLA': ldA(m8 ? this.pull() : this.pull16()); break;
      case 'PHX': if (x8) this.push(this.X); else this.push16(this.X); break;
      case 'PLX': this.X = x8 ? this.pull() : this.pull16(); this.nz(this.X, x8); break;
      case 'PHY': if (x8) this.push(this.Y); else this.push16(this.Y); break;
      case 'PLY': this.Y = x8 ? this.pull() : this.pull16(); this.nz(this.Y, x8); break;
      case 'PHP': this.push(this.P); break;
      case 'PLP': this.setP(this.pull()); break;
      case 'PHB': this.push(this.DB); break;
      case 'PLB': this.DB = this.pull(); this.nz(this.DB, true); break;
      case 'PHK': this.push(this.PB); break;
      case 'PHD': this.push16(this.D); break;
      case 'PLD': this.D = this.pull16(); this.nz(this.D, false); break;
      case 'PEA': this.push16(imm); break;
      case 'PEI': this.push16(this.rd16b0(addr)); break;
      case 'PER': this.push16(addr); break;
      case 'JMP': this.PC = addr & 0xFFFF; if (mode === 'absindl') this.PB = addr >> 16; break;
      case 'JML': this.PC = addr & 0xFFFF; this.PB = addr >> 16; break;
      case 'JSR': this.push16((this.PC - 1) & 0xFFFF); this.PC = addr & 0xFFFF; break;
      case 'JSL': this.push(this.PB); this.push16((this.PC - 1) & 0xFFFF); this.PC = addr & 0xFFFF; this.PB = addr >> 16; break;
      case 'RTS': this.PC = (this.pull16() + 1) & 0xFFFF; break;
      case 'RTL': this.PC = (this.pull16() + 1) & 0xFFFF; this.PB = this.pull(); break;
      case 'RTI': this.setP(this.pull()); this.PC = this.pull16(); if (!this.E) this.PB = this.pull(); break;
      case 'BRA': case 'BRL': this.PC = addr; break;
      case 'BCC': if (!C()) this.PC = addr; break;
      case 'BCS': if (C()) this.PC = addr; break;
      case 'BEQ': if (this.P & 2) this.PC = addr; break;
      case 'BNE': if (!(this.P & 2)) this.PC = addr; break;
      case 'BMI': if (this.P & 0x80) this.PC = addr; break;
      case 'BPL': if (!(this.P & 0x80)) this.PC = addr; break;
      case 'BVS': if (this.P & 0x40) this.PC = addr; break;
      case 'BVC': if (!(this.P & 0x40)) this.PC = addr; break;
      case 'WAI': this.waiting = true; break;
      case 'STP': this.halted = true; break;
      case 'NOP': case 'WDM': break;
      case 'BRK': case 'COP': throw new Error(`${mn} at ${pc0.toString(16)}`);
      case 'MVN': case 'MVP': {
        const [dst, srcb] = imm; this.DB = dst;
        this.wr((dst << 16) | this.Y, this.rd((srcb << 16) | this.X));
        const d = mn === 'MVN' ? 1 : -1, xm = x8 ? 0xFF : 0xFFFF;
        this.X = (this.X + d) & xm; this.Y = (this.Y + d) & xm; this.A = (this.A - 1) & 0xFFFF;
        if (this.A !== 0xFFFF) this.PC = (this.PC - 3) & 0xFFFF; break;
      }
      default: throw new Error('unimplemented ' + mn);
    }
    if (this.E) { this.X &= 0xFF; this.Y &= 0xFF; }
  }
  // one frame: active display, then vblank with NMI. Returns cycles the game used before it idled (approx).
  runFrame(budget = 51000) {
    this.cyc = 0;
    this.nmiFlag = 1;
    if (this.reg[0x4200] & 0x80) this.nmi();
    let irqDone = !(this.reg[0x4200] & 0x20);
    const irqLine = this.reg[0x4209] | (this.reg[0x420A] << 8);
    // an interrupt near the bottom of the picture is where a frame of this emulator starts (it renders at the end)
    if (!irqDone && irqLine >= 200) { irqDone = true; this.irqFlag = 0x80; if (!(this.P & 4)) { this.push(this.PB); this.push16(this.PC); this.push(this.P); this.P |= 0x04; this.P &= ~0x08; this.PB = 0; this.PC = this.rd16(0xFFEE); } }
    while (this.cyc < budget && !this.halted) {
      this.step();
      if (this.sfx && this.sfx.running) for (let i = 0; i < 6 && this.sfx.running; i++) this.sfx.step();
      if (!irqDone && this.cyc > budget * ((((this.reg[0x4209] | (this.reg[0x420A] << 8)) + 38) % 262) / 262)) {
        irqDone = true; this.irqFlag = 0x80;
        if (!(this.P & 4)) { this.push(this.PB); this.push16(this.PC); this.push(this.P); this.P |= 0x04; this.P &= ~0x08; this.PB = 0; this.PC = this.rd16(0xFFEE); }
      }
    }
    this.frame++;
  }
  // ---- rendering: Mode 1, BG1 (4bpp) + sprites
  color(i) { const c = this.cgram[i * 2] | (this.cgram[i * 2 + 1] << 8); return [(c & 31) << 3, ((c >> 5) & 31) << 3, ((c >> 10) & 31) << 3]; }
  tilePx(base, tile, x, y) {
    const o = (base + tile * 32) & 0xFFFF;
    const b0 = this.vram[(o + y * 2) & 0xFFFF], b1 = this.vram[(o + y * 2 + 1) & 0xFFFF], b2 = this.vram[(o + 16 + y * 2) & 0xFFFF], b3 = this.vram[(o + 17 + y * 2) & 0xFFFF];
    const s = 7 - x; return ((b0 >> s) & 1) | (((b1 >> s) & 1) << 1) | (((b2 >> s) & 1) << 2) | (((b3 >> s) & 1) << 3);
  }
  render() {
    const W = 256, H = 224, out = new Uint8Array(W * H * 3);
    const sc = this.reg[0x2107], mapBase = (sc & 0xFC) << 9, size = sc & 3;
    const chrBase = (this.reg[0x210B] & 0xF) << 13;
    const hofs = this.scroll.h & 0x3FF, vofs = this.scroll.v & 0x3FF;
    const objBase = (this.reg[0x2101] & 7) << 14, sizes = [[8, 16], [8, 32], [8, 64], [16, 32], [16, 64], [32, 64]][this.reg[0x2101] >> 5];
    const spr = new Int16Array(W * H).fill(-1);
    for (let n = 127; n >= 0; n--) {
      const x0 = this.oam[n * 4], y0 = this.oam[n * 4 + 1], tile = this.oam[n * 4 + 2], at = this.oam[n * 4 + 3];
      const hb = (this.oam[512 + (n >> 2)] >> ((n & 3) * 2)) & 3;
      const sz = sizes[(hb >> 1) & 1]; let x = x0 | ((hb & 1) << 8); if (x >= 256) x -= 512;
      const pal = 128 + ((at >> 1) & 7) * 16, hf = at & 0x40, vf = at & 0x80;
      for (let yy = 0; yy < sz; yy++) for (let xx = 0; xx < sz; xx++) {
        const sx = x + xx, sy = (y0 + yy + 1) & 0xFF; if (sx < 0 || sx >= W || sy >= H) continue;
        const tx = hf ? sz - 1 - xx : xx, ty = vf ? sz - 1 - yy : yy;
        const t = ((tile & 0xF0) + ((ty >> 3) << 4)) & 0xF0 | ((tile + (tx >> 3)) & 0xF);
        const name = (at & 1) << 8;
        const v = this.tilePx(objBase, name | t, tx & 7, ty & 7);
        if (v) spr[sy * W + sx] = pal + v;
      }
    }
    // HDMA: the tables are walked line by line, writing the registers before each line is drawn
    const hd = [];
    for (let c = 0; c < 8; c++) {
      if (!(this.reg[0x420C] & (1 << c))) continue;
      const base = 0x4300 + c * 16, bank = this.reg[base + 4] << 16;
      const ch = { mode: this.reg[base] & 7, breg: 0x2100 | this.reg[base + 1], ptr: this.reg[base + 2] | (this.reg[base + 3] << 8), bank, count: 0, rep: false, xfer: false, on: true };
      const hdr = this.rd(bank | ch.ptr); ch.ptr = (ch.ptr + 1) & 0xFFFF;
      if (!hdr) ch.on = false; else { ch.count = hdr & 0x7F; ch.rep = !!(hdr & 0x80); ch.xfer = true; }
      hd.push(ch);
    }
    const s13 = (v) => ((v & 0x1FFF) << 19) >> 19, s16 = (v) => ((v & 0xFFFF) << 16) >> 16;
    for (let y = 0; y < H; y++) {
      for (const ch of hd) {
        if (!ch.on) continue;
        if (ch.xfer) {
          const pat = [[0], [0, 1], [0, 0], [0, 0, 1, 1], [0, 1, 2, 3], [0, 1, 0, 1], [0, 0], [0, 0, 1, 1]][ch.mode];
          for (const o of pat) { this.wr(ch.breg + o, this.rd(ch.bank | ch.ptr)); ch.ptr = (ch.ptr + 1) & 0xFFFF; }
        }
        ch.count--;
        if (ch.count <= 0) {
          const hdr = this.rd(ch.bank | ch.ptr); ch.ptr = (ch.ptr + 1) & 0xFFFF;
          if (!hdr) ch.on = false; else { ch.count = hdr & 0x7F; ch.rep = !!(hdr & 0x80); ch.xfer = true; }
        } else ch.xfer = ch.rep;
      }
      const mode = this.reg[0x2105] & 7, tm = this.reg[0x212C], bright = this.reg[0x2100] & 15, blank = this.reg[0x2100] & 0x80;
      const A = s16(this.m7[0x211B] || 0), B = s16(this.m7[0x211C] || 0), C = s16(this.m7[0x211D] || 0), D = s16(this.m7[0x211E] || 0);
      const X0 = s13(this.m7[0x211F] || 0), Y0 = s13(this.m7[0x2120] || 0), MH = s13(this.m7[0x210D] || 0), MV = s13(this.m7[0x210E] || 0);
      for (let x = 0; x < W; x++) {
      let ci = 0;
      if ((tm & 1) && mode === 7) {
        const u = x + MH - X0, v = y + MV - Y0;
        const tx = ((A * u + B * v) >> 8) + X0, ty = ((C * u + D * v) >> 8) + Y0;
        const tile = this.vram[((((ty >> 3) & 127) * 128) + ((tx >> 3) & 127)) * 2];
        ci = this.vram[(tile * 64 + (ty & 7) * 8 + (tx & 7)) * 2 + 1];
      } else if (tm & 1) {
        const px = (x + hofs) & (size & 1 ? 511 : 255), py = (y + vofs) & (size & 2 ? 511 : 255);
        let mb = mapBase + (((py & 255) >> 3) * 32 + ((px & 255) >> 3)) * 2;
        if (px >= 256) mb += 0x800; if (py >= 256) mb += size === 3 ? 0x1000 : 0x800;
        const e = this.vram[mb & 0xFFFF] | (this.vram[(mb + 1) & 0xFFFF] << 8);
        let tx = px & 7, ty = py & 7; if (e & 0x4000) tx = 7 - tx; if (e & 0x8000) ty = 7 - ty;
        const v = this.tilePx(chrBase, e & 0x3FF, tx, ty);
        if (v) ci = ((e >> 10) & 7) * 16 + v;
      }
      // BG2 (mode 1 only; 32x32 map, the one-line offset): low-priority tiles under the sprites, high ones over them
      let b2 = 0, b2hi = false;
      if ((tm & 2) && mode === 1) {
        const m2 = (this.reg[0x2108] & 0xFC) << 9, c2 = (this.reg[0x210B] >> 4) << 13;
        const py = (y - 1 + 256) & 255;
        const e = this.vram[(m2 + ((py >> 3) * 32 + (x >> 3)) * 2) & 0xFFFF] | (this.vram[(m2 + ((py >> 3) * 32 + (x >> 3)) * 2 + 1) & 0xFFFF] << 8);
        const v = this.tilePx(c2, e & 0x3FF, x & 7, py & 7);
        if (v) { b2 = ((e >> 10) & 7) * 16 + v; b2hi = !!(e & 0x2000); }
      }
      let math = ci ? this.reg[0x2131] & 1 : 0;             // which layer is on top decides whether BG3 is added
      if (b2 && !b2hi) { ci = b2; math = 0; }
      if ((tm & 0x10) && spr[y * W + x] >= 0) { ci = spr[y * W + x]; math = ci >= 192 ? this.reg[0x2131] & 0x10 : 0; }
      if (b2 && b2hi) { ci = b2; math = 0; }
      let [r, g, b] = this.color(ci);
      if (math && mode === 1 && (this.reg[0x2130] & 2) && (this.reg[0x212D] & 4)) {    // add the second screen: BG3, 64x32
        const q = this.scroll3 || { h: 0, v: 0 }, px = (x + (q.h & 0x3FF)) & 511, py = (y + (q.v & 0x3FF)) & 255;
        const mb = (((this.reg[0x2109] & 0xFC) << 9) + (((py >> 3) * 32 + ((px >> 3) & 31)) + (px >= 256 ? 0x400 : 0)) * 2) & 0xFFFF;
        const e = this.vram[mb] | (this.vram[mb + 1] << 8), o = (((this.reg[0x210C] & 0xF) << 13) + (e & 0x3FF) * 16 + (py & 7) * 2) & 0xFFFF, sh = 7 - (px & 7);
        const v = ((this.vram[o] >> sh) & 1) | (((this.vram[o + 1] >> sh) & 1) << 1);
        if (v) { const [ar, ag, ab] = this.color(((e >> 10) & 7) * 4 + v); r = Math.min(248, r + ar); g = Math.min(248, g + ag); b = Math.min(248, b + ab); }
      }
      if (blank) r = g = b = 0; else if (bright < 15) { r = r * (bright + 1) >> 4; g = g * (bright + 1) >> 4; b = b * (bright + 1) >> 4; }
      out.set([r, g, b], (y * W + x) * 3);
      }
    }
    return out;
  }
  savePPM(file) { const px = this.render(); fs.writeFileSync(file, Buffer.concat([Buffer.from('P6\n256 224\n255\n'), Buffer.from(px)])); }
}
