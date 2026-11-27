// A small assembler for the SuperFX (GSU). Opcodes as ares' instruction table.
//   label:            NAME = expr         ; comment
//   iwt r1, #$1234    ibt r2, #-3         lm r3, ($0100)    sm ($0100), r3
//   to r1 / with r1 / from r1             add r2 / add #2   stw (r1) / ldw (r1) / stb / ldb
//   bra label (and blt bge bne beq bpl bmi bcc bcs bvc bvs): the next instruction still runs (delay slot)
// assembleGsu(source, origin) -> { code, labels }
const reg = (s) => { const m = /^r(\d+)$/i.exec(s.trim()); if (!m || +m[1] > 15) throw new Error('register expected: ' + s); return +m[1]; };
const IMP = { stop: [0x00], nop: [0x01], cache: [0x02], lsr: [0x03], rol: [0x04], loop: [0x3c], alt1: [0x3d], alt2: [0x3e], alt3: [0x3f], plot: [0x4c], rpix: [0x3d, 0x4c],
  swap: [0x4d], color: [0x4e], cmode: [0x3d, 0x4e], not: [0x4f], merge: [0x70], sbk: [0x90], sex: [0x95], asr: [0x96], div2: [0x3d, 0x96], ror: [0x97], lob: [0x9e], fmult: [0x9f],
  lmult: [0x3d, 0x9f], hib: [0xc0], getc: [0xdf], ramb: [0x3e, 0xdf], romb: [0x3f, 0xdf], getb: [0xef], getbh: [0x3d, 0xef], getbl: [0x3e, 0xef], getbs: [0x3f, 0xef] };
const BR = { bra: 0x05, blt: 0x06, bge: 0x07, bne: 0x08, beq: 0x09, bpl: 0x0a, bmi: 0x0b, bcc: 0x0c, bcs: 0x0d, bvc: 0x0e, bvs: 0x0f };
// op rN / op #n: base opcode, prefix for the register form, prefix for the immediate form
const ALU = { add: [0x50, [], [0x3e]], adc: [0x50, [0x3d], [0x3f]], sub: [0x60, [], [0x3e]], sbc: [0x60, [0x3d], null], cmp: [0x60, [0x3f], null],
  and: [0x70, [], [0x3e]], bic: [0x70, [0x3d], [0x3f]], mult: [0x80, [], [0x3e]], umult: [0x80, [0x3d], [0x3f]], or: [0xc0, [], [0x3e]], xor: [0xc0, [0x3d], [0x3f]] };

export function assembleGsu(source, origin) {
  const lines = source.split(/\r?\n/).map((l) => l.replace(/;.*/, '').trim()).filter(Boolean);
  let labels = {};
  const pass = (final) => {
    const out = []; const found = { ...labels };
    const ev = (s) => {
      s = s.trim().replace(/^#/, '');
      const js = s.replace(/\$([0-9a-fA-F]+)/g, '0x$1').replace(/\b([A-Za-z_]\w*)\b/g, (m, n) => {
        if (/^0x/i.test(m)) return m;
        if (n in found) return found[n];
        if (final) throw new Error('undefined ' + n);
        return origin;
      });
      return Function(`"use strict"; return (${js});`)();
    };
    for (let line of lines) {
      let m = /^(\w+):\s*(.*)$/.exec(line);
      if (m) { found[m[1]] = origin + out.length; line = m[2]; if (!line) continue; }
      m = /^(\w+)\s*=\s*(.+)$/.exec(line);
      if (m) { found[m[1]] = ev(m[2]); continue; }
      const [, op0, rest = ''] = /^(\w+)\s*(.*)$/.exec(line);
      const op = op0.toLowerCase(); const a = rest ? rest.split(',').map((s) => s.trim()) : [];
      const E = (...b) => out.push(...b.map((v) => v & 255));
      const paren = (s) => s.replace(/^\(|\)$/g, '');
      if (op in IMP) E(...IMP[op]);
      else if (op in BR) { const d = ev(a[0]) - (origin + out.length + 2); if (final && (d < -128 || d > 127)) throw new Error('branch out of range: ' + line); E(BR[op], d); }
      else if (op === 'to') E(0x10 + reg(a[0]));
      else if (op === 'with') E(0x20 + reg(a[0]));
      else if (op === 'from') E(0xb0 + reg(a[0]));
      else if (op === 'move') E(0x20 + reg(a[1]), 0x10 + reg(a[0]));                 // move rd, rs
      else if (op === 'stw' || op === 'stb') { if (op === 'stb') E(0x3d); E(0x30 + reg(paren(a[0]))); }
      else if (op === 'ldw' || op === 'ldb') { if (op === 'ldb') E(0x3d); E(0x40 + reg(paren(a[0]))); }
      else if (op === 'jmp') E(0x90 + reg(a[0]));
      else if (op === 'link') E(0x90 + ev(a[0]));
      else if (op === 'inc') E(0xd0 + reg(a[0]));
      else if (op === 'dec') E(0xe0 + reg(a[0]));
      else if (op === 'ibt') E(0xa0 + reg(a[0]), ev(a[1]));
      else if (op === 'iwt') { const v = ev(a[1]); E(0xf0 + reg(a[0]), v, v >> 8); }
      else if (op === 'lm') { const v = ev(paren(a[1])); E(0x3d, 0xf0 + reg(a[0]), v, v >> 8); }
      else if (op === 'sm') { const v = ev(paren(a[0])); E(0x3e, 0xf0 + reg(a[1]), v, v >> 8); }
      else if (op in ALU) {
        const [base, pr, pi] = ALU[op];
        if (a[0].startsWith('#')) { if (!pi) throw new Error(op + ' has no immediate form'); E(...pi, base + ev(a[0])); }
        else E(...pr, base + reg(a[0]));
      } else throw new Error('unknown instruction: ' + line);
    }
    labels = found;
    return Buffer.from(out);
  };
  pass(false); pass(false);
  const code = pass(true);
  return { code, labels };
}
