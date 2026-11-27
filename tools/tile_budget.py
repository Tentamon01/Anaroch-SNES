"""How a pre-rendered area fits the SNES: 6 background palettes of 15 colours, 8x8 tiles (mirrored ones count once).
python tools/tile_budget.py <name> [<name> ...]   names in out/step0 without .png; --save writes the SNES look.
For each: different tiles in the whole picture, and the most on one screen (with a margin for scrolling),
exact, and with near-identical tiles merged (mean difference per colour channel under TOL of 255)."""
import sys, os, random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S0 = os.path.join(ROOT, 'out', 'step0')
NPAL, TOL = 6, 9.0      # six: the HUD and glow layer (background 3) shares CGRAM with two world palettes
SPOT, SPOTS = 48, 2      # a merge may differ clearly (sum over the three channels > SPOT) in at most SPOTS pixels
WINW, WINH = 33, 29


def flips(t):
    rows = [t[i * 8:i * 8 + 8] for i in range(8)]
    h = [r[::-1] for r in rows]
    return (t, b''.join(h), b''.join(rows[::-1]), b''.join(h[::-1]))


def run(name, save):
    im = Image.open(os.path.join(S0, name + '.png')).convert('RGBA')
    W, H = im.width // 8, im.height // 8
    data = im.load()
    tiles = []          # per cell: list of 64 rgb or None
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
    # tiles with flames get a palette of their own: a few bright pixels would otherwise be averaged away
    bright = lambda p: p is not None and p[0] > 200 and p[1] > 130 and p[2] < 130
    flame = [i for i in solid if sum(1 for p in tiles[i] if bright(p)) >= 3]
    rest = [i for i in solid if i not in set(flame)]
    NG = NPAL - 1 if flame else NPAL
    cents = [mean[i] for i in random.sample(rest, NG)]
    for _ in range(12):
        groups = [[] for _ in range(NG)]
        for i in rest:
            m = mean[i]
            groups[min(range(NG), key=lambda c: (m[0] - cents[c][0]) ** 2 + (m[1] - cents[c][1]) ** 2 + (m[2] - cents[c][2]) ** 2)].append(i)
        cents = [tuple(sum(mean[i][k] for i in g) / len(g) for k in range(3)) if g else cents[c] for c, g in enumerate(groups)]
    if flame: groups.append(flame)
    pals, group_of = [], {}
    for g, members in enumerate(groups):
        pix = [p for i in members for p in tiles[i] if p]
        if len(pix) > 60000: pix = random.sample(pix, 60000)
        if not pix: pals.append([(0, 0, 0)] * 15); continue
        if flame and g == len(groups) - 1: pix = pix + [p for p in pix if bright(p)] * 6
        q = Image.new('RGB', (len(pix), 1)); q.putdata(pix)
        p = q.quantize(colors=15, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[:45]
        pals.append([tuple(p[k * 3:k * 3 + 3]) for k in range(len(p) // 3)])
        for i in members: group_of[i] = g
    cache = [dict() for _ in range(NPAL)]
    idx = {}
    for i in solid:
        g = group_of[i]; pal = pals[g]; c = cache[g]; out = bytearray(64)
        for k, p in enumerate(tiles[i]):
            if p is None: continue
            v = c.get(p)
            if v is None:
                v = c[p] = 1 + min(range(len(pal)), key=lambda j: (p[0] - pal[j][0]) ** 2 * 2 + (p[1] - pal[j][1]) ** 2 * 4 + (p[2] - pal[j][2]) ** 2)
            out[k] = v
        idx[i] = bytes(out)
    # exact: the same indices in the same palette, any mirroring
    exact = {}
    ids = {}
    for i in solid:
        key = (group_of[i], min(flips(idx[i])))
        ids[i] = exact.setdefault(key, len(exact))
    # near: greedy, against tiles of about the same average colour
    near_id, reps, buckets = {}, [], {}
    seen_key = {}
    for i in solid:
        key = (group_of[i], min(flips(idx[i])))
        if key in seen_key: near_id[i] = seen_key[key]; continue
        g = group_of[i]; pal = pals[g]
        def rgb(t): return [pal[v - 1] if v else None for v in t]
        mine = [rgb(f) for f in flips(idx[i])]
        m = mean[i]
        bk = (int(m[0]) >> 3, int(m[1]) >> 3, int(m[2]) >> 3)
        found = None
        for dr in (0, -1, 1):
            for dg in (0, -1, 1):
                for db in (0, -1, 1):
                    for r in buckets.get((bk[0] + dr, bk[1] + dg, bk[2] + db), ()):
                        other = reps[r]
                        for f in mine:
                            tot = 0; lim = TOL * 3 * 64; bad = 0
                            for a, b in zip(f, other):
                                if (a is None) != (b is None): tot = lim + 1; break
                                if a is not None:
                                    d = abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
                                    tot += d
                                    if d > SPOT: bad += 1
                                if tot > lim or bad > SPOTS: break
                            if tot <= lim and bad <= SPOTS: found = r; break
                        if found is not None: break
                    if found is not None: break
                if found is not None: break
            if found is not None: break
        if found is None:
            found = len(reps); reps.append(mine[0]); buckets.setdefault(bk, []).append(found)
        near_id[i] = seen_key[key] = found

    def screens(m):
        worst, total, n = 0, 0, 0
        for y in range(0, max(1, H - WINH), 3):
            for x in range(0, max(1, W - WINW), 3):
                cells = [(y + j) * W + x + i for j in range(min(WINH, H)) for i in range(min(WINW, W))]
                got = [m[c] for c in cells if c in m]
                if name.endswith('objects') or len(got) > 0.9 * len(cells):
                    u = len(set(got)); worst = max(worst, u); total += u; n += 1
        return worst, total // max(1, n)

    we, ae = screens(ids); wn, an = screens(near_id)
    print(f'{name:34s} cells {len(solid):6d} | different tiles: exact {len(exact):6d}  near {len(reps):6d} | per screen worst/average: exact {we:4d}/{ae:4d}  near {wn:4d}/{an:4d}')
    if '--exact' in sys.argv:           # the picture as the SNES would show it with nothing merged: only the palettes
        outp = Image.new('RGB', (W * 8, H * 8)); op = outp.load()
        for i in solid:
            pal = pals[group_of[i]]
            for k, v in enumerate(idx[i]):
                if v: op[(i % W) * 8 + k % 8, (i // W) * 8 + k // 8] = pal[v - 1]
        outp.save(os.path.join(S0, name + '_pal.png'))
    if save:
        outp = Image.new('RGB', (W * 8, H * 8))
        op = outp.load()
        for i in solid:
            t = reps[near_id[i]]
            # (the representative may be mirrored: choose the mirroring closest to this cell)
            pal = pals[group_of[i]]
            mine = [pal[v - 1] if v else (0, 0, 0) for v in idx[i]]
            best = min(flips_list(t), key=lambda f: sum(abs((a or (0, 0, 0))[k] - b[k]) for a, b in zip(f, mine) for k in range(3)))
            for k, p in enumerate(best):
                op[(i % W) * 8 + k % 8, (i // W) * 8 + k // 8] = p or (0, 0, 0)
        outp.save(os.path.join(S0, name + '_snes.png'))


def flips_list(t):
    rows = [t[i * 8:i * 8 + 8] for i in range(8)]
    h = [r[::-1] for r in rows]
    cat = lambda rs: [p for r in rs for p in r]
    return (t, cat(h), cat(rows[::-1]), cat(h[::-1]))


if __name__ == '__main__':
    save = '--save' in sys.argv
    for n in sys.argv[1:]:
        if not n.startswith('--'): run(n, save)
