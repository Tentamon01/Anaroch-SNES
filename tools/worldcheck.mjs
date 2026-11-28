// Compares every tile the test emulator shows with the data ROM's record of the place the hero is in.
export function world(s, sy, rom) {
  const data = rom.subarray(0x200000);
  const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
  const rd = (addr) => data[((rom[sy.place_page - 0x8000 + w(sy.placeId) * 2] << 20) | (addr - 0xD00000))];
  const cell = (c, r) => {
    if (c >= w(sy.mapW) || r >= w(sy.mapH)) return 0;
    const p = 0x1C000 + r * 3, a = w(p) | (s.wram[p + 2] << 16);
    return rd(a + c * 2) | (rd(a + c * 2 + 1) << 8);
  };
  return {
    /** -> {checked, bad, first}; nothing is checked while the picture is being sent */
    tiles() {
      const out = { checked: 0, bad: 0, first: null };
      if (w(sy.sq) || w(sy.inMenu) || w(sy.rebuild) || !(s.reg[0x420C] & 0x80)) return out;
      const camx = w(sy.camx), camy = w(sy.camy);
      // (the camera in the variables may be a frame ahead of what has been sent: check what the scroll registers show)
      if ((camx & 0x3FF) !== (s.scroll.h & 0x3FF) || (camy & 0x3FF) !== (s.scroll.v & 0x3FF)) return out;
      const tileBank = w(sy.tileBank);
      for (let r = (camy + 9) >> 3; r <= (camy + 216) >> 3; r++) for (let c = camx >> 3; c <= (camx + 255) >> 3; c++) {
        const mapAt = (0x4000 + ((r & 31) * 32) + (c & 31) + (c & 32 ? 0x400 : 0)) * 2;
        const e = s.vram[mapAt] | (s.vram[mapAt + 1] << 8), slot = e & 0x3FF, pal = (e >> 10) & 7;
        const word = cell(c, r), id = word & 0x1FFF, want = id ? (word >> 13) + 2 : -1;
        let ok = id === 0 || pal === want;
        if (ok) {
          const at = ((tileBank + (id >> 11)) << 16) + (id & 2047) * 32;
          for (let i = 0; i < 32; i++) if (s.vram[slot * 32 + i] !== (id ? rd(at + i) : 0)) { ok = false; break; }
        }
        out.checked++;
        if (!ok) { out.bad++; out.first ||= { c, r, slot, pal, want, id, camx, camy }; }
      }
      return out;
    },
  };
}
