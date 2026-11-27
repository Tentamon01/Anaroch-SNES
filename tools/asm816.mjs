// A small 65816 assembler for the Anaroch SNES version (no ca65/wla on this machine). LoROM output.
// Syntax (ca65-like):
//   label:   @local (scoped to the last global label)   NAME = expr
//   .bank n            switch to ROM bank n (LoROM: $8000-$FFFF of bank n); .org addr sets the address inside it
//   .ram addr          switch to a RAM section starting at addr (labels only, no bytes); .res n reserves
//   .byte/.word/.long/.dword a,b,"text"   .res n[,fill]   .incbin "file"   .include "file"   .align n
//   .a8 .a16 .i8 .i16  register sizes (REP/SEP with a constant operand are tracked automatically)
//   .macro name / .endmacro  (args \1 \2 ...)
// Operands: #imm  dp  abs  long  with suffix .b/.w/.l forcing size on the mnemonic (lda.l), < > ^ = low/high/bank byte.
// Symbols below $100 are direct page, below $10000 absolute, otherwise long, unless forced.
import fs from 'node:fs';
import path from 'node:path';

// mode keys: imp acc imm(A) immx(X/Y) immb(8bit) dp dpx dpy abs absx absy long longx ind indx indy indl indly sr sry
//            rel rell absind absindx absindl mvn
export const T = {
  ADC: { imm: 0x69, dp: 0x65, dpx: 0x75, abs: 0x6D, absx: 0x7D, absy: 0x79, long: 0x6F, longx: 0x7F, ind: 0x72, indx: 0x61, indy: 0x71, indl: 0x67, indly: 0x77, sr: 0x63, sry: 0x73 },
  AND: { imm: 0x29, dp: 0x25, dpx: 0x35, abs: 0x2D, absx: 0x3D, absy: 0x39, long: 0x2F, longx: 0x3F, ind: 0x32, indx: 0x21, indy: 0x31, indl: 0x27, indly: 0x37, sr: 0x23, sry: 0x33 },
  ASL: { acc: 0x0A, dp: 0x06, dpx: 0x16, abs: 0x0E, absx: 0x1E },
  BIT: { immb: 0x89, imm: 0x89, dp: 0x24, dpx: 0x34, abs: 0x2C, absx: 0x3C },
  CMP: { imm: 0xC9, dp: 0xC5, dpx: 0xD5, abs: 0xCD, absx: 0xDD, absy: 0xD9, long: 0xCF, longx: 0xDF, ind: 0xD2, indx: 0xC1, indy: 0xD1, indl: 0xC7, indly: 0xD7, sr: 0xC3, sry: 0xD3 },
  CPX: { immx: 0xE0, dp: 0xE4, abs: 0xEC },
  CPY: { immx: 0xC0, dp: 0xC4, abs: 0xCC },
  DEC: { acc: 0x3A, dp: 0xC6, dpx: 0xD6, abs: 0xCE, absx: 0xDE },
  EOR: { imm: 0x49, dp: 0x45, dpx: 0x55, abs: 0x4D, absx: 0x5D, absy: 0x59, long: 0x4F, longx: 0x5F, ind: 0x52, indx: 0x41, indy: 0x51, indl: 0x47, indly: 0x57, sr: 0x43, sry: 0x53 },
  INC: { acc: 0x1A, dp: 0xE6, dpx: 0xF6, abs: 0xEE, absx: 0xFE },
  JMP: { abs: 0x4C, long: 0x5C, absind: 0x6C, absindx: 0x7C, absindl: 0xDC },
  JML: { long: 0x5C, abs: 0x5C, absindl: 0xDC },
  JSR: { abs: 0x20, absindx: 0xFC },
  JSL: { long: 0x22, abs: 0x22 },
  LDA: { imm: 0xA9, dp: 0xA5, dpx: 0xB5, abs: 0xAD, absx: 0xBD, absy: 0xB9, long: 0xAF, longx: 0xBF, ind: 0xB2, indx: 0xA1, indy: 0xB1, indl: 0xA7, indly: 0xB7, sr: 0xA3, sry: 0xB3 },
  LDX: { immx: 0xA2, dp: 0xA6, dpy: 0xB6, abs: 0xAE, absy: 0xBE },
  LDY: { immx: 0xA0, dp: 0xA4, dpx: 0xB4, abs: 0xAC, absx: 0xBC },
  LSR: { acc: 0x4A, dp: 0x46, dpx: 0x56, abs: 0x4E, absx: 0x5E },
  ORA: { imm: 0x09, dp: 0x05, dpx: 0x15, abs: 0x0D, absx: 0x1D, absy: 0x19, long: 0x0F, longx: 0x1F, ind: 0x12, indx: 0x01, indy: 0x11, indl: 0x07, indly: 0x17, sr: 0x03, sry: 0x13 },
  ROL: { acc: 0x2A, dp: 0x26, dpx: 0x36, abs: 0x2E, absx: 0x3E },
  ROR: { acc: 0x6A, dp: 0x66, dpx: 0x76, abs: 0x6E, absx: 0x7E },
  SBC: { imm: 0xE9, dp: 0xE5, dpx: 0xF5, abs: 0xED, absx: 0xFD, absy: 0xF9, long: 0xEF, longx: 0xFF, ind: 0xF2, indx: 0xE1, indy: 0xF1, indl: 0xE7, indly: 0xF7, sr: 0xE3, sry: 0xF3 },
  STA: { dp: 0x85, dpx: 0x95, abs: 0x8D, absx: 0x9D, absy: 0x99, long: 0x8F, longx: 0x9F, ind: 0x92, indx: 0x81, indy: 0x91, indl: 0x87, indly: 0x97, sr: 0x83, sry: 0x93 },
  STX: { dp: 0x86, dpy: 0x96, abs: 0x8E },
  STY: { dp: 0x84, dpx: 0x94, abs: 0x8C },
  STZ: { dp: 0x64, dpx: 0x74, abs: 0x9C, absx: 0x9E },
  TRB: { dp: 0x14, abs: 0x1C },
  TSB: { dp: 0x04, abs: 0x0C },
  PEA: { abs: 0xF4, imm: 0xF4 },
  PEI: { ind: 0xD4 },
  REP: { immb: 0xC2 }, SEP: { immb: 0xE2 },
  COP: { immb: 0x02 }, WDM: { immb: 0x42 },
  MVN: { mvn: 0x54 }, MVP: { mvn: 0x44 },
};
export const IMP = { BRK: 0, CLC: 0x18, CLD: 0xD8, CLI: 0x58, CLV: 0xB8, DEX: 0xCA, DEY: 0x88, INX: 0xE8, INY: 0xC8, NOP: 0xEA, PHA: 0x48, PHB: 0x8B, PHD: 0x0B,
  PHK: 0x4B, PHP: 0x08, PHX: 0xDA, PHY: 0x5A, PLA: 0x68, PLB: 0xAB, PLD: 0x2B, PLP: 0x28, PLX: 0xFA, PLY: 0x7A, RTI: 0x40, RTL: 0x6B, RTS: 0x60,
  SEC: 0x38, SED: 0xF8, SEI: 0x78, STP: 0xDB, TAX: 0xAA, TAY: 0xA8, TCD: 0x5B, TCS: 0x1B, TDC: 0x7B, TSC: 0x3B, TSX: 0xBA, TXA: 0x8A, TXS: 0x9A,
  TXY: 0x9B, TYA: 0x98, TYX: 0xBB, WAI: 0xCB, XBA: 0xEB, XCE: 0xFB };
export const REL = { BCC: 0x90, BCS: 0xB0, BEQ: 0xF0, BMI: 0x30, BNE: 0xD0, BPL: 0x10, BVC: 0x50, BVS: 0x70, BRA: 0x80, BLT: 0x90, BGE: 0xB0 };
export const RELL = { BRL: 0x82, PER: 0x62 };
const ALIAS = { 'INA': 'INC', 'DEA': 'DEC', 'ASLA': 'ASL', 'LSRA': 'LSR' };

const strip = (line) => {
  let q = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) { if (c === q) q = null; continue; }
    if (c === '"') q = '"';
    else if (c === "'" && line[i + 2] === "'") { i += 2; continue; }
    else if (c === ';') return line.slice(0, i);
  }
  return line;
};
const splitArgs = (s) => {
  const out = []; let cur = ''; let q = null; let d = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (q) { cur += c; if (c === q) q = null; continue; }
    if (c === '"') { q = '"'; cur += c; continue; }
    if (c === "'" && s[i + 2] === "'") { cur += s.slice(i, i + 3); i += 2; continue; }
    if (c === '(' || c === '[') d++;
    if (c === ')' || c === ']') d--;
    if (c === ',' && d === 0) { out.push(cur.trim()); cur = ''; continue; }
    cur += c;
  }
  if (cur.trim() !== '' || out.length) out.push(cur.trim());
  return out;
};

export function assemble(mainFile, { banks = 8, defines = {} } = {}) {
  const lines = [];
  const readFile = (file, depth = 0) => {
    if (depth > 12) throw new Error('include depth');
    fs.readFileSync(file, 'utf8').split(/\r?\n/).forEach((raw, i) => {
      const m = /^\s*\.include\s+"([^"]+)"/.exec(raw);
      if (m) readFile(path.resolve(path.dirname(file), m[1]), depth + 1);
      else lines.push({ text: strip(raw), file: path.basename(file), no: i + 1, dir: path.dirname(file) });
    });
  };
  readFile(path.resolve(mainFile));

  const macros = {}; const flat = [];
  for (let i = 0; i < lines.length; i++) {
    const m = /^\s*\.macro\s+(\w+)/.exec(lines[i].text);
    if (m) { const body = []; i++; while (!/^\s*\.endmacro/.test(lines[i].text)) body.push(lines[i++]); macros[m[1].toLowerCase()] = body; continue; }
    flat.push(lines[i]);
  }
  const expand = (list, depth = 0) => {
    const out = [];
    for (const l of list) {
      const m = /^(\s*(?:[\w@.]+:\s*)?)(\w+)\s*(.*)$/.exec(l.text);
      if (m && macros[m[2].toLowerCase()]) {
        const args = splitArgs(m[3]);
        const body = macros[m[2].toLowerCase()].map((b) => ({ ...b, text: b.text.replace(/\\(\d)/g, (_, n) => args[+n - 1] ?? ''), file: l.file, no: l.no }));
        if (m[1].trim()) out.push({ ...l, text: m[1] });
        out.push(...expand(body, depth + 1));
      } else out.push(l);
    }
    return out;
  };
  const src = expand(flat);

  const rom = Buffer.alloc(banks * 0x8000, 0);
  const written = new Uint8Array(banks * 0x8000);   // a byte written twice: code ran into data
  let syms = {}; let prevSyms = {};
  let lastGlobal = '';
  const err = (l, msg) => { throw new Error(`${l.file}:${l.no}: ${msg}\n    ${l.text.trim()}`); };

  const evalExpr = (s, l, pass) => {
    const toks = [];
    const re = /\s*(\$[0-9a-fA-F]+|%[01]+|0x[0-9a-fA-F]+|\d+|'.'|[@A-Za-z_.][\w@.]*|<<|>>|[-+*\/&|^~()<>])/y;
    let pos = 0;
    s = s.trim();
    while (pos < s.length) {
      re.lastIndex = pos; const m = re.exec(s);
      if (!m) err(l, 'bad expression: ' + s);
      toks.push(m[1]); pos = re.lastIndex;
    }
    let ti = 0; let unresolved = false;
    const prim = () => {
      const t = toks[ti++];
      if (t === undefined) err(l, 'bad expression: ' + s);
      if (t === '(') { const v = or(); ti++; return v; }
      if (t === '-') return -prim();
      if (t === '+') return prim();
      if (t === '~') return ~prim();
      if (t === '<') return prim() & 0xFF;
      if (t === '>') return (prim() >> 8) & 0xFF;
      if (t === '^') return (prim() >> 16) & 0xFF;
      if (t[0] === '$') return parseInt(t.slice(1), 16);
      if (t[0] === '%') return parseInt(t.slice(1), 2);
      if (t.startsWith('0x')) return parseInt(t, 16);
      if (/^\d/.test(t)) return parseInt(t, 10);
      if (t[0] === "'") return t.charCodeAt(1);
      let name = t;
      if (name[0] === '@') name = lastGlobal + name;
      if (name === '*') return cur.pc;
      if (name in syms) return syms[name];
      if (name in prevSyms) { unresolved = true; return prevSyms[name]; }
      if (pass > 0) err(l, 'undefined symbol ' + name);
      unresolved = true; return 0x8000;
    };
    const mul = () => { let v = prim(); while (toks[ti] === '*' || toks[ti] === '/') { const o = toks[ti++]; const r = prim(); v = o === '*' ? v * r : Math.trunc(v / r); } return v; };
    const add = () => { let v = mul(); while (toks[ti] === '+' || toks[ti] === '-') { const o = toks[ti++]; const r = mul(); v = o === '+' ? v + r : v - r; } return v; };
    const sh = () => { let v = add(); while (toks[ti] === '<<' || toks[ti] === '>>') { const o = toks[ti++]; const r = add(); v = o === '<<' ? v << r : v >> r; } return v; };
    const and = () => { let v = sh(); while (toks[ti] === '&') { ti++; v &= sh(); } return v; };
    const xor = () => { let v = and(); while (toks[ti] === '^') { ti++; v ^= and(); } return v; };
    var or = () => { let v = xor(); while (toks[ti] === '|') { ti++; v |= xor(); } return v; };
    const v = or();
    if (ti < toks.length) err(l, 'trailing tokens in ' + s);
    return { v, unresolved };
  };

  const cur = { pc: 0, bank: 0, ram: false, a16: false, x16: false };
  let outSize = 0;

  const pass = (n) => {
    lastGlobal = ''; cur.pc = 0x8000; cur.bank = 0; cur.ram = false; cur.a16 = false; cur.x16 = false;
    const newSyms = { ...defines };
    const conds = [];   // .if / .else / .endif: { active, parent }
    const emitB = (l, b) => {
      if (cur.ram) err(l, 'bytes in RAM section');
      const off = cur.bank * 0x8000 + (cur.pc & 0x7FFF);
      if ((cur.pc & 0xFFFF) < 0x8000 && !cur.ram) err(l, 'pc below $8000 in ROM');
      if (n === 1) { if (off >= rom.length) err(l, 'ROM overflow'); if (written[off]) err(l, 'overlaps what is already at this address'); written[off] = 1; rom[off] = b & 0xFF; }
      cur.pc++;
      if (cur.pc > 0x10000) err(l, 'bank overflow (bank ' + cur.bank + ')');
    };
    const setSym = (name, v, l) => { if (name in newSyms) err(l, 'duplicate ' + name); newSyms[name] = v; syms = syms; };
    syms = newSyms;
    for (const l of src) {
      let t = l.text;
      const dm = /^\s*\.(if|else|endif)(?![\w])\s*(.*)$/i.exec(t);
      if (dm) {
        const d = dm[1].toLowerCase();
        if (d === 'if') { const parent = conds.every((c) => c.active); conds.push({ parent, active: parent && !!evalExpr(dm[2], l, n).v }); }
        else if (!conds.length) err(l, '.' + d + ' without .if');
        else if (d === 'else') { const c = conds[conds.length - 1]; c.active = c.parent && !c.active; }
        else conds.pop();
        continue;
      }
      if (conds.length && !conds[conds.length - 1].active) continue;
      let m = /^\s*([@A-Za-z_.][\w@.]*):(.*)$/.exec(t);
      if (m && !/^\s*\./.test(t)) {
        let name = m[1];
        if (name[0] !== '@') lastGlobal = name; else name = lastGlobal + name;
        const addr = cur.ram ? cur.pc : ((cur.bank << 16) | cur.pc);
        if (name in newSyms) err(l, 'duplicate label ' + name);
        newSyms[name] = addr;
        t = m[2];
      }
      t = t.trim();
      if (!t) continue;
      m = /^([@A-Za-z_.][\w@.]*)\s*=\s*(.+)$/.exec(t);
      if (m) { let nm = m[1]; if (nm[0] === '@') nm = lastGlobal + nm; newSyms[nm] = evalExpr(m[2], l, n).v; continue; }
      m = /^(\.?[A-Za-z_]\w*)(?:\.([bwlBWL]))?\s*(.*)$/.exec(t);
      if (!m) err(l, 'cannot parse');
      const mn = m[1].toUpperCase(); const force = m[2] ? m[2].toLowerCase() : null; const arg = m[3].trim();
      const ev = (s) => evalExpr(s, l, n);
      const ownSyms = syms; // eslint-disable-line
      if (mn[0] === '.') {
        switch (mn) {
          case '.BANK': cur.bank = ev(arg).v; cur.pc = 0x8000; cur.ram = false; break;
          case '.ORG': cur.pc = ev(arg).v; break;
          case '.RAM': cur.ram = true; cur.pc = ev(arg).v; break;
          case '.A8': cur.a16 = false; break;
          case '.A16': cur.a16 = true; break;
          case '.I8': cur.x16 = false; break;
          case '.I16': cur.x16 = true; break;
          case '.ALIGN': { const a = ev(arg).v; while (cur.pc % a) { if (cur.ram) cur.pc++; else emitB(l, 0); } break; }
          case '.BYTE': for (const a of splitArgs(arg)) { if (a[0] === '"') for (const ch of a.slice(1, -1)) emitB(l, ch.charCodeAt(0)); else emitB(l, ev(a).v); } break;
          case '.WORD': for (const a of splitArgs(arg)) { const v = ev(a).v; emitB(l, v); emitB(l, v >> 8); } break;
          case '.LONG': for (const a of splitArgs(arg)) { const v = ev(a).v; emitB(l, v); emitB(l, v >> 8); emitB(l, v >> 16); } break;
          case '.DWORD': for (const a of splitArgs(arg)) { const v = ev(a).v; emitB(l, v); emitB(l, v >> 8); emitB(l, v >> 16); emitB(l, v >> 24); } break;
          case '.RES': { const a = splitArgs(arg); const c = ev(a[0]).v; const f = a[1] ? ev(a[1]).v : 0; for (let i = 0; i < c; i++) { if (cur.ram) cur.pc++; else emitB(l, f); } break; }
          case '.INCBIN': { const f = path.resolve(l.dir, arg.replace(/^"|"$/g, '')); const b = fs.readFileSync(f); for (const x of b) emitB(l, x); break; }
          default: err(l, 'unknown directive ' + mn);
        }
        continue;
      }
      const op = ALIAS[mn] || mn;
      const E = (v, bytes) => { for (let i = 0; i < bytes; i++) emitB(l, v >> (8 * i)); };
      if (op in IMP) { if (arg) err(l, 'unexpected operand'); emitB(l, IMP[op]); continue; }
      if (op in REL || op in RELL) {
        const tgt = ev(arg);
        const isL = op in RELL;
        const base = cur.pc + (isL ? 3 : 2);
        const d = (tgt.v & 0xFFFF) - base;
        if (isL) { emitB(l, RELL[op]); E(d, 2); }
        else { if (n > 0 && (d < -128 || d > 127)) err(l, `branch out of range (${d})`); emitB(l, REL[op]); E(d, 1); }
        continue;
      }
      const tab = T[op];
      if (!tab) err(l, 'unknown mnemonic ' + mn);
      const pick = (mode, val, bytes) => {
        const opc = tab[mode];
        if (opc === undefined) err(l, `${op} has no ${mode} mode`);
        emitB(l, opc); E(val, bytes);
      };
      // classify operand
      if (arg === '' || /^[aA]$/.test(arg)) { if (tab.acc === undefined) err(l, 'needs operand'); emitB(l, tab.acc); continue; }
      let a = arg;
      if (a[0] === '#') {
        const e = ev(a.slice(1));
        if (op === 'REP' || op === 'SEP') { if (!e.unresolved) { if (e.v & 0x20) cur.a16 = op === 'REP'; if (e.v & 0x10) cur.x16 = op === 'REP'; } emitB(l, tab.immb); E(e.v, 1); continue; }
        if (op === 'PEA') { emitB(l, tab.imm); E(e.v, 2); continue; }
        if (tab.immb !== undefined && tab.imm === undefined) { emitB(l, tab.immb); E(e.v, 1); continue; }
        if (tab.immx !== undefined) { emitB(l, tab.immx); E(e.v, cur.x16 ? 2 : 1); continue; }
        emitB(l, tab.imm); E(e.v, cur.a16 ? 2 : 1); continue;
      }
      if (op === 'MVN' || op === 'MVP') { const p = splitArgs(a); emitB(l, tab.mvn); E(ev(p[1]).v, 1); E(ev(p[0]).v, 1); continue; }
      let mm;
      if ((mm = /^\[(.+)\]\s*,\s*[yY]$/.exec(a))) { const e = ev(mm[1]); pick('indly', e.v, 1); continue; }
      if ((mm = /^\[(.+)\]$/.exec(a))) { const e = ev(mm[1]); if (op === 'JMP' || op === 'JML') pick('absindl', e.v, 2); else pick('indl', e.v, 1); continue; }
      if ((mm = /^\((.+),\s*[sS]\)\s*,\s*[yY]$/.exec(a))) { pick('sry', ev(mm[1]).v, 1); continue; }
      if ((mm = /^\((.+)\)\s*,\s*[yY]$/.exec(a))) { pick('indy', ev(mm[1]).v, 1); continue; }
      if ((mm = /^\((.+),\s*[xX]\)$/.exec(a))) { const e = ev(mm[1]); if (op === 'JMP' || op === 'JSR') pick('absindx', e.v, 2); else pick('indx', e.v, 1); continue; }
      if ((mm = /^\((.+)\)$/.exec(a)) && !/^\(.*\)\s*[-+*\/&|^<>]/.test(a)) {
        const e = ev(mm[1]);
        if (op === 'JMP') pick('absind', e.v, 2); else if (op === 'PEI') pick('ind', e.v, 1); else pick('ind', e.v, 1);
        continue;
      }
      if ((mm = /^(.+),\s*[sS]$/.exec(a))) { pick('sr', ev(mm[1]).v, 1); continue; }
      let idx = '';
      if ((mm = /^(.+),\s*([xXyY])$/.exec(a))) { a = mm[1]; idx = mm[2].toLowerCase(); }
      const e = ev(a);
      const v = e.v;
      let size = force || null;
      if (!size) {
        if (op === 'JSR' || op === 'JMP') size = 'w';
        else if (op === 'JSL' || op === 'JML') size = 'l';
        else if (e.unresolved) size = 'w';
        else if (v >= 0 && v < 0x100 && !/^[<>^]/.test(a) && tab.dp !== undefined) size = 'b';
        else if (v >= 0x10000 && (tab.long !== undefined)) size = 'l';
        else size = 'w';
        if (n === 0 && e.unresolved) size = 'w';
        // keep stable: direct page only when resolved <$100
      }
      if (size === 'b') { pick('dp' + idx, v, 1); }
      else if (size === 'w') { if (op === 'JSL') pick('long', v, 3); else pick('abs' + idx, v, 2); }
      else { if (idx === 'x') pick('longx', v, 3); else pick('long', v, 3); }
    }
    return newSyms;
  };

  // iterate to a fixed point on symbol values (operand sizes depend on them)
  let last = null;
  for (let i = 0; i < 8; i++) {
    prevSyms = syms; syms = {};
    const r = pass(0);
    syms = r;
    const key = JSON.stringify(r);
    if (key === last) break;
    last = key;
    prevSyms = r;
  }
  prevSyms = syms; syms = {};
  const final = pass(1);
  syms = final;
  // header at bank 0 $FFC0, set by the source (.org $FFC0); checksum computed here
  let sum = 0; for (const b of rom) sum = (sum + b) & 0xFFFF;
  const inv = sum ^ 0xFFFF;
  rom[0x7FDC] = inv & 0xFF; rom[0x7FDD] = inv >> 8; rom[0x7FDE] = sum & 0xFF; rom[0x7FDF] = sum >> 8;
  return { rom, syms: final };
}
