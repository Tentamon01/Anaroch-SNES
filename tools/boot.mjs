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
