"""The remake's places from their pre-rendered pictures: for each, 4bpp tiles in six palettes (world palettes 2-7),
the tile map, the walk-behind blocks, the glow of its lamps, its collision grid, gates and the spots its people stand on.
needs: node tools/make_area_unlit.mjs, then node tools/render_world.mjs
writes: out/game/world_pages.bin (the data ROM, a megabyte a page) and src/world.inc"""
import os, json, math, random, array
from PIL import Image
from places import PLACES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S0 = os.path.join(ROOT, 'out', 'step0')
OUT = os.path.join(ROOT, 'out', 'game'); os.makedirs(OUT, exist_ok=True)
NPAL = 6
bgr = lambda c: ((c[2] >> 3) << 10) | ((c[1] >> 3) << 5) | (c[0] >> 3)
w16 = lambda v: ', '.join('$%04X' % (x & 0xFFFF) for x in v)
words = lambda v: b''.join((x & 0xFFFF).to_bytes(2, 'little') for x in v)
long3 = lambda a: a.to_bytes(3, 'little')


class Page:
    """a megabyte of the data ROM, seen at $D00000 when $4831 selects it; nothing crosses a 64 KB bank unless asked"""
    def __init__(self): self.data = bytearray()
    def add(self, b):
        assert len(b) <= 0x10000, len(b)
        if (len(self.data) & 0xFFFF) + len(b) > 0x10000: self.data += bytes(0x10000 - (len(self.data) & 0xFFFF))
        at = 0xD00000 + len(self.data); self.data += b
        assert len(self.data) <= 0x100000, 'the page is full'
        return at
    def banks(self, b):
        """a long table from the start of a bank on -> that bank's number"""
        if len(self.data) & 0xFFFF: self.data += bytes(0x10000 - (len(self.data) & 0xFFFF))
        bank = 0xD0 + (len(self.data) >> 16); self.data += b
        assert len(self.data) <= 0x100000, 'the page is full'
        return bank


# work RAM bank $7F: where a place's tables are copied when the hero enters it (src/game/area.asm)
RAM = {'OCCMAP': (0x0000, 0x5000), 'OCCDEP': (0x5000, 0x5000), 'GRID': (0xA000, 0x2000), 'ROWPTR': (0xC000, 0x300),
       'GLOWPTR': (0xC300, 0x300), 'OCCROW': (0xC600, 0x100), 'PALS': (0xC700, 0x100), 'GATES': (0xC800, 0x100),
       'SPAWNS': (0xC900, 0x200), 'PEOPLE': (0xCB00, 0x80)}
HEAD = ['mapW', 'mapH', 'camMaxX', 'camMaxY', 'picKX', 'picKY', 'tileBank', 'occBank', 'occW', 'occH', 'areaW', 'areaH',
        'gridW', 'safeArea', 'glowSrc', 'glowSrcBank', 'glowBytes', 'nSpawns', 'nGates', 'nPeople', 'startX', 'startY']
DIRV = [(0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1)]


def screen_dir(rot):
    """a heading of the N64's (0 faces +z) -> the nearest of the pad's eight screen directions"""
    wx, wz = math.sin(rot), math.cos(rot)
    sx, sy = wx - wz / 2, (wx + wz) / 2
    return max(range(8), key=lambda d: (DIRV[d][0] * sx + DIRV[d][1] * sy) / math.hypot(*DIRV[d]))


def build(place, page):
    R = place['render']; AW, AH = place['size']; grid = place['grid']
    assert len(grid) == AW * AH, (place['id'], len(grid))
    P = json.load(open(os.path.join(S0, f'{R}_t1.json')))
    assert P['x'] == [16, 8] and P['z'] == [-8, 8]
    im = Image.open(os.path.join(S0, f'{R}_t1{"_flat" if place["flat"] else ""}_all.png')).convert('RGBA')
    W, H = im.width // 8, im.height // 8
    data = im.load()
    # the projection: picture x = wx - wz/2 + kx, picture y = (wx + wz)/2 + ky  (wx, wz: world px, 16 a metre, from the corner)
    kx = -AW * 8 + AH * 4 - P['minX']; ky = -AW * 4 - AH * 4 - P['minY']
    lights = place['lights']
    tiles = []
    for ty in range(H):
        for tx in range(W):
            px = []
            for y in range(8):
                for x in range(8):
                    r, g, b, a = data[tx * 8 + x, ty * 8 + y]
                    px.append((r & 248, g & 248, b & 248) if a > 127 else None)
            tiles.append(px)
    solid = [i for i, t in enumerate(tiles) if any(t)]
    mean = {i: tuple(sum(p[k] for p in tiles[i] if p) / sum(1 for p in tiles[i] if p) for k in range(3)) for i in solid}
    random.seed(3)
    bright = lambda p: p is not None and p[0] > 200 and p[1] > 130 and p[2] < 130
    flame = set(i for i in solid if sum(1 for p in tiles[i] if bright(p)) >= 3)
    rest = [i for i in solid if i not in flame]
    NG = NPAL - 1 if flame else NPAL
    cents = [mean[i] for i in random.sample(rest, NG)]
    for _ in range(12):
        groups = [[] for _ in range(NG)]
        for i in rest:
            m = mean[i]
            groups[min(range(NG), key=lambda c: (m[0] - cents[c][0]) ** 2 + (m[1] - cents[c][1]) ** 2 + (m[2] - cents[c][2]) ** 2)].append(i)
        cents = [tuple(sum(mean[i][k] for i in g) / len(g) for k in range(3)) if g else cents[c] for c, g in enumerate(groups)]
    if flame: groups.append(sorted(flame))

    pals, entry = [], {}                # entry[cell] = (tile id, palette)
    ids = {bytes(32): 0}                # tile 0: clear
    gfx = [bytes(32)]
    def enc(px):
        o = bytearray(32)
        for y in range(8):
            for x in range(8):
                v = px[y * 8 + x]; bit = 0x80 >> x
                if v & 1: o[y * 2] |= bit
                if v & 2: o[y * 2 + 1] |= bit
                if v & 4: o[16 + y * 2] |= bit
                if v & 8: o[17 + y * 2] |= bit
        return bytes(o)
    for g, members in enumerate(groups):
        pix = [p for i in members for p in tiles[i] if p]
        if len(pix) > 60000: pix = random.sample(pix, 60000)
        if flame and g == len(groups) - 1: pix = pix + [p for p in pix if bright(p)] * 6
        q = Image.new('RGB', (max(1, len(pix)), 1)); q.putdata(pix or [(0, 0, 0)])
        p = q.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[:45]
        cols = [tuple(p[k * 3:k * 3 + 3]) for k in range(len(p) // 3)]
        cols += [(0, 0, 0)] * (15 - len(cols))
        pals.append(cols)
        cache = {}
        for i in members:
            out = []
            for px in tiles[i]:
                if px is None: out.append(0); continue
                v = cache.get(px)
                if v is None: v = cache[px] = 1 + min(range(15), key=lambda j: (px[0] - cols[j][0]) ** 2 * 2 + (px[1] - cols[j][1]) ** 2 * 4 + (px[2] - cols[j][2]) ** 2)
                out.append(v)
            t = enc(out)
            if t not in ids: ids[t] = len(gfx); gfx.append(t)
            entry[i] = (ids[t], g)
    assert len(gfx) <= 8192, f'{len(gfx)} tiles'
    while len(pals) < NPAL: pals.append([(0, 0, 0)] * 15)

    # tiles: 2048 a bank, so a tile's address is simply bank TILE_BANK + id / 2048, (id % 2048) * 32
    tile_bank = page.banks(b''.join(gfx))
    # the map: whole rows in each bank; a table gives every row's address
    rows_per_bank = 0x10000 // (W * 2)
    rowptr = []
    for r0 in range(0, H, rows_per_bank):
        chunk = bytearray()
        for r in range(r0, min(H, r0 + rows_per_bank)):
            for c in range(W):
                t, pal = entry.get(r * W + c, (0, 0))
                chunk += (t | (pal << 13)).to_bytes(2, 'little')
        at = page.add(bytes(chunk))
        rowptr += [at + k * W * 2 for k in range(min(H, r0 + rows_per_bank) - r0)]

    # ---------------------------------------------------------------- walk-behind: 16x16 blocks of what stands up, with depth
    front = Image.open(os.path.join(OUT, f'front_{R}.png')).convert('RGBA')
    depth = array.array('h', open(os.path.join(OUT, f'front_{R}.bin'), 'rb').read())
    shown = Image.new('RGB', (W * 8, H * 8))        # the picture as the SNES shows it (the blocks copy its colours)
    sp = shown.load()
    for ty in range(H):
        for tx in range(W):
            t, pal = entry.get(ty * W + tx, (0, 0))
            if not t: continue
            g = gfx[t]
            for y in range(8):
                for x in range(8):
                    bit = 0x80 >> x
                    v = (1 if g[y * 2] & bit else 0) | (2 if g[y * 2 + 1] & bit else 0) | (4 if g[16 + y * 2] & bit else 0) | (8 if g[17 + y * 2] & bit else 0)
                    if v: sp[tx * 8 + x, ty * 8 + y] = pals[pal][v - 1]
    BW, BH = W * 8 // 16, H * 8 // 16
    fp = front.load()
    def wall_at(column, foot):
        """a block standing on a run of five blocked cells of the collision grid takes that run's direction"""
        rel = column - kx              # = wx - wz / 2
        wz = (2 * foot - rel) / 1.5; wx = 2 * foot - wz
        blocked = lambda cx, cz: not (0 <= cx < AW and 0 <= cz < AH) or grid[cz * AW + cx] != 0
        cx = min(AW - 1, max(0, int(wx // 16))); cz = min(AH - 1, max(0, int(wz // 16)))
        run_x = sum(blocked(cx + k, cz) for k in range(-2, 3)); run_z = sum(blocked(cx, cz + k) for k in range(-2, 3))
        if run_z == 5 and run_x <= 3: return 0x8000, -1.0
        if run_x == 5 and run_z <= 3: return 0x4000, 0.5
        return None
    blocks = []                                       # (bx, by, pixels, depth at the middle column, direction)
    def facing(pts):
        """how the foot depth runs across the columns: a wall running south (-1 a column), one running east (+1/2), or neither"""
        cols = {}
        for x, d in pts: cols.setdefault(x, []).append(d)
        med = [(x, sorted(v)[len(v) // 2]) for x, v in cols.items() if len(v) >= 3]
        if len(med) >= 6:
            mx = sum(x for x, _ in med) / len(med); md_ = sum(d for _, d in med) / len(med)
            slope = sum((x - mx) * (d - md_) for x, d in med) / sum((x - mx) ** 2 for x, _ in med)
            if -1.5 < slope < -0.6: return 0x8000, -1.0
            if 0.25 < slope < 0.8: return 0x4000, 0.5
        return 0, 0.0
    for by in range(BH):
        for bx in range(BW):
            px = []; ds = []
            for y in range(16):
                for x in range(16):
                    X, Y = bx * 16 + x, by * 16 + y
                    d = depth[Y * front.width + X]
                    if d != -32768 and fp[X, Y][3] > 127: px.append(sp[X, Y]); ds.append((x, d))
                    else: px.append(None)
            if len(ds) >= 8:
                bits, slope = facing(ds)
                mid = sorted(d - slope * (x - 8) for x, d in ds)[len(ds) // 2]
                bits, slope = wall_at(bx * 16 + 8, mid) or (bits, slope)
                at_mid = sorted(round(d - slope * (x - 8)) for x, d in ds)
                blocks.append((bx, by, px, at_mid[len(at_mid) // 2], bits))
    solidpx = [p_ for b in blocks for p_ in b[2] if p_]
    if len(solidpx) > 60000: solidpx = random.sample(solidpx, 60000)
    q = Image.new('RGB', (len(solidpx), 1)); q.putdata(solidpx)
    qp = q.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[:45]
    ocols = [tuple(qp[k * 3:k * 3 + 3]) for k in range(15)]
    ocache = {}
    def onear(c):
        v = ocache.get(c)
        if v is None: v = ocache[c] = 1 + min(range(15), key=lambda j: (c[0] - ocols[j][0]) ** 2 * 2 + (c[1] - ocols[j][1]) ** 2 * 4 + (c[2] - ocols[j][2]) ** 2)
        return v
    oids = {bytes(128): 0}; ogfx = [bytes(128)]
    omap = bytearray(BW * BH * 2); odep = bytearray(BW * BH * 2)
    for bx, by, px, d, bits in blocks:
        idx = [onear(p_) if p_ else 0 for p_ in px]
        raw = b''
        for ty in (0, 8):                              # two tile rows of 16 x 8, sent to video memory as two halves
            for tx in (0, 8):
                raw += enc([idx[(ty + y) * 16 + tx + x] for y in range(8) for x in range(8)])
        if raw not in oids: oids[raw] = len(ogfx); ogfx.append(raw)
        at = (by * BW + bx) * 2
        omap[at:at + 2] = (oids[raw] | bits).to_bytes(2, 'little'); odep[at:at + 2] = (d & 0xFFFF).to_bytes(2, 'little')
    occ_bank = page.banks(b''.join(ogfx))     # 512 to a bank
    occ_map = page.add(bytes(omap)); occ_dep = page.add(bytes(odep))

    # ---------------------------------------------------------------- the braziers' glow: a dithered 3-level layer (BG3)
    ma, mc = P['x'][0], P['z'][0]; mb, md = P['x'][1], P['z'][1]; det = ma * md - mc * mb
    to_px = lambda x, z: (x * ma + z * mc - P['minX'], x * mb + z * md - P['minY'])
    def ground(px_, py_):
        sx_, sy_ = px_ + P['minX'], py_ + P['minY']
        return ((md * sx_ - mc * sy_) / det, (-mb * sx_ + ma * sy_) / det)
    BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    gl = {}
    for lx, lz in lights:
        cx, cy = to_px(lx, lz)
        for y in range(max(0, int(cy) - 90), min(H * 8, int(cy) + 90)):
            for x in range(max(0, int(cx) - 120), min(W * 8, int(cx) + 120)):
                gx, gz = ground(x, y)
                dist = math.hypot(gx - lx, gz - lz)
                if dist < 4.2:
                    v = 3.2 * (1 - dist / 4.2) ** 1.1
                    if v > gl.get((x, y), 0): gl[(x, y)] = v
    tile_of = {}
    for (x, y), v in gl.items():
        level = min(3, int(v) + (1 if (v - int(v)) * 16 > BAYER[y & 3][x & 3] else 0))
        if level: tile_of.setdefault((x // 8, y // 8), [0] * 64)[(y & 7) * 8 + x % 8] = level
    uniq = {}
    for k_, t in tile_of.items(): uniq.setdefault(tuple(t), []).append(k_)
    keep = sorted(uniq, key=lambda t: -len(uniq[t]))[:127]
    kept = set(keep)
    gmap = bytearray(W * H)
    for t, cells_ in uniq.items():
        best = t if t in kept else min(keep, key=lambda k2: sum((a - b) * (a - b) for a, b in zip(k2, t)))
        gid = 1 + keep.index(best)
        for tx, ty in cells_: gmap[ty * W + tx] = gid
    def enc2(t):
        o = bytearray(16)
        for y in range(8):
            for x in range(8):
                v = t[y * 8 + x]; bit = 0x80 >> x
                if v & 1: o[y * 2] |= bit
                if v & 2: o[y * 2 + 1] |= bit
        return bytes(o)
    rows_g = 0x10000 // W
    gptr = []
    for r0 in range(0, H, rows_g):
        at = page.add(bytes(gmap[r0 * W:min(H, r0 + rows_g) * W]))
        gptr += [at + k * W for k in range(min(H, r0 + rows_g) - r0)]
    glow_tiles = bytes(16) + b''.join(enc2(t) for t in keep)
    glow_at = page.add(glow_tiles)

    to_world = lambda x, z: (round((x + AW / 2) * 16), round((z + AH / 2) * 16))
    gates = b''
    for (x0, z0, x1, z1), dest, (ax, az), rot in place['gates']:
        a, b = to_world(x0, z0); c, d = to_world(x1, z1)
        dw, dh = PLACES[dest]['size']
        gates += words([a, b, c, d, dest, round((ax + dw / 2) * 16), round((az + dh / 2) * 16), screen_dir(rot)])
    spawns = words([v for x, z in place['spawns'] for v in to_world(x, z)])

    def free(x, z, r=0.45):
        return all(0 <= int(x + dx + AW / 2) < AW and 0 <= int(z + dz + AH / 2) < AH
                   and grid[int(z + dz + AH / 2) * AW + int(x + dx + AW / 2)] == 0 for dx in (-r, r) for dz in (-r, r))
    people = b''
    for who, x, z, roam in place['people']:
        qx = x
        for i in range(40):                          # (main.c place_free: the nearest free ground along x)
            if free(qx, z): break
            qx += 0.6 * (1 if i & 1 else -1) * (i // 2 + 1)
        assert free(qx, z), (place['id'], who)
        a, b = to_world(qx, z)
        people += words([who, a, b, round(roam * 16)])

    recs = []
    def part(name, b, at=None):
        off, room = RAM[name]
        assert len(b) <= room, (place['id'], name, len(b))
        if b: recs.append(long3(page.add(b) if at is None else at) + words([off, len(b)]))
    part('OCCMAP', omap, occ_map); part('OCCDEP', odep, occ_dep)
    part('GRID', bytes(grid))
    part('ROWPTR', b''.join(long3(a) for a in rowptr))
    part('GLOWPTR', b''.join(long3(a) for a in gptr))
    part('OCCROW', words([y * BW * 2 for y in range(BH)]))
    pal = words([v for p in pals for v in [0] + [bgr(c) for c in p]])
    pal += words([0] + [bgr(c) for c in ocols]) + words([bgr((24, 12, 0)), bgr((48, 24, 0)), bgr((72, 40, 8))])
    part('PALS', pal); part('GATES', gates); part('SPAWNS', spawns); part('PEOPLE', people)
    sx, sz = to_world(*place['start'])
    # the head of the record: copied word for word to the variables of the same names (src/game/area.asm)
    head = dict(mapW=W, mapH=H, camMaxX=W * 8 - 256, camMaxY=H * 8 - 224, picKX=kx, picKY=ky, tileBank=tile_bank,
                occBank=occ_bank, occW=BW, occH=BH, areaW=AW * 16, areaH=AH * 16, gridW=AW, safeArea=place['safe'],
                glowSrc=glow_at & 0xFFFF, glowSrcBank=glow_at >> 16, glowBytes=len(glow_tiles),
                nSpawns=len(place['spawns']), nGates=len(place['gates']), nPeople=len(place['people']), startX=sx, startY=sz)
    at = page.add(words([head[n] for n in HEAD]) + b''.join(recs) + bytes(3))
    print(f"{place['id']}: {W} x {H} tiles, {len(gfx)} different ({len(gfx) * 32 // 1024} KB), walk-behind {len(blocks)} "
          f'({len(ogfx)} different), glow {len(keep)}, page {place["page"]} now {len(page.data) // 1024} KB')
    return at


pages = [Page() for _ in range(max(p['page'] for p in PLACES) + 1)]
at = []
for place in PLACES:
    random.seed(3)
    at.append(build(place, pages[place['page']]))
open(os.path.join(OUT, 'world_pages.bin'), 'wb').write(b''.join(bytes(p.data) + bytes(0x100000 - len(p.data)) for p in pages))

lines = ['; generated by tools/build_world.py - do not edit', '.bank 0', '.org $C800',
         f'PLACE_COUNT = {len(PLACES)}', f'WORLD_PAGES = {len(pages)}', f'HEAD_WORDS = {len(HEAD)}']
lines += [f'PLACE_{p["id"].upper()} = {i}' for i, p in enumerate(PLACES)]
lines += [f'W_{n} = ${off:04X}' for n, (off, _) in RAM.items()]
ram = ['; generated by tools/build_world.py - do not edit', '.ram $1C00                   ; the place the hero is in, in the order of its record']
ram += [f'{n}: .res 2' for n in HEAD]
open(os.path.join(ROOT, 'src', 'world_ram.inc'), 'w').write('\n'.join(ram) + '\n')
lines.append('place_head: .word ' + w16([a & 0xFFFF for a in at]))
lines.append('place_bank: .word ' + w16([a >> 16 for a in at]))
lines.append('place_page: .word ' + w16([p['page'] for p in PLACES]))
# movement: the pad's eight screen directions as world velocities of a given speed (1/16 px a frame)
def speeds(s):
    vx, vy = [], []
    for dx, dy in DIRV:
        wz = (2 * dy - dx) / 1.5; wx = dx + wz / 2           # screen direction -> world direction
        l = math.hypot(wx, wz)
        vx.append(round(wx / l * s)); vy.append(round(wz / l * s))
    return vx, vy
for name, s in (('h', 15), ('g', 6), ('w', 3), ('r', 5), ('k', 64), ('c', 112)):
    vx, vy = speeds(s)
    lines += [f'wspd_{name}x: .word {w16(vx)}', f'wspd_{name}y: .word {w16(vy)}']
open(os.path.join(ROOT, 'src', 'world.inc'), 'w').write('\n'.join(lines) + '\n')
