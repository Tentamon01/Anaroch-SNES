"""The studio's splash, the N64 version's scene (src/splash.c) drawn again at the SNES's size, 20 pictures a second.

Reads:  ../Anaroch_N64_Sprite/assets/sg_<0,1,3>.png, title_tent / title_sucker / title_tenta / tg_spot.png, src/splash_guy.h
Writes: src/splash.inc, out/splash/*.bin, out/splash/sheet.png (every 8th picture, to look at)

The floor and its lights are one still background (BG2); the studio's mark is sprites, uncovered by a window; the man,
the tentacle and the blood are a picture of tiles for every step (BG1). The fades and the turn to red are done with
the colours alone, so the tiles hold the scene as it is lit before the blow.
"""
import os, re, math, random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
N64 = os.path.join(os.path.dirname(ROOT), 'Anaroch_N64_Sprite')
A = os.path.join(N64, 'assets')
OUT = os.path.join(ROOT, 'out', 'splash')
os.makedirs(OUT, exist_ok=True)
S = 0.4                                   # 640 x 480 -> 256 x 192
OY = 8                                    # (the picture shows 208 lines: 8 spare above and below)
W, H = 256, 208
FPS = 20
src = open(os.path.join(N64, 'src', 'splash.c')).read()
def num(name):
    m = re.search(r'#define %s\s+(.+?)(?://|$)' % name, src, re.M)
    return eval(re.sub(r'(\d)f\b', r'\1', m.group(1)).replace('T_STAB', str(globals().get('T_STAB', 0))))
GROUND = num('GROUND'); WALK_X0 = num('WALK_X0'); WALK_V = num('WALK_V'); WALK_RATE = num('WALK_RATE')
BELLY_Y = num('BELLY_Y'); BELLY_DX = num('BELLY_DX')
T_CREEP = num('T_CREEP'); T_REAR = num('T_REAR'); T_STAB = num('T_STAB'); T_LIFT = num('T_LIFT'); T_PULL = num('T_PULL')
PULL_ACC = num('PULL_ACC'); T_FIGHT = num('T_FIGHT'); T_GLEAM = num('T_GLEAM'); T_OUT = num('T_OUT'); T_END = num('T_END')
guy_h = open(os.path.join(N64, 'src', 'splash_guy.h')).read()
SG_W = int(re.search(r'SG_W (\d+)', guy_h).group(1)); SG_AY = int(re.search(r'SG_ANCHOR_Y (\d+)', guy_h).group(1))
anim = [(int(a), float(b), int(c), int(d), int(e), int(f), int(g)) for a, b, c, d, e, f, g in
        re.findall(r'\{(\d+), ([\d.]+)f, (\d+), (\d+), (\d+), (\d+), (\d+)\}', guy_h)]
guy = {a: Image.open(os.path.join(A, f'sg_{a}.png')).convert('RGBA') for a in (0, 1, 3)}
tent = Image.open(os.path.join(A, 'title_tent.png')).convert('RGBA')
sucker = Image.open(os.path.join(A, 'title_sucker.png')).convert('RGBA')
logo = Image.open(os.path.join(A, 'title_tenta.png')).convert('RGBA')
spot_img = Image.open(os.path.join(A, 'tg_spot.png')).convert('L')
clamp = lambda v, lo=0.0, hi=1.0: lo if v < lo else hi if v > hi else v

# ------------------------------------------------------------------ where everything is (splash.c)
def guy_x(T):
    if T < T_STAB: return WALK_X0 - WALK_V * T
    x = WALK_X0 - WALK_V * T_STAB
    if T > T_PULL:
        d = T - T_PULL; x -= 115 * d
        if d > T_FIGHT: x -= 0.5 * PULL_ACC * 1.6 * (d - T_FIGHT) ** 2
    return x
def guy_lift(T):
    if T < T_LIFT: return 0
    k = clamp((T - T_LIFT) / 0.6); k = k * k * (3 - 2 * k)
    return 34 * k + (math.sin(T * 31) * 1.5 if T < T_PULL else math.sin(T * 23) * 2.5)
def guy_frame(T):
    if T < T_STAB: return 0, int(T * WALK_RATE / anim[0][1] * anim[0][0]) % anim[0][0]
    if T < T_PULL: return 1, int(clamp((T - T_STAB) / anim[1][1] * anim[1][0], 0, anim[1][0] - 1))
    return 3, int(math.fmod((T - T_PULL) / anim[3][1], 1.0) * anim[3][0]) % anim[3][0]
def wound(T): return guy_x(T) + BELLY_DX, GROUND - BELLY_Y - guy_lift(T)
lit_at = lambda x: 0.22 + 0.78 * math.exp(-(x - 470) ** 2 / (2 * 150.0 ** 2))

# the blood (splash_update at 60 steps a second)
rng = random.Random(12345)
rnd = rng.random
drops = []; spots = []
def bleed(x, y, n, spread, push):
    for _ in range(n):
        if len(drops) < 90: drops.append([x + (rnd() - 0.5) * 6, y + (rnd() - 0.5) * 6, (rnd() - 0.5) * spread + push, -rnd() * spread * 0.8])
def step(was, T):
    dt = T - was
    if was < T_STAB <= T:
        x, y = wound(T); bleed(x, y, 26, 260, -40); bleed(x + 30, y, 18, 200, 120)
    if T_STAB < T < T_PULL + T_FIGHT + 0.6 and rnd() < (0.55 if T < T_PULL else 0.9):
        x, y = wound(T); bleed(x + 4, y + 6, 1, 40, 60 if T > T_PULL else 0)
    for d in drops[:]:
        d[3] += 900 * dt; d[0] += d[2] * dt; d[1] += d[3] * dt
        if d[1] >= GROUND + 4:
            drops.remove(d)
            best = None
            for s_ in spots:
                if abs(s_[0] - d[0]) < s_[1] * 0.6: best = s_
            if best:
                if best[1] < 70: best[1] += 1.6
            elif len(spots) < 48: spots.append([d[0], 5 + rnd() * 4])

# ------------------------------------------------------------------ drawing (on the 256 x 208 picture)
P = lambda x, y: (x * S, y * S + OY)
def paste(layer, im, x, y):
    """alpha-composites im with its corner at picture pixel (x, y), clipped"""
    x, y = int(round(x)), int(round(y))
    x0, y0 = max(0, -x), max(0, -y); x1, y1 = min(im.width, W - x), min(im.height, H - y)
    if x1 > x0 and y1 > y0: layer.alpha_composite(im.crop((x0, y0, x1, y1)), (x + x0, y + y0))
def glow(layer, x, y, sx, sy, col):
    wd, ht = max(1, int(round(32 * sx * S))), max(1, int(round(32 * sy * S)))
    if wd > 700 or ht > 700 or col[3] <= 0: return
    al = spot_img.resize((wd, ht), Image.BILINEAR).point([v * int(col[3]) // 255 for v in range(256)])
    im = Image.new('RGBA', (wd, ht), (int(col[0]), int(col[1]), int(col[2]), 255)); im.putalpha(al)
    paste(layer, im, *P(x - 16 * sx, y - 16 * sy))
cache = {}
def disc(layer, pic, x, y, r, k):
    d = max(1, int(round(2 * r * S))); v = int(clamp(k) * 16)
    key = (id(pic), d, v)
    im = cache.get(key)
    if im is None:
        im = pic.resize((d, d), Image.LANCZOS)
        rr, g, b, al = im.split()
        lut = [i * v // 16 for i in range(256)]
        im = cache[key] = Image.merge('RGBA', (rr.point(lut), g.point(lut), b.point(lut), al))
    paste(layer, im, x * S - d / 2, y * S + OY - d / 2)
def tentacle(layer, T, tx, ty, arch, amp, s0, s1):
    bx, by = -90, GROUND + 14
    dx, dy = tx - bx, ty - by; ln = math.hypot(dx, dy) + 1e-3; nx, ny = -dy / ln, dx / ln
    for i in range(int(s0 * 120), int(s1 * 120) + 1):
        s = i / 120
        w = amp * math.sin(3.14159 * s) * math.sin(6.2832 * (1.3 * s - 1.4 * T)) * (1 - 0.4 * s)
        x = bx + dx * s + nx * w; y = by + dy * s + ny * w - arch * math.sin(3.14159 * s)
        r = 30 * (1 - 0.8 * s) + 3.0
        disc(layer, tent, x, y, r, 0.35 + lit_at(x) * 0.9)
        if i % 7 == 3 and 0.12 < s < 0.92: disc(layer, sucker, x + 0.2 * r, y + 0.55 * r, r * 0.38, 0.3 + lit_at(x) * 0.8)

def floor_picture(red):
    im = Image.new('RGBA', (W, H), (2, 2, 4, 255))
    col = (34, 8, 8) if red else (14, 16, 22)
    for k in range(12):
        band = Image.new('RGBA', (W, max(1, int(round(12 * S)))), col + (max(0, 110 - k * 8),))
        paste(im, band, 0, (GROUND + k * 12) * S + OY)
    glow(im, 470, GROUND - 120, 26, 18, (190, 30, 24, 100) if red else (120, 140, 175, 60))
    glow(im, 470, GROUND + 4, 30, 4.5, (200, 40, 30, 110) if red else (150, 165, 200, 110))
    glow(im, -20, GROUND - 20, 18, 10, (60, 10, 40, 90))
    return im.convert('RGB')

def actors(T):
    """the man, the tentacle, the blood: a transparent picture, as lit before the blow"""
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for sx_, r in spots: glow(L, sx_, GROUND + 5, r / 16.0, r / 70.0 + 0.25, (110, 4, 6, 230))
    if T >= T_PULL:                                    # the red glow at the edge the mark is uncovered from
        lx = 320 - logo.width / 2.0; ly = GROUND - 196; rx = guy_x(T) + 70
        if lx < rx < lx + logo.width: glow(L, rx - 4, ly + 120, 3, 9, (220, 40, 30, int(120 * clamp((lx + logo.width - rx) / 60))))
    gx = guy_x(T); lift = guy_lift(T); wx, wy = wound(T); through = T >= T_STAB
    if T < T_CREEP: tx, ty, arch, amp = -60, GROUND + 4, 0, 4
    elif T < T_REAR: k = (T - T_CREEP) / (T_REAR - T_CREEP); tx, ty, arch, amp = -60 + k * 170, GROUND + 2 - 3 * math.sin(T * 9), 4, 10
    elif not through:
        k = (T - T_REAR) / (T_STAB - T_REAR); e = k * k * k
        tx = 110 + (wx + 46 - 110) * e - 30 * (1 - k) * math.sin(k * 3.14159); ty = GROUND - 120 * math.sin(k * 3.14159) + (wy - GROUND) * e
        arch, amp = 50 * (1 - e) + 6, 6
    else: tx, ty, arch, amp = wx + 46, wy - 4, 6, 3
    s_in = clamp((wx + 90) / (tx + 90)) if through else 1.0
    glow(L, gx, GROUND + 2, 4.2 * (1 - lift / 80), 0.9, (0, 0, 0, 140))
    if T >= T_CREEP: tentacle(L, T, tx, ty, arch, amp, s_in if through else 0, 1)
    if gx > -140:
        a, f = guy_frame(T); n, secs, cols, cw, ch, x0, y0 = anim[a]
        cell = guy[a].crop(((f % cols) * cw, (f // cols) * ch, (f % cols) * cw + cw, (f // cols) * ch + ch))
        v = clamp(lit_at(gx)); lut = [int(i * v) for i in range(256)]
        r, g, b, al = cell.split()
        cell = Image.merge('RGBA', (r.point(lut), g.point(lut), b.point(lut), al))
        sm = cell.resize((max(1, round(cw * S)), max(1, round(ch * S))), Image.LANCZOS)
        paste(L, sm, (gx - SG_W / 2.0 + x0) * S, (GROUND - SG_AY + y0 - lift) * S + OY)
    if T >= T_CREEP and through: tentacle(L, T, tx, ty, arch, amp, 0, s_in)
    if through: glow(L, wx, wy, 0.6, 0.6, (150, 0, 0, 220))
    d = ImageDraw.Draw(L)
    for x, y, _, _ in drops:
        px, py = P(x, y); d.rectangle((int(px), int(py), int(px), int(py) + 1), fill=(150, 6, 8, 255))
    return L

# ------------------------------------------------------------------ colours
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def dith(c, x, y, amount=7):
    d = (BAYER[y & 3][x & 3] - 7.5) / 16 * amount
    return tuple(int(clamp(v + d, 0, 255)) for v in c)
def palette_of(pixels, n=15):
    if not pixels: return [(0, 0, 0)] * n
    if len(pixels) > 30000: pixels = random.Random(1).sample(pixels, 30000)
    q = Image.new('RGB', (len(pixels), 1)); q.putdata(pixels)
    pal = q.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[:n * 3]
    cols = [tuple(pal[i * 3:i * 3 + 3]) for i in range(len(pal) // 3)]
    return cols + [(0, 0, 0)] * (n - len(cols))
def nearest(pal, c):
    best = 0; be = 1 << 30
    for i, p in enumerate(pal):
        e = (c[0] - p[0]) ** 2 * 3 + (c[1] - p[1]) ** 2 * 4 + (c[2] - p[2]) ** 2 * 2
        if e < be: be = e; best = i
    return best, be
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

# ------------------------------------------------------------------ the story
N = int(T_END * FPS) + 1
PAL_BYTES = 224                           # a picture's colours: BG 0..95, then the mark's 16
frames = []; T_ = 0.0
for k in range(N):
    T = k / FPS
    while T_ + 1e-6 < T:
        nxt = min(T, T_ + 1 / 60); step(T_, nxt); T_ = nxt
    frames.append(actors(T))
print(f'{N} pictures drawn')

# the floor: two palettes (each tile takes the better one), each colour with its look before and after the blow
cold, hot = floor_picture(False), floor_picture(True)
cp, hp = cold.load(), hot.load()
dc = [[dith(cp[x, y], x, y, 8) for x in range(W)] for y in range(H)]
cells = [[dc[ty * 8 + y][tx * 8 + x] for y in range(8) for x in range(8)] for ty in range(H // 8) for tx in range(32)]
lum_ = [sum(sum(c) for c in t) / 64 for t in cells]
cut = sorted(lum_)[len(lum_) * 6 // 10]
fpals = [palette_of([c for t, l in zip(cells, lum_) if (l > cut) == bright for c in t]) for bright in (False, True)]
fmemo = [{}, {}]
def ffit(t, n):
    out = []; e = 0
    for c in t:
        v = fmemo[n].get(c)
        if v is None: v = fmemo[n][c] = nearest(fpals[n], c)
        out.append(v[0]); e += v[1]
    return out, e
fidx = [[0] * W for _ in range(H)]; fpl = []
for k_, t in enumerate(cells):
    a_, b_ = ffit(t, 0), ffit(t, 1); n_ = 0 if a_[1] <= b_[1] else 1; idx = (a_ if n_ == 0 else b_)[0]; fpl.append(n_)
    tx, ty = k_ % 32, k_ // 32
    for q, v in enumerate(idx): fidx[ty * 8 + q // 8][tx * 8 + q % 8] = v
sums = [[[0, 0, 0, 0] for _ in range(15)] for _ in range(2)]
for y in range(H):
    for x in range(W):
        s_ = sums[fpl[(y // 8) * 32 + x // 8]][fidx[y][x]]; h = hp[x, y]; s_[0] += h[0]; s_[1] += h[1]; s_[2] += h[2]; s_[3] += 1
freds = [[tuple(s_[j] // s_[3] for j in range(3)) if s_[3] else fpals[n][i] for i, s_ in enumerate(sums[n])] for n in range(2)]
ftiles = {bytes(32): 0}; fmap = []
for ty in range(32):
    for tx in range(32):
        if ty >= H // 8: fmap.append(0); continue
        t = enc4([fidx[ty * 8 + y][tx * 8 + x] + 1 for y in range(8) for x in range(8)])
        n = ftiles.get(t)
        if n is None: n = ftiles[t] = len(ftiles)
        fmap.append(n | ((4 + fpl[ty * 32 + tx]) << 10))
assert len(ftiles) <= 768, len(ftiles)

# the actors: tiles of each picture, with four palettes
tiles = []                                       # per picture: [(cell, pixels or None per place)]
for k, L in enumerate(frames):
    px = L.load(); lst = []
    for ty in range(H // 8):
        for tx in range(32):
            if not L.crop((tx * 8, ty * 8, tx * 8 + 8, ty * 8 + 8)).getchannel('A').getbbox(): continue
            t = []
            for y in range(ty * 8, ty * 8 + 8):
                for x in range(tx * 8, tx * 8 + 8):
                    r, g, b, a = px[x, y]
                    if a < 14 + BAYER[y & 3][x & 3] * 3: t.append(None); continue
                    f = a / 255; c = cp[x, y]
                    t.append(dith((r * f + c[0] * (1 - f), g * f + c[1] * (1 - f), b * f + c[2] * (1 - f)), x, y, 6))
            if any(p is not None for p in t): lst.append((ty * 32 + tx, t))
    tiles.append(lst)
alltiles = [t for lst in tiles for _, t in lst]
def mean(t):
    q = [p for p in t if p is not None]; return tuple(sum(c[j] for c in q) / len(q) for j in range(3))
means = [mean(t) for t in alltiles]
# four groups of tiles by their colour, a palette for each, then every tile to the palette that suits it
centres = [(20, 20, 26), (110, 80, 95), (90, 20, 20), (150, 140, 140)]
for _ in range(6):
    groups = [[] for _ in centres]
    for i, m in enumerate(means): groups[nearest(centres, m)[0]].append(i)
    centres = [tuple(sum(means[i][j] for i in g) / len(g) for j in range(3)) if g else centres[n] for n, g in enumerate(groups)]
apals = [palette_of([p for i in g for p in alltiles[i] if p is not None]) for g in groups]
memo = [{} for _ in apals]
def fit(t, n):
    e = 0; out = []
    for p in t:
        if p is None: out.append(0); continue
        v = memo[n].get(p)
        if v is None: v = memo[n][p] = nearest(apals[n], p)
        out.append(v[0] + 1); e += v[1]
    return out, e
frame_data = []; most = 0
for lst in tiles:
    cells = bytearray(); gfx = bytearray()
    for cell, t in lst:
        sample = [p if i % 3 == 0 else None for i, p in enumerate(t)]
        n = min(range(4), key=lambda n_: fit(sample, n_)[1])
        cells += (cell | (n << 10)).to_bytes(2, 'little'); gfx += enc4(fit(t, n)[0])
    most = max(most, len(lst)); frame_data.append((len(lst), bytes(cells + gfx)))
assert most <= 384, most
print(f'floor {len(ftiles)} tiles; actors: at most {most} tiles a picture, {sum(len(d) for _, d in frame_data) // 1024} KB in all')

# the mark: sprites, 32 x 32, six across and three down
lw, lh = round(logo.width * S), round(logo.height * S)
lx, ly = round((320 - logo.width / 2) * S), round((GROUND - 196) * S + OY)
small = logo.resize((lw, lh), Image.LANCZOS)
lp = Image.new('RGBA', (192, 96), (0, 0, 0, 0)); lp.paste(small, (0, 0))
lpix = []
for y in range(96):
    for x in range(192):
        r, g, b, a = lp.getpixel((x, y))
        if a < 48 or not (0 <= ly + y < H and 0 <= lx + x < W): lpix.append(None); continue
        f = a / 255; c = tuple(v * 0.6 + w_ * 0.4 for v, w_ in zip(hp[lx + x, ly + y], (120, 0, 0)))   # (it is seen over the red)
        lpix.append(dith((r * f + c[0] * (1 - f), g * f + c[1] * (1 - f), b * f + c[2] * (1 - f)), x, y, 5))
lpal = palette_of([p for p in lpix if p is not None])
lidx = [0 if p is None else nearest(lpal, p)[0] + 1 for p in lpix]
LOGO_TILE = 0xC0                           # video memory $0C00-$1FFF: no sprite may cross a page of 256 tiles
ltiles = bytearray(320 * 32); oam = bytearray(544)
for i in range(128): oam[i * 4 + 1] = 0xE0
n = 0
for row in range(3):
    for col in range(6):
        base = 64 + (n // 4) * 64 + (n % 4) * 4 if n < 16 else (n - 16) * 4      # tiles from LOGO_TILE
        for ty in range(4):
            for tx in range(4):
                t = enc4([lidx[(row * 32 + ty * 8 + y) * 192 + col * 32 + tx * 8 + x] for y in range(8) for x in range(8)])
                at = (base + ty * 16 + tx) * 32; ltiles[at:at + 32] = t
        sx_, sy_ = lx + col * 32, ly + row * 32 + 8 - 1        # (canvas row 0 is screen line 8)
        first = LOGO_TILE + base
        oam[n * 4:n * 4 + 4] = bytes([sx_ & 255, sy_ & 255, first & 255, 0x20 | ((first >> 8) & 1)])
        oam[512 + n // 4] |= (2 | ((sx_ >> 8) & 1)) << ((n % 4) * 2)
        n += 1

# per picture: the colours (floor, actors, the mark), where the window stands, the sounds
def bgr(c): return (int(c[0]) >> 3) | ((int(c[1]) >> 3) << 5) | ((int(c[2]) >> 3) << 10)
mix = lambda a, b, k: tuple(a[j] + (b[j] - a[j]) * k for j in range(3))
pals = bytearray(); meta = bytearray()
sounds = [(T_REAR, 'SFX_GROWL'), (T_STAB, 'SFX_GRAB'), (T_STAB + 0.15, 'SFX_SCREAM'), (T_PULL, 'SFX_THUD')]
for k in range(N):
    T = k / FPS
    fade = clamp(T / 0.6) * (1 - clamp((T - T_OUT) / (T_END - T_OUT)))
    rk = clamp((T - T_STAB) / 0.9)
    wash = rk * (0.18 + 0.22 * clamp((T - T_PULL) / 0.8))
    gl = math.sin((T - T_GLEAM) / 0.9 * 3.14159) if T_GLEAM < T < T_GLEAM + 0.9 else 0
    red_ = lambda c: mix(c, (120, 0, 0), wash)
    shade = lambda c: tuple(v * fade for v in c)
    bg = [0] * 128
    for p, pal in enumerate(apals):
        for i, c in enumerate(pal): bg[p * 16 + i + 1] = bgr(shade(red_((c[0], c[1] * (1 - 0.35 * rk), c[2] * (1 - 0.45 * rk)))))
    for n_ in range(2):
        for i in range(15): bg[64 + n_ * 16 + i + 1] = bgr(shade(red_(mix(fpals[n_][i], freds[n_][i], rk))))
    bg[0] = bgr(shade(red_(mix((2, 2, 4), (4, 1, 1), rk))))
    obj = [0] + [bgr(tuple(min(255, v * (225 + 30 * gl) / 255) * fade for v in c)) for c in lpal]
    pals += b''.join(v.to_bytes(2, 'little') for v in bg[:96] + obj)
    rx = 10000 if T < T_PULL else (guy_x(T) + 70) * S
    left = int(clamp(rx, 0, 256))                      # the mark shows from this column on
    ev = 0
    for at, name in sounds:
        if k == int(math.ceil(at * FPS - 1e-6)): ev = ['SFX_GROWL', 'SFX_GRAB', 'SFX_SCREAM', 'SFX_THUD'].index(name) + 1
    meta += bytes([left & 255, left >> 8, ev, 0])

# ------------------------------------------------------------------ the ROM banks
free = [10, 11, 12, 13, 14, 15, 34, 35, 36, 37, 38, 39, 48, 49, 50, 51, 52, 53, 54, 55, 57, 58, 59, 60, 61, 62, 63]
lines = ['; generated by tools/build_splash.py - do not edit', f'SPLASH_FRAMES = {N}', f'SPLASH_PAL_BYTES = {PAL_BYTES}', f'SPLASH_FLOOR_BYTES = {len(ftiles) * 32}']
banks = [[free.pop(0), bytearray()]]
def put(data):
    if len(banks[-1][1]) + len(data) > 0x8000: banks.append([free.pop(0), bytearray()])
    b, buf = banks[-1]; at = (b << 16) | (0x8000 + len(buf)); buf += data; return at
labels = {}
ordered = sorted(ftiles.items(), key=lambda q: q[1])
labels['splash_floor'] = put(b''.join(t for t, _ in ordered))
labels['splash_map'] = put(b''.join(v.to_bytes(2, 'little') for v in fmap))
labels['splash_logo'] = put(bytes(ltiles))
labels['splash_oam'] = put(bytes(oam))
pal_per_bank = 0x8000 // PAL_BYTES
labels['splash_pals'] = put(bytes(pals[:pal_per_bank * PAL_BYTES]))
if N > pal_per_bank:
    second = put(bytes(pals[pal_per_bank * PAL_BYTES:]))
else: second = labels['splash_pals']
labels['splash_meta'] = put(bytes(meta))
head = bytearray()
for count, data in frame_data:
    at = put(data) if data else 0x8000
    head += (at & 0xFFFF).to_bytes(2, 'little') + (at >> 16).to_bytes(2, 'little') + count.to_bytes(2, 'little') + b'\0\0'
labels['splash_head'] = put(bytes(head))
for b, buf in banks:
    open(os.path.join(OUT, f'bank{b}.bin'), 'wb').write(buf)
    lines += [f'.bank {b}', '.org $8000', f' .incbin "../out/splash/bank{b}.bin"']
lines += [f'{k} = ${v:06X}' for k, v in labels.items()]
lines += [f'splash_pals2 = ${second:06X}', f'SPLASH_PALS_PER_BANK = {pal_per_bank}']
open(os.path.join(ROOT, 'src', 'splash.inc'), 'w', newline='\n').write('\n'.join(lines) + '\n')

# a sheet to look at: every 8th picture as it would show (floor + actors + the mark)
sheet = Image.new('RGB', (W * 5 + 16, (H + 4) * ((N // 8) // 5 + 1)), (255, 0, 255))
for j, k in enumerate(range(0, N, 8)):
    pic = Image.new('RGB', (W, H))
    p = pals[k * PAL_BYTES:(k + 1) * PAL_BYTES]
    col = lambda i: tuple(((int.from_bytes(p[i * 2:i * 2 + 2], 'little') >> s_) & 31) << 3 for s_ in (0, 5, 10))
    left = meta[k * 4] | (meta[k * 4 + 1] << 8)
    for y in range(H):
        for x in range(W): pic.putpixel((x, y), col(64 + fpl[(y // 8) * 32 + x // 8] * 16 + fidx[y][x] + 1))
    for y in range(96):
        for x in range(192):
            if lidx[y * 192 + x] and lx + x >= left and ly + y < H and lx + x < W: pic.putpixel((lx + x, ly + y), col(96 + lidx[y * 192 + x]))
    count, data = frame_data[k]
    for t in range(count):
        c = int.from_bytes(data[t * 2:t * 2 + 2], 'little'); cell, n = c & 1023, c >> 10
        g = data[count * 2 + t * 32:count * 2 + t * 32 + 32]
        for y in range(8):
            for x in range(8):
                bit = 0x80 >> x
                v = (1 if g[y * 2] & bit else 0) | (2 if g[y * 2 + 1] & bit else 0) | (4 if g[16 + y * 2] & bit else 0) | (8 if g[17 + y * 2] & bit else 0)
                if v: pic.putpixel(((cell % 32) * 8 + x, (cell // 32) * 8 + y), col(n * 16 + v))
    sheet.paste(pic, ((j % 5) * (W + 4), (j // 5) * (H + 4)))
sheet.save(os.path.join(OUT, 'sheet.png'))
print(f'{sum(len(b) for _, b in banks) // 1024} KB in {len(banks)} banks; free banks left {len(free)}')
