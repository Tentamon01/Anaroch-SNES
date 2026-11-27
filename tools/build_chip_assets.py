"""Assets of the dual-chip test: the picture the SPC7110 unpacks, the textures the SuperFX scales, a 2bpp font.
Uses files made by tools/build_assets.py. Writes out/chip/*.bin and out/chip/chip.inc"""
import os, re
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'out'); C = os.path.join(OUT, 'chip'); os.makedirs(C, exist_ok=True)
bgr = lambda c: ((c[2] >> 3) << 10) | ((c[1] >> 3) << 5) | (c[0] >> 3)
px_of = lambda im: list(im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata())
def enc4(px):
    o = bytearray(32)
    for y in range(8):
        for x in range(8):
            v = px[y * 8 + x]; bit = 0x80 >> x
            if v & 1: o[y * 2] |= bit
            if v & 2: o[y * 2 + 1] |= bit
            if v & 4: o[16 + y * 2] |= bit
            if v & 8: o[17 + y * 2] |= bit
    return bytes(o)
# the picture: a piece of the graveyard
im = Image.open(os.path.join(OUT, 'world_preview.png')).convert('RGB').crop((440, 72, 696, 296))
q = im.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
pal = q.getpalette()[:45]
ix = [v + 1 for v in px_of(q)]
tiles = bytearray()
for ty in range(28):
    for tx in range(32):
        tiles += enc4([ix[(ty * 8 + y) * 256 + tx * 8 + x] for y in range(8) for x in range(8)])
open(os.path.join(C, 'picture.bin'), 'wb').write(tiles)
picpal = [0] + [bgr(pal[i * 3:i * 3 + 3]) for i in range(15)]
# textures: hero, ghoul, skeleton walking toward the camera (from the 2x preview sheets; their grey ground is clear)
frames = []
for name in ('hero', 'ghoul', 'skel'):
    sh = Image.open(os.path.join(OUT, f'{name}_preview.png')).convert('RGB')
    for pose in (2, 3, 4, 5):
        frames.append(sh.crop((pose * 64, 0, pose * 64 + 64, 64)).resize((32, 32), Image.NEAREST))
solid = [p for f in frames for p in px_of(f) if p != (50, 50, 50)]
qi = Image.new('RGB', (len(solid), 1)); qi.putdata(solid)
tq = qi.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
tp = tq.getpalette()[:45]; cols = [tuple(tp[i * 3:i * 3 + 3]) for i in range(15)]
near = lambda c: 1 + min(range(15), key=lambda i: sum((c[k] - cols[i][k]) ** 2 for k in range(3)))
tex = bytearray()
for f in frames:
    tex += bytes(0 if p == (50, 50, 50) else near(p) for p in px_of(f))
open(os.path.join(C, 'textures.bin'), 'wb').write(tex)
texpal = [0] + [bgr(c) for c in cols]
# the game's font as 2bpp tiles on a dark ground
data = open(os.path.join(ROOT, 'src', 'data.inc')).read()
charmap = [int(v) for v in re.search(r'^charmap: \.byte (.*)$', data, re.M).group(1).split(',')]
base = int(re.search(r'FONT_BASE = (\d+)', data).group(1))
hud = open(os.path.join(OUT, 'hud_tiles.bin'), 'rb').read()
font = bytearray(16)                                   # tile 0: clear
used = sorted(set(v for v in charmap if v))
remap = {}
for t in [base] + [u for u in used if u != base]:
    src = hud[t * 32:t * 32 + 32]; o = bytearray(16)
    for y in range(8):
        for x in range(8):
            bit = 0x80 >> x
            v = sum(((src[(y * 2) + (p & 1) + (16 if p > 1 else 0)] & bit) != 0) << p for p in range(4))
            c = 3 if v == 15 else 1
            if c & 1: o[y * 2] |= bit
            if c & 2: o[y * 2 + 1] |= bit
    remap[t] = len(font) // 16; font += o
open(os.path.join(C, 'font.bin'), 'wb').write(font)
chars = [remap.get(v, remap[base]) for v in charmap]
w = lambda v: ', '.join('$%04X' % x for x in v)
open(os.path.join(C, 'chip.inc'), 'w').write(
    f'FONT_BYTES = {len(font)}\npicpal: .word {w(picpal)}\ntexpal: .word {w(texpal)}\ntxtpal: .word 0, $0842, $2D6B, $7FFF\n'
    )
open(os.path.join(C, 'charmap.bin'), 'wb').write(bytes(chars))
print('picture', len(tiles), 'textures', len(tex), 'font', len(font))
