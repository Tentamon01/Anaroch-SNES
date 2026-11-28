// Walks the hero into the gate of this place that leads to `place` (0 the graveyard, 1 the town, 2.. its houses).
export function travel(s, sy, place) {
  const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
  const pw = (a, v) => { s.wram[a] = v & 255; s.wram[a + 1] = (v >> 8) & 255; };
  for (let i = 0; i < w(sy.nGates); i++) {
    const g = Array.from({ length: 5 }, (_, k) => w(0x1C800 + i * 16 + k * 2));
    if (g[4] !== place) continue;
    pw(sy.ex, ((g[0] + g[2]) >> 1) * 16); pw(sy.ey, ((g[1] + g[3]) >> 1) * 16);
    for (let n = 0; n < 200; n++) { s.pad = 0; s.runFrame(400000); if (w(sy.placeId) === place && w(sy.mode) === 0 && !w(sy.rebuild)) break; }
    for (let n = 0; n < 6; n++) s.runFrame(400000);
    if (w(sy.placeId) !== place) throw new Error('the gate did not lead there');
    return;
  }
  throw new Error('no gate there from here');
}
// Brings a freshly started test emulator to the game: through the studio's splash (Start passes it by).
export function boot(s, sy, skip = true) {
  const w = (a) => s.wram[a] | (s.wram[a + 1] << 8);
  for (let n = 0; n < 900 && w(sy.frame) < 2; n++) {
    s.pad = skip && w(sy.spk) > 14 && n % 2 ? 0x1000 : 0;
    s.runFrame(400000);
  }
  if (w(sy.frame) < 2) throw new Error('the game did not start');
  s.pad = 0;
  for (let n = 0; n < 20; n++) s.runFrame(400000);
}
