// SPC7110 graphics compression: the packer for the chip's decompressor (an adaptive binary arithmetic coder with
// pixel-context modelling, as documented by neviksti and talarubi and implemented in ares' decompressor.cpp).
// decompress() mirrors the chip; compress() runs the same model and works out the number whose decoding gives the data.

const EV = [ // probability of the likelier symbol, next state after {likely, unlikely}
  [0x5a, 1, 1], [0x25, 2, 6], [0x11, 3, 8], [0x08, 4, 10], [0x03, 5, 12], [0x01, 5, 15],
  [0x5a, 7, 7], [0x3f, 8, 19], [0x2c, 9, 21], [0x20, 10, 22], [0x17, 11, 23], [0x11, 12, 25], [0x0c, 13, 26], [0x09, 14, 28], [0x07, 15, 29], [0x05, 16, 31], [0x04, 17, 32], [0x03, 18, 34], [0x02, 5, 35],
  [0x5a, 20, 20], [0x48, 21, 39], [0x3a, 22, 40], [0x2e, 23, 42], [0x26, 24, 44], [0x1f, 25, 45], [0x19, 26, 46], [0x15, 27, 25], [0x11, 28, 26], [0x0e, 29, 26], [0x0b, 30, 27], [0x09, 31, 28], [0x08, 32, 29], [0x07, 33, 30], [0x05, 34, 31], [0x04, 35, 33], [0x04, 36, 33], [0x03, 37, 34], [0x02, 38, 35], [0x02, 5, 36],
  [0x58, 40, 39], [0x4d, 41, 47], [0x43, 42, 48], [0x3b, 43, 49], [0x34, 44, 50], [0x2e, 45, 51], [0x29, 46, 44], [0x25, 24, 45],
  [0x56, 48, 47], [0x4f, 49, 47], [0x47, 50, 48], [0x41, 51, 49], [0x3c, 52, 50], [0x37, 43, 51],
];

const moveToFront = (list, v) => { const i = list.indexOf(v); if (i > 0) { list.splice(i, 1); list.unshift(v); } };

// The pixel model shared by both directions. symbol(lpsOffset) decides each binary symbol (0 = the likelier one).
function model(bpp, nPixels, symbol, wanted) {
  const ctx = Array.from({ length: 5 }, () => Array.from({ length: 15 }, () => ({ p: 0, swap: 0 })));
  let range = 0x100, output = 0;
  const history = new Array(16).fill(0);                 // the pixels so far, newest first
  const colormap = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
  const result = [];
  for (let n = 0; n < nPixels; n++) {
    let diff = 0, map = colormap.slice();
    if (bpp > 1) {
      // the neighbours: the pixel before, and the two a row of 8 back
      const pa = history[bpp === 2 ? 1 : 0], pb = history[7], pc = history[8];
      if (pa !== pb || pb !== pc) {
        const match = pa ^ pb ^ pc;
        diff = 4;
        if ((match ^ pc) === 0) diff = 3;
        if ((match ^ pb) === 0) diff = 2;
        if ((match ^ pa) === 0) diff = 1;
      }
      moveToFront(colormap, pa);
      map = colormap.slice();
      moveToFront(map, pc); moveToFront(map, pb); moveToFront(map, pa);
    }
    // what must come out, when packing
    let target = 0;
    if (wanted) target = bpp > 1 ? map.indexOf(wanted[n]) : wanted[n] ^ history[15];
    if (wanted && bpp > 1 && (target < 0 || target >= (1 << bpp))) throw new Error(`pixel ${n}: colour ${wanted[n]} not reachable`);
    for (let plane = 0; plane < bpp; plane++) {
      const bit = bpp > 1 ? 1 << plane : 1 << (n & 3);
      const hist = (bit - 1) & output;
      let set = 0;
      if (bpp === 1) set = (n % 8) >= 4 ? 1 : 0;
      if (bpp === 2) set = diff;
      if (plane >= 2 && hist <= 1) set = diff;
      const c = ctx[set][bit + hist - 1];
      const [prob, nextMps, nextLps] = EV[c.p];
      const offset = (range - prob) & 0xff;
      const want = wanted ? ((target >> (bpp - 1 - plane)) & 1) ^ c.swap : undefined;
      const sym = symbol(offset, want);
      output = ((output << 1) | (sym ^ c.swap)) & 0xff;
      if (sym === 0) range = offset; else range -= offset;
      while (range <= 0x7f) { c.p = sym ? nextLps : nextMps; range <<= 1; symbol.shift(); }
      if (sym === 1 && prob > 0x55) c.swap ^= 1;
    }
    let index = output & ((1 << bpp) - 1);
    if (bpp === 1) index ^= history[15] & 1;
    const pixel = bpp === 1 ? index : map[index];
    history.pop(); history.unshift(pixel);
    result.push(pixel);
  }
  return result;
}

/** pixels (left to right, 8 per tile row, tile after tile) -> the packed stream */
export function packPixels(pixels, bpp) {
  let low = 0n, offset = 0n, shifts = 0;
  const symbol = (lps, want) => {
    if (want === 1) low += BigInt(lps) << 8n;          // the unlikely symbol: the upper part of the range
    return want;
  };
  symbol.shift = () => { low <<= 1n; shifts++; };
  model(bpp, pixels.length, symbol, pixels);
  // the stream's first 16 bits are the starting number; each shift takes one more bit
  const totalBits = 16 + shifts, pad = (8 - (totalBits % 8)) % 8;
  const value = low << BigInt(pad), bytes = (totalBits + pad) / 8;
  const out = Buffer.alloc(bytes + 2);
  let v = value;
  for (let i = bytes - 1; i >= 0; i--) { out[i] = Number(v & 0xffn); v >>= 8n; }
  return out;
}

/** the chip's side, to check the packer */
export function unpackPixels(stream, bpp, nPixels) {
  let at = 2, bits = 8, input = (stream[0] << 8) | stream[1];
  const symbol = (lps) => { const s = input >= (lps << 8) ? 1 : 0; if (s) input -= lps << 8; return s; };
  symbol.shift = () => { input = (input << 1) & 0xffff; if (--bits === 0) { bits = 8; input = (input + (stream[at++] || 0)) & 0xffff; } };
  return model(bpp, nPixels, symbol, null);
}

/** SNES 4bpp tiles (32 bytes each) <-> the pixel order the chip codes them in */
export function tilesToPixels(tiles) {
  const px = [];
  for (let t = 0; t < tiles.length; t += 32) for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
    const s = 7 - x;
    // (the chip puts a pixel's highest bit in bit plane 0: the planes go in reversed)
    px.push((((tiles[t + y * 2] >> s) & 1) << 3) | (((tiles[t + y * 2 + 1] >> s) & 1) << 2) | (((tiles[t + 16 + y * 2] >> s) & 1) << 1) | ((tiles[t + 17 + y * 2] >> s) & 1));
  }
  return px;
}
export const compressTiles4 = (tiles) => packPixels(tilesToPixels(tiles), 4);
