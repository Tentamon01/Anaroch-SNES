"""Builds the SNES assets of Anaroch from the N64 sprite version (Anaroch_N64_Sprite).

Reads:  ../Anaroch_N64_Sprite/assets/spr_<hero|ghoul|skel>_<anim>_<dir>.png + src/spr_<name>.h  (the game's 8-direction sheets)
        ../Anaroch_N64_Sprite/assets/hud_vial_*.png, assets/icons/i120.png                         (life vial, potion)
        ../Anaroch_N64_Sprite/src/area_graveyard.h                                                (collision grid, braziers, spawns)
Writes: out/*.bin and src/data.inc
"""
import os, re, math, random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
N64 = os.path.join(os.path.dirname(ROOT), 'Anaroch_N64_Sprite')
ASSETS = os.path.join(N64, 'assets')
GYH = os.path.join(N64, 'src', 'area_graveyard.h')
OUT = os.path.join(ROOT, 'out')
os.makedirs(OUT, exist_ok=True)


def bgr555(rgb):
    r, g, b = rgb[:3]
    return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)


def enc_tile(px, bpp=4):  # 64 indices -> SNES planar tile
    out = bytearray(8 * bpp)
    for y in range(8):
        for x in range(8):
            v = px[y * 8 + x]; bit = 0x80 >> x
            if v & 1: out[y * 2] |= bit
            if v & 2: out[y * 2 + 1] |= bit
            if bpp == 4:
                if v & 4: out[16 + y * 2] |= bit
                if v & 8: out[16 + y * 2 + 1] |= bit
    return bytes(out)


def tiles_of(img):
    w, h = img.size
    px = list(img.get_flattened_data()) if hasattr(img, 'get_flattened_data') else list(img.getdata())
    return [[[px[(ty * 8 + y) * w + tx * 8 + x] for y in range(8) for x in range(8)] for tx in range(w // 8)] for ty in range(h // 8)]


def quantize(images, n):
    """one palette of n colours for the opaque pixels of RGBA images -> (colours, nearest())"""
    opaque = []
    for im in images:
        for p in (im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()):
            if p[3] >= 128: opaque.append(p[:3])
    q_in = Image.new('RGB', (len(opaque), 1)); q_in.putdata(opaque)
    qi = q_in.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = qi.getpalette()[:n * 3]
    cols = [tuple(pal[i * 3:i * 3 + 3]) for i in range(n)]
    cache = {}
    def nearest(c):
        k = (c[0] >> 2, c[1] >> 2, c[2] >> 2)
        if k not in cache:
            cache[k] = min(range(n), key=lambda i: sum((c[j] - cols[i][j]) ** 2 for j in range(3))) + 1
        return cache[k]
    return cols, nearest


def index_img(im, nearest):
    out = Image.new('P', im.size)
    out.putdata([0 if p[3] < 128 else nearest(p) for p in (im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata())])
    return out


# ------------------------------------------------------------------ characters (the N64 game's sheets)
FH = 60
SC = 0.75
PICK = [(0, 0), (0, 3), (1, 0), (1, 3), (1, 6), (1, 9), (2, 1), (2, 4), (2, 7), (2, 10), (3, 1), (4, 2), (4, 5), (4, 8), (4, 11)]
FRAMES = len(PICK)  # 0-1 idle, 2-5 walk, 6-9 attack, 10 hit, 11-14 death


def load_char(name, folder=None):
    """the N64 game's sheets; folder: our own renders (tools/make_skeleton.mjs)"""
    hdr = open(os.path.join(folder or os.path.join(N64, 'src'), f'spr_{name}.h')).read()
    W = int(re.search(r'SPR_%s_W (\d+)' % name.upper(), hdr).group(1))
    FH = int(re.search(r'SPR_%s_H (\d+)' % name.upper(), hdr).group(1))
    AY = int(re.search(r'SPR_%s_ANCHOR_Y (\d+)' % name.upper(), hdr).group(1))
    cells = [int(n) for n in re.findall(r'-?\d+', re.search(r'_cell\[5\]\[8\] = \{(.*?)\};', hdr, re.S).group(1))]
    sheets = {}
    def frame(a, d, i):
        if (a, d) not in sheets:
            sheets[(a, d)] = Image.open(os.path.join(folder or ASSETS, f'spr_{name}_{a}_{d}.png')).convert('RGBA')
        sh = sheets[(a, d)]
        cw, ch, x0, y0 = cells[(a * 8 + d) * 4:(a * 8 + d) * 4 + 4]
        n = sh.width // cw
        i = min(i, n - 1)
        full = Image.new('RGBA', (W, FH), (0, 0, 0, 0))
        full.paste(sh.crop((i * cw, 0, i * cw + cw, ch)), (x0, y0))
        return full
    ppm = int(re.search(r'SPR_PPM (\d+)', hdr).group(1))
    SCALE = SC * 24 / ppm
    w, h = round(W * SCALE), round(FH * SCALE)
    wx0 = (w - 32) // 2
    wy0 = round(AY * SCALE) - 30          # the feet on row 30
    seq = []
    for d in range(8):
        row = []
        for a, i in PICK:
            f = frame(a, d, i)
            r, g, b, al = f.split()
            z = Image.new('L', f.size, 0)
            pre = Image.merge('RGBA', (Image.composite(r, z, al), Image.composite(g, z, al), Image.composite(b, z, al), al))
            sm = pre.resize((w, h), Image.BOX).crop((wx0, wy0, wx0 + 32, wy0 + 32))
            px = sm.load()  # un-premultiply
            for y in range(32):
                for x in range(32):
                    rr, gg, bb, aa = px[x, y]
                    if aa: px[x, y] = (min(255, rr * 255 // aa), min(255, gg * 255 // aa), min(255, bb * 255 // aa), aa)
            if folder:   # our skeleton: a little more contrast so bone and shadow part at this size
                from PIL import ImageEnhance
                al = sm.split()[3]
                rgb = ImageEnhance.Brightness(ImageEnhance.Contrast(sm.convert('RGB')).enhance(1.2)).enhance(0.86)
                sm = Image.merge('RGBA', rgb.split() + (al,))
            row.append(sm)
        seq.append(row)
    cols, nearest = quantize([f for row in seq for f in row], 15)
    frames = []
    for d in range(8):
        for f in seq[d]:
            frames.append(b''.join(enc_tile(t) for row in tiles_of(index_img(f, nearest)) for t in row))
    return frames, cols, seq


def pal16(cols, f=lambda c: c):
    return [0] + [bgr555(f(c)) for c in cols] + [0] * (15 - len(cols))


hero, hero_cols, hero_seq = load_char('hx10')   # the hero with a sword (main.c: spr_hx<family><look>)
ghoul, ghoul_cols, ghoul_seq = load_char('ghoul')
SKEL = os.path.join(OUT, 'skel_src')
assert os.path.exists(os.path.join(SKEL, 'spr_skel.h')), 'run: node tools/make_skeleton.mjs'
skel, skel_cols, skel_seq = load_char('skel', SKEL)

def blue(c): return (int(c[0] * 0.55), int(c[1] * 0.7), min(255, int(c[2] * 1.2 + 60)))
def red(c): return (min(255, int(c[0] * 0.6 + 110)), int(c[1] * 0.45), int(c[2] * 0.45))
def flash(c): return tuple(min(255, int(v * 0.4 + 160)) for v in c)

def sheet_preview(seq, name):
    im = Image.new('RGBA', (32 * FRAMES, 32 * 8), (50, 50, 50, 255))
    for d in range(8):
        for i, f in enumerate(seq[d]): im.alpha_composite(f, (i * 32, d * 32))
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(OUT, name))
sheet_preview(hero_seq, 'hero_preview.png'); sheet_preview(ghoul_seq, 'ghoul_preview.png'); sheet_preview(skel_seq, 'skel_preview.png')

# ------------------------------------------------------------------ small sprites: potion, gold, tome, arrows (16x16)
def potion_img():
    return Image.open(os.path.join(ASSETS, 'icons', 'i120.png')).convert('RGBA').resize((16, 16), Image.LANCZOS)

def gold_img():
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for x, y in ((3, 9), (8, 10), (5, 6), (10, 7), (7, 3)):
        d.ellipse((x, y, x + 4, y + 3), fill=(150, 100, 20, 255)); d.ellipse((x, y, x + 3, y + 2), fill=(240, 196, 60, 255)); d.point((x + 1, y), fill=(255, 245, 170, 255))
    return im

def tome_img():
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle((3, 3, 12, 13), fill=(70, 30, 20, 255)); d.rectangle((4, 3, 12, 12), fill=(120, 50, 30, 255))
    d.rectangle((4, 12, 12, 13), fill=(230, 220, 190, 255)); d.rectangle((7, 6, 9, 9), fill=(240, 196, 60, 255))
    return im

def arrow_img(d):
    dx, dy = [(0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1)][d]
    l = math.hypot(dx, dy); dx, dy = dx / l, dy / l
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); dr = ImageDraw.Draw(im)
    x0, y0, x1, y1 = 8 - dx * 6, 8 - dy * 6, 8 + dx * 6, 8 + dy * 6
    dr.line((x0, y0, x1, y1), fill=(150, 110, 70, 255), width=1)
    dr.line((x0, y0, x0 + dy * 2, y0 - dx * 2), fill=(230, 230, 230, 255)); dr.line((x0, y0, x0 - dy * 2, y0 + dx * 2), fill=(230, 230, 230, 255))
    dr.point((round(x1), round(y1)), fill=(210, 210, 220, 255))
    return im

smalls = [potion_img(), gold_img(), tome_img()] + [arrow_img(d) for d in range(8)]
small_cols, small_near = quantize(smalls, 15)
# tiles $80..$BF (4 rows of 16): the 16x16 pictures go at $80,$82,..,$8E then $A0,$A2,...
obj_static = bytearray(4 * 16 * 32)
for k, im in enumerate(smalls):
    base = 0x80 + (k % 8) * 2 + (k // 8) * 0x20
    t = tiles_of(index_img(im, small_near))
    for ty in range(2):
        for tx in range(2):
            o = (base + tx + ty * 16 - 0x80) * 32
            obj_static[o:o + 32] = enc_tile(t[ty][tx])

# ------------------------------------------------------------------ HUD on BG2 (4bpp): font, life vial, belt slots
HUD_RGB = [(0, 0, 0), (12, 10, 10), (40, 34, 30), (70, 58, 40), (220, 170, 40), (20, 16, 12)]   # 0-5 frames
vial_e = Image.open(os.path.join(ASSETS, 'hud_vial_empty.png')).convert('RGBA').resize((16, 48), Image.LANCZOS)
vial_f = Image.open(os.path.join(ASSETS, 'hud_vial_full.png')).convert('RGBA').resize((16, 48), Image.LANCZOS)
pot16 = potion_img()
vcols, vnear = quantize([vial_e, vial_f, pot16], 8)   # colours 6..13
hud_pal = [bgr555(c) for c in HUD_RGB] + [bgr555(c) for c in vcols] + [bgr555((90, 80, 70)), bgr555((235, 230, 225))]   # 14 shadow, 15 ink
def vidx(im):
    return Image.eval(index_img(im, vnear), lambda v: 0 if v == 0 else v + 5)

hud_tiles = []      # list of 64-pixel tiles
def add_tile(px):
    hud_tiles.append(px); return len(hud_tiles) - 1
add_tile([0] * 64)                          # 0: blank
PANEL = add_tile([1] * 64)                  # 1: panel ground

# font: 5x7 glyphs, ink 15 with a shadow 14 down-right
FONT = {
 ' ': '', '0': '01110 10001 10011 10101 11001 10001 01110', '1': '00100 01100 00100 00100 00100 00100 01110', '2': '01110 10001 00001 00110 01000 10000 11111',
 '3': '11110 00001 00001 01110 00001 00001 11110', '4': '00010 00110 01010 10010 11111 00010 00010', '5': '11111 10000 11110 00001 00001 10001 01110',
 '6': '00110 01000 10000 11110 10001 10001 01110', '7': '11111 00001 00010 00100 01000 01000 01000', '8': '01110 10001 10001 01110 10001 10001 01110',
 '9': '01110 10001 10001 01111 00001 00010 01100', 'A': '01110 10001 10001 11111 10001 10001 10001', 'B': '11110 10001 10001 11110 10001 10001 11110',
 'C': '01110 10001 10000 10000 10000 10001 01110', 'D': '11110 10001 10001 10001 10001 10001 11110', 'E': '11111 10000 10000 11110 10000 10000 11111',
 'F': '11111 10000 10000 11110 10000 10000 10000', 'G': '01110 10001 10000 10111 10001 10001 01111', 'H': '10001 10001 10001 11111 10001 10001 10001',
 'I': '01110 00100 00100 00100 00100 00100 01110', 'J': '00111 00010 00010 00010 00010 10010 01100', 'K': '10001 10010 10100 11000 10100 10010 10001',
 'L': '10000 10000 10000 10000 10000 10000 11111', 'M': '10001 11011 10101 10101 10001 10001 10001', 'N': '10001 10001 11001 10101 10011 10001 10001',
 'O': '01110 10001 10001 10001 10001 10001 01110', 'P': '11110 10001 10001 11110 10000 10000 10000', 'Q': '01110 10001 10001 10001 10101 10010 01101',
 'R': '11110 10001 10001 11110 10100 10010 10001', 'S': '01111 10000 10000 01110 00001 00001 11110', 'T': '11111 00100 00100 00100 00100 00100 00100',
 'U': '10001 10001 10001 10001 10001 10001 01110', 'V': '10001 10001 10001 10001 10001 01010 00100', 'W': '10001 10001 10001 10101 10101 10101 01010',
 'X': '10001 10001 01010 00100 01010 10001 10001', 'Y': '10001 10001 01010 00100 00100 00100 00100', 'Z': '11111 00001 00010 00100 01000 10000 11111',
 '/': '00001 00010 00010 00100 01000 01000 10000', ':': '00000 01100 01100 00000 01100 01100 00000', '+': '00000 00100 00100 11111 00100 00100 00000',
 '-': '00000 00000 00000 11111 00000 00000 00000', '.': '00000 00000 00000 00000 00000 01100 01100', '(': '00010 00100 01000 01000 01000 00100 00010',
 ')': '01000 00100 00010 00010 00010 00100 01000', '>': '01000 00100 00010 00001 00010 00100 01000', "'": '00100 00100 01000 00000 00000 00000 00000',
 '!': '00100 00100 00100 00100 00100 00000 00100',
}
CHARS = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/:+-.()>\'!'
FONT_BASE = len(hud_tiles)
for ch in CHARS:
    rows = FONT[ch].split() if FONT[ch] else []
    px = [0] * 64
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == '1':
                px[(y) * 8 + x + 1] = 15
    for y in range(7, -1, -1):
        for x in range(7, -1, -1):
            if px[y * 8 + x] == 15 and y < 7 and x < 7 and px[(y + 1) * 8 + x + 1] == 0:
                px[(y + 1) * 8 + x + 1] = 14
    add_tile(px)
CHARMAP = {c: FONT_BASE + i for i, c in enumerate(CHARS)}
FONT2_BASE = len(hud_tiles)                 # the same letters on the panel's ground (for the character window)
for i in range(len(CHARS)):
    add_tile([1 if v == 0 else v for v in hud_tiles[FONT_BASE + i]])

# vial: 2 columns x 6 rows; per tile row 9 states: 0 = empty .. 8 = full (cut from the top)
ve, vf = vidx(vial_e), vidx(vial_f)
VIAL_BASE = len(hud_tiles)
for row in range(6):
    for state in range(9):
        for col in range(2):
            px = []
            for y in range(8):
                for x in range(8):
                    gy = row * 8 + y
                    full = y >= 8 - state
                    px.append((vf if full else ve).getpixel((col * 8 + x, gy)))
            add_tile(px)
# liquid rows of the scaled vial (the N64's 15..121 of 128)
VIAL_TOP, VIAL_BOT = round(15 * 48 / 128), round(121 * 48 / 128)

# belt slots (16x16 = 2x2 tiles): frame normal / selected, empty / potion
BELT_BASE = len(hud_tiles)
p16 = vidx(pot16)
for sel in range(2):
    for content in range(2):
        im = Image.new('P', (16, 16), 5)
        d = ImageDraw.Draw(im); d.rectangle((0, 0, 15, 15), outline=4 if sel else 3)
        if content:
            sm = p16.resize((12, 12), Image.NEAREST)
            for y in range(12):
                for x in range(12):
                    v = sm.getpixel((x, y))
                    if v: im.putpixel((2 + x, 2 + y), v)
        t = tiles_of(im)
        for ty in range(2):
            for tx in range(2): add_tile(t[ty][tx])
hud_bin = b''.join(enc_tile(t) for t in hud_tiles)
assert len(hud_tiles) <= 512
# text palettes: 1 white, 2 gold, 3 red, 4 grey (only ink 15 differs)
def txt_pal(ink): return hud_pal[:15] + [bgr555(ink)]
hud_pals = hud_pal + txt_pal((240, 196, 60)) + txt_pal((230, 60, 50)) + txt_pal((150, 150, 150))
# ------------------------------------------------------------------ the world (Anaroch_N64_Sprite/src/area_graveyard.h)
src = open(GYH).read()
W = H = 72
grid = [int(v) for v in re.search(r'gy_grid\[GY_W \* GY_H\] = \{(.*?)\};', src, re.S).group(1).replace('\n', ' ').split(',') if v.strip()]
assert len(grid) == W * H
lights = [(float(a), float(b)) for a, _, b in re.findall(r'\{(-?[\d.]+)f, (-?[\d.]+)f, (-?[\d.]+)f\}', src.split('gy_lights')[1].split('gy_spawns')[0])]
spawns = [(float(a), float(b)) for a, b in re.findall(r'\{(-?[\d.]+)f, (-?[\d.]+)f\}', src.split('gy_spawns')[1].split('gy_south_gate')[0])]
start = tuple(float(v) for v in re.search(r'gy_start\[2\] = \{(.*?)f, (.*?)f\}', src).groups())
g = lambda x, z: grid[z * W + x] if 0 <= x < W and 0 <= z < H else 2

def h2(x, z, s=0):
    v = (x * 374761393 + z * 668265263 + s * 2246822519) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return (v ^ (v >> 16)) / 4294967295.0

def tex(name):
    return Image.open(os.path.join(ASSETS, f'tex_{name}.png')).convert('L')

def ramp(lum_img, dark, light, gamma=1.0):
    """greyscale -> RGB between two colours"""
    out = Image.new('RGB', lum_img.size)
    lo, hi = min(lum_img.getdata()), max(lum_img.getdata())
    px = []
    for v in lum_img.getdata():
        t = ((v - lo) / max(1, hi - lo)) ** gamma
        px.append(tuple(int(dark[i] + (light[i] - dark[i]) * t) for i in range(3)))
    out.putdata(px)
    return out

# the N64 graveyard's textures (meshlib: grass, dirt, stonewall, slate), tinted for the night
moss = tex('moss')
grass_t = ramp(Image.blend(tex('grass'), moss, 0.25), (14, 26, 16), (74, 100, 50), 1.1)
dirt_t = ramp(tex('dirt'), (38, 28, 20), (128, 98, 66), 0.9)
wall_t = ramp(tex('stonewall'), (34, 34, 44), (140, 140, 152), 1.0)
roof_t = ramp(tex('slate'), (22, 24, 34), (88, 92, 110), 1.0)

def crop(t, cx, cz, rot=False, m=4):
    if rot: t = t.rotate(90, expand=True)
    x, y = (cx % m) * 16, (cz % m) * 16
    return t.crop((x, y, x + 16, y + 16))

road = set()
for i in range(W):
    for j in (35, 36): road.add((i, j)); road.add((j, i))
is_road = lambda x, z: (x, z) in road and g(x, z) == 0

def wall_kind(x, z):
    if g(x, z) != 2: return None
    n = [g(x, z - 1) == 2, g(x + 1, z) == 2, g(x, z + 1) == 2, g(x - 1, z) == 2]
    if sum(n) <= 1 and not (n[0] and n[2]) and not (n[1] and n[3]): return None   # alone: a tree
    if all(n) and g(x - 1, z - 1) == 2 and g(x + 1, z + 1) == 2 and g(x + 1, z - 1) == 2 and g(x - 1, z + 1) == 2: return 'roof'
    if (n[1] or n[3]) and not (n[0] or n[2]): return 'h'
    if (n[0] or n[2]) and not (n[1] or n[3]): return 'v'
    return 'block'

def edge_shade(img, side, amount):
    """darken / lighten a strip of the cell"""
    px = img.load()
    for i in range(16):
        for k in range(3):
            x, y = {'n': (i, k), 's': (i, 15 - k), 'w': (k, i), 'e': (15 - k, i)}[side]
            f = amount * (3 - k) / 3
            px[x, y] = tuple(max(0, min(255, int(c + (255 - c if f > 0 else c) * f))) for c in px[x, y])
    return img

def cell_image(x, z):
    """(group, key, RGB 16x16) of a cell's ground"""
    k = wall_kind(x, z)
    if k == 'roof':
        return 'stone', ('roof', x % 2, z % 2), crop(roof_t, x, z, m=2)
    if k in ('h', 'v', 'block'):
        im = crop(wall_t, x, z, rot=(k == 'v'), m=2).copy()
        if k == 'h': edge_shade(im, 'n', 0.35); edge_shade(im, 's', -0.45)
        elif k == 'v': edge_shade(im, 'w', 0.35); edge_shade(im, 'e', -0.45)
        else: edge_shade(im, 'n', 0.3); edge_shade(im, 'w', 0.2); edge_shade(im, 's', -0.4); edge_shade(im, 'e', -0.3)
        return 'stone', (k, x % 2, z % 2), im
    if is_road(x, z):
        im = crop(dirt_t, x, z, m=2).copy()
        sides = tuple(s for s, (dx, dz) in (('n', (0, -1)), ('s', (0, 1)), ('w', (-1, 0)), ('e', (1, 0))) if not is_road(x + dx, z + dz))
        gim = crop(grass_t, x, z, m=2)
        px, gp = im.load(), gim.load()
        for yy in range(16):
            for xx in range(16):
                dist = min([yy if s == 'n' else 15 - yy if s == 's' else xx if s == 'w' else 15 - xx for s in sides] + [9])
                if dist < 3 or (dist < 5 and h2(x * 16 + xx, z * 16 + yy, 7) < 0.45):
                    px[xx, yy] = gp[xx, yy]
        return 'path', ('road', x % 2, z % 2, sides), im
    return 'grass', ('grass', x % 4, z % 4), crop(grass_t, x, z)

cells = {}       # key -> (type id, group, image)
world = bytearray(W * H)
for z in range(H):
    for x in range(W):
        grp, key, im = cell_image(x, z)
        if key not in cells: cells[key] = (len(cells), grp, im)
        world[z * W + x] = cells[key][0]
cells[('void',)] = (63, 'void', Image.new('RGB', (16, 16)))
assert len(cells) <= 64, f'{len(cells)} ground cell types: more than 63'
coll = bytes(grid)

# palettes per group: grass -> BG palette 0, path -> 5, stone -> 6 (1-4 are the HUD's)
GROUP_PAL = {'grass': 0, 'path': 5, 'stone': 6, 'void': 0}
bg_pals = {}
for grp, pal in (('grass', 0), ('path', 5), ('stone', 6)):
    ims = [im.convert('RGBA') for (_, gr, im) in cells.values() if gr == grp]
    bg_pals[pal] = quantize(ims, 15)
bg_tiles = bytearray(64 * 4 * 32)        # Mode 1: 4bpp, type * 4 + (tx + 2 ty)
m7_chars = bytearray(256 * 64)          # Mode 7: 8bpp, the same tile numbers, pixel = palette * 16 + index
type_pal = [0] * 64
prev_cells = {}
for key, (t, grp, im) in cells.items():
    pal = GROUP_PAL[grp]; type_pal[t] = pal
    if grp == 'void':
        idx = Image.new('P', (16, 16), 0)
    else:
        idx = index_img(im.convert('RGBA'), bg_pals[pal][1])
    prev_cells[t] = (idx, pal)
    rows = tiles_of(idx)
    for ty in range(2):
        for tx in range(2):
            n = t * 4 + tx + 2 * ty
            bg_tiles[n * 32:n * 32 + 32] = enc_tile(rows[ty][tx])
            for i, v in enumerate(rows[ty][tx]):
                m7_chars[n * 64 + i] = (pal * 16 + v) if v else 0
bg_cgram = [0] * 128
for pal, (cols, _) in bg_pals.items():
    for i, c in enumerate(cols): bg_cgram[pal * 16 + 1 + i] = bgr555(c)
def pal_rgb(pal, v):
    if v == 0: return (0, 0, 0)
    return bg_pals[pal][0][v - 1]

# ------------------------------------------------------------------ props: graves, crosses, rocks, bones, braziers, trees (upright sprites)
PROP_RGB = {}
def stone_slab(kind, seed):
    r = random.Random(seed)
    im = Image.new('RGBA', (16, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse((0, 26, 15, 31), fill=(8, 12, 8, 150))                      # its shadow on the grass
    dark, mid, lit, hi = (52, 54, 64, 255), (92, 94, 106, 255), (132, 134, 146, 255), (170, 172, 182, 255)
    if kind == 'round':
        d.rectangle((2, 9, 13, 29), fill=mid); d.ellipse((2, 3, 13, 15), fill=mid)
        d.rectangle((2, 9, 4, 29), fill=lit); d.chord((2, 3, 13, 15), 150, 270, fill=lit)
        d.rectangle((12, 9, 13, 29), fill=dark); d.arc((2, 3, 13, 15), 300, 30, fill=dark)
        d.line((5, 12, 10, 12), fill=dark); d.line((7, 10, 7, 17), fill=dark); d.line((5, 20, 10, 20), fill=dark); d.line((5, 23, 9, 23), fill=dark)
        d.point((4, 5), fill=hi)
    elif kind == 'square':
        d.polygon([(2, 8), (7, 3), (8, 3), (13, 8), (13, 29), (2, 29)], fill=mid)
        d.polygon([(2, 8), (7, 3), (7, 29), (2, 29)], fill=lit)
        d.line((13, 8, 13, 29), fill=dark); d.line((8, 3, 13, 8), fill=dark)
        d.rectangle((5, 13, 10, 14), fill=dark); d.line((5, 18, 10, 18), fill=dark); d.line((5, 21, 9, 21), fill=dark)
    else:  # a stone cross
        d.rectangle((6, 2, 9, 29), fill=mid); d.rectangle((1, 8, 14, 11), fill=mid)
        d.line((6, 2, 6, 29), fill=lit); d.line((1, 8, 14, 8), fill=lit); d.line((9, 2, 9, 29), fill=dark); d.line((1, 11, 14, 11), fill=dark)
        d.rectangle((4, 26, 11, 29), fill=dark); d.line((4, 26, 11, 26), fill=lit)
    for _ in range(6):                                                    # moss and lichen near the ground
        x, y = r.randrange(2, 14), r.randrange(20, 30)
        if im.getpixel((x, y))[3] == 255 and im.getpixel((x, y))[:3] != (8, 12, 8): im.putpixel((x, y), (54, 78, 40, 255))
    d.line((2, 30, 13, 30), fill=(40, 30, 22, 255))                       # the earth at its foot
    return im

def rock_img():
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse((0, 10, 15, 15), fill=(8, 12, 8, 150))
    d.ellipse((1, 3, 14, 14), fill=(70, 72, 82, 255)); d.ellipse((2, 3, 11, 11), fill=(104, 106, 118, 255)); d.ellipse((3, 4, 7, 7), fill=(140, 142, 154, 255))
    d.arc((1, 3, 14, 14), 0, 120, fill=(44, 46, 54, 255))
    return im

def bones_img():
    """the remains: the skeleton model fallen (the last picture of its death), at the game's size, in 32 x 16"""
    hdr = open(os.path.join(SKEL, 'spr_skel.h')).read()
    scale_ = 0.75 * 24 / int(re.search(r'SPR_PPM (\d+)', hdr).group(1))
    nums = [int(n) for n in re.findall(r'-?\d+', re.search(r'_cell\[5\]\[8\] = \{(.*?)\};', hdr, re.S).group(1))]
    cw = nums[(4 * 8 + 2) * 4]
    sh = Image.open(os.path.join(SKEL, 'spr_skel_4_2.png')).convert('RGBA')
    body = sh.crop((sh.width - cw, 0, sh.width, sh.height))
    body = body.crop(body.getbbox())
    k = min(32 / body.width, 15 / body.height, scale_ * 1.15)
    body = body.resize((max(1, round(body.width * k)), max(1, round(body.height * k))), Image.LANCZOS)
    im = Image.new('RGBA', (32, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse((1, 9, 30, 15), fill=(8, 12, 8, 150))
    im.alpha_composite(body, ((32 - body.width) // 2, 15 - body.height))
    return im

def brazier_img(f):
    im = Image.new('RGBA', (16, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse((1, 27, 14, 31), fill=(8, 12, 8, 150))
    iron, ironl = (40, 36, 40, 255), (84, 78, 80, 255)
    d.line((4, 29, 7, 18), fill=iron); d.line((11, 29, 8, 18), fill=iron); d.line((7, 18, 7, 29), fill=iron)
    d.polygon([(2, 14), (13, 14), (11, 19), (4, 19)], fill=iron); d.line((2, 14, 13, 14), fill=ironl)
    flames = [[(7, 1), (4, 8), (5, 13), (10, 13), (11, 7), (9, 4)], [(8, 0), (11, 7), (10, 13), (5, 13), (4, 8), (6, 5)]][f]
    d.polygon(flames, fill=(236, 110, 30, 255))
    inner = [(7, 5), (6, 9), (6, 13), (9, 13), (9, 9)] if f == 0 else [(8, 4), (9, 9), (9, 13), (6, 13), (6, 9)]
    d.polygon(inner, fill=(255, 210, 90, 255)); d.point((7, 12), fill=(255, 250, 200, 255))
    return im

def tree_img(name, w):
    sil = Image.open(os.path.join(ASSETS, f'{name}.png')).convert('RGBA')
    h = 60
    sc = min(w / sil.width, h / sil.height)
    s2 = sil.resize((max(1, round(sil.width * sc)), round(sil.height * sc)), Image.LANCZOS)
    im = Image.new('RGBA', (32, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse((4, 57, 27, 63), fill=(8, 12, 8, 150))
    ox = (32 - s2.width) // 2; oy = 62 - s2.height
    a = s2.split()[3].load()
    px = im.load()
    for y in range(s2.height):
        runs, xx = [], 0
        while xx < s2.width:                  # light from the left on each branch
            if a[xx, y] > 110:
                x0 = xx
                while xx < s2.width and a[xx, y] > 110: xx += 1
                runs.append((x0, xx - 1))
            xx += 1
        for x0, x1 in runs:
            for xx in range(x0, x1 + 1):
                t = (xx - x0) / max(1, x1 - x0)
                c = (92, 74, 58) if t < 0.3 and x1 > x0 else (58, 44, 36) if t < 0.7 else (30, 24, 22)
                if x1 == x0: c = (64, 50, 40)
                px[ox + xx, oy + y] = c + (255,)
    return im

graves = [stone_slab('round', 1), stone_slab('square', 2), stone_slab('cross', 3)]
braz = [brazier_img(0), brazier_img(1)]
trees = [tree_img('tl_tree0a', 30), tree_img('tl_tree2a', 26)]
rock, bones = rock_img(), bones_img()
prop_cols, prop_near = quantize(graves + braz * 4 + trees + [rock] + [bones] * 5, 15)   # (the bone colours weighted: they were turning grey)
obj_props = bytearray(256 * 32)         # OBJ name table 2 (VRAM $7000)
def put16(img, tile):                   # a 16x16 at tile (n, n+1, n+16, n+17)
    t = tiles_of(index_img(img, prop_near))
    for ty in range(2):
        for tx in range(2):
            n = tile + tx + ty * 16; obj_props[n * 32:n * 32 + 32] = enc_tile(t[ty][tx])
def put32(img, tile):
    t = tiles_of(index_img(img, prop_near))
    for ty in range(4):
        for tx in range(4):
            n = tile + tx + ty * 16; obj_props[n * 32:n * 32 + 32] = enc_tile(t[ty][tx])
small_slot = lambda k: (k // 4) * 32 + 8 + (k % 4) * 2 if k < 16 else 0x80 + ((k - 16) // 8) * 32 + ((k - 16) % 8) * 2
ATTR = 0x2D00                            # name table 2, palette 6, priority 2
PROPS = []                               # per type: parts (dx, dy, large, tile)
def prop(parts): PROPS.append(parts); return len(PROPS) - 1
k = 0
P_GRAVE = []
for im in graves:
    put16(im.crop((0, 0, 16, 16)), small_slot(k)); put16(im.crop((0, 16, 16, 32)), small_slot(k + 1))
    P_GRAVE.append(prop([(-8, -30, 0, small_slot(k)), (-8, -14, 0, small_slot(k + 1))])); k += 2
P_BRAZ = []
for im in braz:
    put16(im.crop((0, 0, 16, 16)), small_slot(k)); put16(im.crop((0, 16, 16, 32)), small_slot(k + 1))
    P_BRAZ.append(prop([(-8, -30, 0, small_slot(k)), (-8, -14, 0, small_slot(k + 1))])); k += 2
put16(rock, small_slot(k)); P_ROCK = prop([(-8, -14, 0, small_slot(k))]); k += 1
put16(bones.crop((0, 0, 16, 16)), small_slot(k)); put16(bones.crop((16, 0, 32, 16)), small_slot(k + 1))
P_BONES = prop([(-16, -12, 0, small_slot(k)), (0, -12, 0, small_slot(k + 1))]); k += 2
P_TREE = []
for i, im in enumerate(trees):
    put32(im.crop((0, 0, 32, 32)), i * 4); put32(im.crop((0, 32, 32, 64)), 0x40 + i * 4)
    P_TREE.append(prop([(-16, -62, 1, i * 4), (-16, -30, 1, 0x40 + i * 4)]))
BRAZIER_TYPE = P_BRAZ[0]

cell_of = lambda wx, wz: (int(math.floor(wx + 36)), int(math.floor(wz + 36)))
brazier_cells = {cell_of(x, z) for x, z in lights}
props = []                               # (x px, y px, type): the contact point on the ground
for z in range(H):
    for x in range(W):
        v = g(x, z); r = h2(x, z)
        if v == 1:
            if (x, z) in brazier_cells: t = BRAZIER_TYPE
            else: t = [P_GRAVE[0], P_GRAVE[0], P_GRAVE[1], P_GRAVE[1], P_GRAVE[2], P_GRAVE[2], P_ROCK, P_BONES][int(r * 8)]
            props.append((x * 16 + 8, z * 16 + 13, t))
        elif v == 2 and wall_kind(x, z) is None:
            props.append((x * 16 + 8, z * 16 + 13, P_TREE[int(r * 2)]))

# ------------------------------------------------------------------ the camera: flat, and Mode 7 (a slight tilt, the N64's yaw)
YAW = 0.62                               # main.c CAM_YAW
CY, SY = math.cos(YAW), math.sin(YAW)
M7_PY = 112                              # the hero's feet on screen
M7_YH = -280                             # the (virtual) horizon line: far above the screen, so the tilt is slight
M7_SPLIT = 160                           # lines 0..159 the ground; then the HUD in Mode 1
def k_of(y): return (M7_PY - M7_YH) / (y - M7_YH)
def d_of(y): return (M7_PY - M7_YH) * (1 - k_of(y))      # a flat plane in perspective: depth grows with the scale
RELY_MIN, RELY_MAX = math.ceil(d_of(0)), math.floor(d_of(223))
ly2line = []
for rely in range(RELY_MIN, RELY_MAX + 1):
    ly2line.append(max(0, min(223, round(M7_YH + (M7_PY - M7_YH) / (1 - rely / (M7_PY - M7_YH))))))
ik7 = [min(255, round(128 / k_of(y))) for y in range(224)]
def s16(v): return round(v * 256) & 0xFFFF
hdma_mat = {'A': [], 'B': [], 'C': [], 'D': []}
for y in range(M7_SPLIT):
    v = y - M7_PY; k = k_of(y); dv = d_of(y) / v if v else k
    hdma_mat['A'].append(s16(CY * k)); hdma_mat['B'].append(s16(SY * dv)); hdma_mat['C'].append(s16(-SY * k)); hdma_mat['D'].append(s16(CY * dv))
def hdma_words(vals):                   # repeat mode: $80|n, then n words; ends with one line and a 0
    out = []
    i = 0
    while i < len(vals):
        n = min(127, len(vals) - i)
        out.append(0x80 | n)
        for v in vals[i:i + n]: out += [v & 0xFF, v >> 8]
        i += n
    out += [1, 0, 1, 0]
    return out
fog = []
for i, b in enumerate(range(7, 15)): fog += [6, b]
fog += [1, 15, 0]
def rot(x, y): return (CY * x - SY * y, SY * x + CY * y)   # world -> camera (lx right, ly down the screen)

# ------------------------------------------------------------------ previews
def preview(mode7):
    full = Image.new('RGB', (W * 16, H * 16))
    for z in range(H):
        for x in range(W):
            idx, pal = prev_cells[world[z * W + x]]
            cim = Image.new('RGB', (16, 16)); cim.putdata([pal_rgb(pal, v) for v in idx.get_flattened_data()])
            full.paste(cim, (x * 16, z * 16))
    for (x, y, t) in sorted(props, key=lambda p: p[1]):
        for dx, dy, large, tile in PROPS[t]:
            sz = 32 if large else 16
            part = Image.new('RGBA', (sz, sz))
            for ty in range(sz // 8):
                for tx in range(sz // 8):
                    n = tile + tx + ty * 16
                    data = obj_props[n * 32:n * 32 + 32]
                    for yy in range(8):
                        for xx in range(8):
                            bit = 0x80 >> xx
                            v = (1 if data[yy * 2] & bit else 0) | (2 if data[yy * 2 + 1] & bit else 0) | (4 if data[16 + yy * 2] & bit else 0) | (8 if data[17 + yy * 2] & bit else 0)
                            if v: part.putpixel((tx * 8 + xx, ty * 8 + yy), prop_cols[v - 1] + (255,))
            full.paste(part, (x + dx, y + dy), part)
    full.save(os.path.join(OUT, 'world_preview.png'))
preview(False)

# ------------------------------------------------------------------ numbers from the N64 game (items.c, items_data.h, main.c)
SP_TOTAL = [0, 10, 21, 33, 46, 60, 76, 93, 112, 133, 156, 181, 209, 240, 274, 311]
def mon_stats(level, archer, champ):
    sp = SP_TOTAL[level]
    hp, st, df = 10 + int(sp * 0.55), 10 + int(sp * 0.25), 10 + int(sp * 0.20)
    if champ: hp *= 3; st = st * 13 // 10
    if archer: hp = hp * 7 // 10; st = st * 8 // 10
    return hp, st, df
mon_tab = []
for archer in range(2):
    for champ in range(2):
        for lv in range(8):
            mon_tab += list(mon_stats(lv, archer, champ))
xp_next = [0] + [int(100.0 * L ** 1.5 + 0.5) for L in range(1, 60)]

DIRV = [(0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1)]
def speeds(s, yaw):
    vx, vy = [], []
    for dx, dy in DIRV:
        l = math.hypot(dx, dy); lx, ly = dx / l * s, dy / l * s
        c, sn = math.cos(yaw), math.sin(yaw)
        vx.append(round(c * lx + sn * ly)); vy.append(round(-sn * lx + c * ly))    # camera -> world
    return vx, vy
def w16(vals): return ', '.join('$%04X' % (v & 0xFFFF) for v in vals)
def b8(vals): return ', '.join(str(v & 0xFF) for v in vals)
px = lambda wx, wz: (round((wx + 36) * 16), round((wz + 36) * 16))
sp_px = [px(a, b) for a, b in spawns]
st = px(*start)

lines = ['; generated by tools/build_assets.py - do not edit', f'START_X = {st[0] - 24}', f'START_Y = {st[1]}',
         f'FONT_BASE = {FONT_BASE}', f'FONT2_BASE = {FONT2_BASE}', f'VIAL_BASE = {VIAL_BASE}', f'BELT_BASE = {BELT_BASE}', f'VIAL_TOP = {VIAL_TOP}', f'VIAL_BOT = {VIAL_BOT}',
         f'HUD_TILES_BYTES = {len(hud_bin)}', f'SPAWN_COUNT = {len(sp_px)}', f'FRAMES = {FRAMES}',
         f'BRAZIER_TYPE = {BRAZIER_TYPE}', f'M7_PY = {M7_PY}', f'M7_SPLIT = {M7_SPLIT}', f'RELY_MIN = {RELY_MIN}', f'RELY_MAX = {RELY_MAX}',
         f'ROT_C = {round(CY * 256)}', f'ROT_S = {round(SY * 256)}']
cur = {'bank': 1, 'pc': 0x8000}
lines.append('.bank 1')
def place(frames, label):
    ptrs = []
    for i, fr in enumerate(frames):
        if cur['pc'] + len(fr) > 0x10000:
            cur['bank'] += 1; cur['pc'] = 0x8000; lines.append(f'.bank {cur["bank"]}')
        fn = f'{label}_{i:03d}.bin'
        open(os.path.join(OUT, fn), 'wb').write(fr)
        lines.append(f'{label}_f{i}: .incbin "../out/{fn}"'); ptrs.append(f'{label}_f{i}')
        cur['pc'] += len(fr)
    return ptrs
for f in os.listdir(OUT):
    if re.match(r'(hero|ghoul|skel)_\d+\.bin$', f): os.remove(os.path.join(OUT, f))
hp_ = place(hero, 'hero'); gp_ = place(ghoul, 'ghoul'); kp_ = place(skel, 'skel')
def blob(name, data):
    if cur['pc'] + len(data) > 0x10000:
        cur['bank'] += 1; cur['pc'] = 0x8000; lines.append(f'.bank {cur["bank"]}')
    open(os.path.join(OUT, name + '.bin'), 'wb').write(data)
    lines.append(f'{name}: .incbin "../out/{name}.bin"'); cur['pc'] += len(data)
cur['bank'] += 1; cur['pc'] = 0x8000; lines.append(f'.bank {cur["bank"]}')
for name, data in (('bg_tiles', bg_tiles), ('obj_static', bytes(obj_static)), ('obj_props', bytes(obj_props)), ('hud_tiles', hud_bin), ('world', bytes(world)), ('coll', coll)):
    blob(name, data)
cur['bank'] += 1; cur['pc'] = 0x8000; lines.append(f'.bank {cur["bank"]}')
blob('m7_chars', bytes(m7_chars))
# the props, sorted by depth for each camera; with a bucket index every 16 px of depth
for mode7 in (False, True):
    rp = []
    for (x, y, t) in props:
        lx, ly = rot(x, y) if mode7 else (x, y)
        rp.append((round(lx), round(ly), t))
    # 2D buckets: 16 px of depth x 128 px across; within a bucket by depth
    ly0 = min(p[1] for p in rp); lx0 = min(p[0] for p in rp)
    nr = (max(p[1] for p in rp) - ly0) // 16 + 1
    nc = (max(p[0] for p in rp) - lx0) // 128 + 1
    rp.sort(key=lambda p: (((p[1] - ly0) // 16) * nc + (p[0] - lx0) // 128, p[1]))
    starts = []
    j = 0
    for b in range(nr * nc + 1):
        while j < len(rp) and ((rp[j][1] - ly0) // 16) * nc + (rp[j][0] - lx0) // 128 < b: j += 1
        starts.append(j)
    tag = 'm7' if mode7 else 'flat'
    T = tag.upper()
    lines += [f'PROPS_{T}_N = {len(rp)}', f'PROPS_{T}_LY0 = {ly0}', f'PROPS_{T}_LX0 = {lx0}', f'PROPS_{T}_NR = {nr}', f'PROPS_{T}_NC = {nc}']
    data = bytearray()
    for lx, ly, t in rp: data += (lx & 0xFFFF).to_bytes(2, 'little') + (ly & 0xFFFF).to_bytes(2, 'little') + bytes([t, 0])
    blob(f'props_{tag}', bytes(data))
    sdat = bytearray()
    for st_ in starts: sdat += (st_ * 6).to_bytes(2, 'little')
    blob(f'pbucket_{tag}', bytes(sdat))
assert cur['pc'] <= 0x10000
lines.append(f'ROM_BANKS = {cur["bank"] + 1}')
lines += ['.bank 0', '.org $E000']
for nm, ptrs in (('hero_ptrs', hp_), ('ghoul_ptrs', gp_), ('skel_ptrs', kp_)):
    lines.append(f'{nm}:')
    for k2 in range(0, len(ptrs), 8): lines.append(' .long ' + ', '.join(ptrs[k2:k2 + 8]))
pals = [pal16(hero_cols), pal16(ghoul_cols), pal16(skel_cols), pal16(ghoul_cols, blue), pal16(skel_cols, blue), pal16(hero_cols, red),
        [0] + [bgr555(c) for c in prop_cols], [0] + [bgr555(c) for c in small_cols]]
lines.append('obj_pals:')
for p in pals: lines.append(' .word ' + w16(p))
lines.append('hud_pals:')
for k2 in range(0, 64, 16): lines.append(' .word ' + w16(hud_pals[k2:k2 + 16]))
lines.append('bg_cgram:')
for k2 in range(0, 128, 16): lines.append(' .word ' + w16(bg_cgram[k2:k2 + 16]))
lines.append('type_pal: .word ' + w16([p << 10 for p in type_pal]))
for mode7 in (True, False):
    lines.append('.if MODE7' if mode7 else '.else')
    y_ = YAW if mode7 else 0.0
    for nm, sp in (('spd_h', 15), ('spd_g', 6), ('spd_w', 3), ('spd_r', 5), ('spd_k', 64), ('spd_c', 112)):
        vx, vy = speeds(sp, y_)
        lines.append(f'{nm}x: .word {w16(vx)}'); lines.append(f'{nm}y: .word {w16(vy)}')
lines.append('.endif')
lines.append('dirx: .word ' + w16([d[0] for d in DIRV]))
lines.append('diry: .word ' + w16([d[1] for d in DIRV]))
lines.append('spawn_tab: .word ' + ', '.join(f'{x}, {y}' for x, y in sp_px))
lines.append('mon_tab: .word ' + w16(mon_tab))
lines.append('xp_next: .word ' + w16(xp_next))
lines.append('gold_tab: .word ' + w16([int(9 * (1 + L * 0.06)) * k2 for k2 in (1, 3) for L in range(8)]))
lines.append('charmap: .byte ' + ', '.join(str(CHARMAP.get(chr(c), 0)) for c in range(32, 96)))
lines.append('prop_ofs: .word ' + ', '.join(f'prop_p{t}' for t in range(len(PROPS))))
for t, parts in enumerate(PROPS):
    rec = [f'prop_p{t}: .byte {len(parts)}']
    for dx, dy, large, tile in parts: rec.append(f' .byte {dx & 0xFF}, {dy & 0xFF}, {2 if large else 0}, 0\n .word ${ATTR | tile:04X}')
    lines += rec
lines.append('.if MODE7')
lines.append('ly2line: .byte ' + b8(ly2line))
lines.append('ik7: .byte ' + b8(ik7))
for r in 'ABCD':
    lines.append(f'hdma_{r}: .byte ' + b8(hdma_words(hdma_mat[r])))
lines.append('hdma_mode: .byte 127, 7, 33, 7, 1, 1, 0')
lines.append('hdma_tm: .byte 127, $11, 33, $11, 1, $02, 0')
lines.append('hdma_fog: .byte ' + b8(fog))
lines.append('.endif')
open(os.path.join(ROOT, 'src', 'data.inc'), 'w').write('\n'.join(lines) + '\n')
print('banks', cur['bank'] + 1, 'cell types', len(cells), 'props', len(props), 'prop types', len(PROPS), 'rely', RELY_MIN, RELY_MAX)
