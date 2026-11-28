"""The places of the game, as the N64 version has them (main.c areas_init, sides.h, npcDefs): size in metres, collision
grid, lamps, monster spawns, where one starts, the gates between them and who stands where. The N64 project is only read."""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N64 = os.path.join(os.path.dirname(ROOT), 'Anaroch_N64_Sprite')
N64SRC = os.path.join(N64, 'src')
read = lambda f: open(os.path.join(N64SRC, f), encoding='utf-8', errors='replace').read()
gy, tn, sides = read('area_graveyard.h'), read('area_town.h'), read('sides.h')


def nums(text, name):
    """the numbers of the C array `name`"""
    m = re.search(r'\b' + re.escape(name) + r'(?:\[[^\]]*\])*\s*=\s*\{(.*?)\};', text, re.S)
    assert m, name
    return [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', m.group(1))]


def tuples(text, name, n):
    v = nums(text, name)
    return [tuple(v[k:k + n]) for k in range(0, len(v), n)]


def grid_h(text, name):
    return [int(v) for v in nums(text, name)]


def grid_file(name):
    return list(open(os.path.join(N64, 'filesystem', name + '.grid'), 'rb').read())


HALF = 1.5707963
GRAVEYARD, TOWN, TRADE, SCRIP, INN = range(5)
# who: the order of the tables in src/rules/people.asm
ODA, WILMA, BRAM, GIDEON, ANSEL, MARTA, FINN = range(7)
tn_start = tuple(nums(tn, 'tn_start'))
street = lambda who, dx, dz, roam: (who, tn_start[0] + dx, tn_start[1] + dz, roam)
house_gate = lambda town_x, town_z: [((-1.0, 5.25, 1.0, 8.0), TOWN, (town_x, town_z), 0.0)]

PLACES = [
    dict(id='graveyard', name='THE GRAVEYARD', render='gymoon', flat=True, page=0, size=(72, 72), grid=grid_h(gy, 'gy_grid'),
         lights=[(x, z) for x, _, z in tuples(gy, 'gy_lights', 3)], spawns=tuples(gy, 'gy_spawns', 2), safe=0,
         start=tuple(nums(gy, 'gy_arrive')), people=[],
         # the east gate: the N64's rectangle lies wholly in the edge's blocked cells (its graveyard is left by the
         # Fields, not made yet), so it begins a little further in
         gates=[((34.4,) + tuple(nums(gy, 'gy_gate'))[1:], TOWN, tuple(nums(tn, 'tn_arrive')), HALF)]),        # east: the town's west gate
    dict(id='town', name='STORMREACH KEEP', render='town', flat=True, page=1, size=(80, 68), grid=grid_h(tn, 'tn_grid'),
         lights=[(x, z) for x, _, z in tuples(tn, 'tn_lights', 3)], spawns=[], safe=1, start=tn_start,
         people=[street(ODA, -6.5, -2.5, 3.0), street(WILMA, 8.0, 2.0, 2.5), street(BRAM, -30.0, 1.5, 2.0)],
         gates=[(tuple(nums(tn, 'tn_gate')), GRAVEYARD, tuple(nums(gy, 'gy_arrive')), -HALF),     # west: the graveyard
                ((-4.05, -9.50, -2.95, -8.60), TRADE, (0.0, 4.4), 3.14),
                ((-3.05, 21.50, -1.95, 22.40), SCRIP, (0.0, 4.4), 3.14),
                ((6.95, -9.50, 8.05, -8.60), INN, (0.0, 4.4), 3.14)]),
    dict(id='trade', name="GIDEON'S TRADING HOUSE", render='sd_i_trade', flat=False, page=2, size=(16, 14),
         grid=grid_file('sd_i_trade'), lights=[], spawns=[], safe=1, start=(0.0, 4.4),
         people=[(GIDEON, -0.5, -2.5, 1.4)], gates=house_gate(-3.5, -7.85)),
    dict(id='scrip', name='THE SCRIPTORIUM', render='sd_i_scrip', flat=False, page=2, size=(16, 14),
         grid=grid_file('sd_i_scrip'), lights=[], spawns=[], safe=1, start=(0.0, 4.4),
         people=[(ANSEL, -0.5, -1.5, 1.2)], gates=house_gate(-2.5, 23.15)),
    dict(id='inn', name='THE STORM LANTERN', render='sd_i_inn', flat=False, page=2, size=(18, 14),
         grid=grid_file('sd_i_inn'), lights=[], spawns=[], safe=1, start=(0.0, 4.4),
         people=[(MARTA, 5.5, -1.5, 1.0), (FINN, -3.5, 3.5, 1.6)], gates=house_gate(7.5, -7.85)),
]
for line in sides.split('\n'):                       # the doors as the N64 has them (a change there stops the build)
    if 'areas[AREA_TOWN].gates[' in line:
        v = [float(x) for x in re.findall(r'(-?\d+\.\d+)f', line)]
        assert any(tuple(v[:4]) == g[0] for g in PLACES[TOWN]['gates']), line
