"""A mock screen of the remake: the pre-rendered graveyard (palette-limited) with a braziers' glow, the characters at
two sizes and the HUD. python tools/mockup.py  -> out/step0/mockup.png  (needs tile_budget.py --exact first)"""
import os, re, math, json
from PIL import Image, ImageEnhance, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N64 = os.path.join(os.path.dirname(ROOT), 'Anaroch_N64_Sprite')
S0 = os.path.join(ROOT, 'out', 'step0')
P = json.load(open(os.path.join(S0, 'gymoon_t1.json')))
world = Image.open(os.path.join(S0, 'gymoon_t1_flat_all_pal.png')).convert('RGB')
src = open(os.path.join(N64, 'src', 'area_graveyard.h')).read()
lights = [(float(a), float(b)) for a, _, b in re.findall(r'\{(-?[\d.]+)f, (-?[\d.]+)f, (-?[\d.]+)f\}', src.split('gy_lights')[1].split('gy_spawns')[0])]
to_px = lambda x, z: (x * P['x'][0] + z * P['z'][0] - P['minX'], x * P['x'][1] + z * P['z'][1] - P['minY'])
a, c = P['x'][0], P['z'][0]; b, d = P['x'][1], P['z'][1]; det = a * d - c * b
def ground(px, py):
    sx, sy = px + P['minX'], py + P['minY']
    return ((d * sx - c * sy) / det, (-b * sx + a * sy) / det)
# the braziers' glow as the SNES would draw it: a 3-colour layer (background 3) added to the picture by colour math,
# its rings dithered
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
ADD = [(0, 0, 0), (24, 12, 0), (48, 24, 0), (72, 40, 8)]
lit = world.copy(); lp = lit.load()
glow = [0.0] * (world.width * world.height)
for lx, lz in lights:
    cx, cy = to_px(lx, lz)
    for y in range(max(0, int(cy) - 60), min(world.height, int(cy) + 60)):
        for x in range(max(0, int(cx) - 80), min(world.width, int(cx) + 80)):
            gx, gz = ground(x, y)
            d_ = math.hypot(gx - lx, gz - lz)
            if d_ < 4.2: glow[y * world.width + x] = max(glow[y * world.width + x], 3.2 * (1 - d_ / 4.2) ** 1.1)
for y in range(world.height):
    for x in range(world.width):
        v = glow[y * world.width + x]
        if v <= 0: continue
        level = min(3, int(v) + (1 if (v - int(v)) * 16 > BAYER[y & 3][x & 3] else 0))
        if level:
            r, g, b = lp[x, y]; a = ADD[level]
            lp[x, y] = (min(255, r + a[0]), min(255, g + a[1]), min(255, b + a[2]))

def sheet_frame(name, a_, d_, i, folder=None):
    hdr = open(os.path.join(folder or os.path.join(N64, 'src'), f'spr_{name}.h')).read()
    W = int(re.search(r'_W (\d+)', hdr).group(1)); H = int(re.search(r'_H (\d+)', hdr).group(1))
    AY = int(re.search(r'ANCHOR_Y (\d+)', hdr).group(1)); ppm = int(re.search(r'SPR_PPM (\d+)', hdr).group(1))
    cells = [int(n) for n in re.findall(r'-?\d+', re.search(r'_cell\[5\]\[8\] = \{(.*?)\};', hdr, re.S).group(1))]
    sh = Image.open(os.path.join(folder or os.path.join(N64, 'assets'), f'spr_{name}_{a_}_{d_}.png')).convert('RGBA')
    cw, ch, x0, y0 = cells[(a_ * 8 + d_) * 4:(a_ * 8 + d_) * 4 + 4]
    full = Image.new('RGBA', (W, H)); full.paste(sh.crop((i * cw, 0, i * cw + cw, ch)), (x0, y0))
    return full, AY, ppm

def sprite(name, a_, d_, i, ppm_out, folder=None):
    full, ay, ppm = sheet_frame(name, a_, d_, i, folder)
    k = ppm_out / ppm
    im = full.resize((round(full.width * k), round(full.height * k)), Image.BOX)
    al = im.split()[3].point(lambda v: 255 if v >= 120 else 0)
    rgb = im.convert('RGB').quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    out = Image.new('RGBA', im.size); out.paste(rgb, (0, 0), al)
    return out, ay * k

vial = Image.open(os.path.join(N64, 'assets', 'hud_vial_full.png')).convert('RGBA').resize((16, 48), Image.LANCZOS)
pot = Image.open(os.path.join(N64, 'assets', 'icons', 'i120.png')).convert('RGBA').resize((12, 12), Image.LANCZOS)
centre = to_px(1.0, 3.2)
def screen(ppm_out, label):
    left, top = int(centre[0]) - 128, int(centre[1]) - 120
    im = lit.crop((left, top, left + 256, top + 224)).convert('RGBA')
    cast = [('hx10', 2, 6, 5, 1.0, 3.2, None), ('ghoul', 1, 2, 3, 3.0, 2.4, None), ('ghoul', 2, 1, 4, -0.6, 4.6, None),
            ('skel', 2, 6, 6, 4.6, 4.4, os.path.join(ROOT, 'out', 'skel_src')), ('ghoul', 0, 0, 1, -3.0, 1.0, None)]
    for name, a_, d_, i, x, z, folder in sorted(cast, key=lambda q: to_px(q[4], q[5])[1]):
        s, foot = sprite(name, a_, d_, i, ppm_out, folder)
        px, py = to_px(x, z)
        ImageDraw.Draw(im, 'RGBA').ellipse((px - left - 8, py - top - 3, px - left + 8, py - top + 3), fill=(0, 0, 0, 90))
        im.alpha_composite(s, (int(px - left - s.width / 2), int(py - top - foot)))
    im.alpha_composite(vial, (8, 164))
    dr = ImageDraw.Draw(im)
    for k in range(4):
        x = 96 + k * 18
        dr.rectangle((x, 202, x + 15, 217), fill=(20, 16, 12, 255), outline=(220, 170, 40, 255) if k == 0 else (70, 58, 40, 255))
        if k < 2: im.alpha_composite(pot, (x + 2, 204))
    r, g, bl, _ = im.split()
    return Image.merge('RGB', [ch.point(lambda v: v & 248) for ch in (r, g, bl)])

a1, a2 = screen(18, 'small'), screen(24, 'tall')
out = Image.new('RGB', (1048, 448), (200, 0, 200))
out.paste(a1.resize((512, 448), Image.NEAREST), (0, 0)); out.paste(a2.resize((512, 448), Image.NEAREST), (536, 0))
d_ = ImageDraw.Draw(out)
for x, t in ((6, 'A: characters 32x32 (to scale)'), (542, 'B: characters a third bigger')):
    d_.rectangle((x - 2, 4, x + 6 * len(t) + 2, 18), fill=(0, 0, 0)); d_.text((x, 6), t, fill=(255, 220, 90))
out.save(os.path.join(S0, 'mockup.png'))
a1.resize((768, 672), Image.NEAREST).save(os.path.join(S0, 'mockup_a.png'))
a2.resize((768, 672), Image.NEAREST).save(os.path.join(S0, 'mockup_b.png'))
print('wrote out/step0/mockup.png')
