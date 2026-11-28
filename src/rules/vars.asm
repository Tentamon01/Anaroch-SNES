; The RPG's memory: the pieces (work RAM $7E:2000, reached with long addresses) and the hero's numbers.
; Every item field is a word.
I_KIND = 0                   ; 0 nothing, 1 gear, 2 potion, 3 scroll, 4 key
I_RAR = 2                    ; 0 poor, 1 normal, 2 magic, 3 rare, 4 unique
I_BASE = 4                   ; base_tab (a unique: unique_tab); potion / scroll: which one
I_ILVL = 6
I_IDENT = 8
I_X = 10                     ; its cell in the bag
I_Y = 12
I_NMODS = 14
I_PRE = 16                   ; the affixes naming a magic piece ($FFFF none)
I_SUF = 18
I_W1 = 20                    ; the words of a rare name; w1 the adjective of a poor one
I_W2 = 22
I_KEYS = 24                  ; six properties and their values
I_VALS = 36
ITEM_BYTES = 64
ITEMS = $7E2000
BAG0 = 0                     ; offsets of the places: 40 in the bag, 7 worn, 4 on the belt, 8 on the ground, 2 spare
EQUIP0 = 40 * 64
BELT0 = 47 * 64
DROP0 = 51 * 64
TEMP = 59 * 64
TEMP2 = 60 * 64
ITEM_PLACES = 61
BAG_COLS = 10
BAG_ROWS = 4
BAG_SIZE = 40
KIND_GEAR = 1
KIND_POTION = 2
KIND_SCROLL = 3
KIND_KEY = 4
RAR_POOR = 0
RAR_NORMAL = 1
RAR_MAGIC = 2
RAR_RARE = 3
RAR_UNIQUE = 4
SRC_NORMAL = 0
SRC_CHAMPION = 1
SRC_BOSS = 2
SLOT_WEAPON = 0
SLOT_SHIELD = 4
MAX_LEVEL = 99

.ram $1900
; the hero's own numbers (strength, defence and life points are strb, defb, lifeb)
sDex:     .res 2
sEne:     .res 2
skillPts: .res 2
xph:      .res 2             ; experience, above 65535
stam:     .res 2
maxStam:  .res 2
heroFlags: .res 2            ; bit 0: the Four Winds read
; worked out from them and what is worn
wMin:     .res 2
wMax:     .res 2
pDex:     .res 2
resist:   .res 8
pmods:    .res 66            ; the sum of each property
famNow:   .res 2             ; the weapon's family (9: bare hands)
swingF:   .res 2             ; frames a swing takes
swingStep: .res 2            ; how fast the swing's pictures run (8.8)
atkAcc:   .res 2
reachPx:  .res 2
ranged:   .res 2
critPm:   .res 2             ; chances, of 1000
evadePm:  .res 2
blockPm:  .res 2
regenAdd: .res 2             ; life coming back, a frame (towards REGEN_STEP)
hspd:     .res 32            ; the hero's speed in the 8 directions (x, y)
; scratch for the rules
it:       .res 2             ; the item being worked on (offset in ITEMS)
rSlot:    .res 2
rFam:     .res 2
rReq:     .res 2
rW:       .res 2
rH:       .res 2
iWmin:    .res 2
iWmax:    .res 2
iStr:     .res 2
iHp:      .res 2
iDef:     .res 2
r0:       .res 2
r1:       .res 2
r2:       .res 2
r3:       .res 2
r4:       .res 2
r5:       .res 2
r6:       .res 2
r7:       .res 2
rm:       .res 2
rl:       .res 2
rh:       .res 2
rem:      .res 2
dv:       .res 2
bx0:      .res 2
by0:      .res 2
bsrc:     .res 2
bdst:     .res 2
bold:     .res 2
rlvl:     .res 2
rsrc:     .res 2
rtags:    .res 2
rsuf:     .res 2
rcnt:     .res 2
rnp:      .res 2
rns:      .res 2
rtot:     .res 2
rwho:     .res 2             ; the monster that is dropping
cEnh:     .res 2             ; the damage formula's extras: enhance %, chances of 1000
cCrit:    .res 2
cEvade:   .res 2
cBlock:   .res 2
cMiss:    .res 2             ; 1 evaded, 2 blocked
nlen:     .res 2
nsrc:     .res 2
nval:     .res 2
nkey:     .res 2
msgp:     .res 2             ; a message for the hero (an address in the rules' bank), 0 none
bagmap:   .res 80            ; which bag piece covers each cell ($FFFF none)
namebuf:  .res 48
affok:    .res 68            ; the affixes that fit, while one is picked
; the bag screen
inMenu:   .res 2             ; it is on screen (the frame interrupt sends its maps instead of the world's)
menuDirty: .res 2
bagZone:  .res 2
bagCx:    .res 2
bagCy:    .res 2
bagDoll:  .res 2
bagBelt:  .res 2
bagIdent: .res 2             ; the Scroll of Identify being read ($FFFF none)
bagTile:  .res 2             ; the next free picture tile
mvDir:    .res 2
dx0:      .res 2
dy0:      .res 2
dw:       .res 2
dh:       .res 2
infoY:    .res 2
infoIt:   .res 2
infoCol:  .res 2
infoCut:  .res 2
infoMods: .res 2
infoMod:  .res 2
; ---------------------------------------------------------------- skills
dotv:     .res 2             ; DotDir's working words
dots:     .res 2
bagPage:  .res 2             ; the bag screen's page: 0 the bag, 1 the skills
curTree:  .res 2
skRank:   .res 72            ; the rank of each skill
skActive: .res 2
casting:  .res 2
skCur:    .res 2
stamAcc:  .res 2
stamRate: .res 2
stamFight:.res 2
stamRegen:.res 2
spellPm:  .res 2
skMult:   .res 2
cryLeft:  .res 2
cryBonus: .res 2
healLeft: .res 2
healAdd:  .res 2
healAcc:  .res 2
teleWait: .res 2
spinLeft: .res 2
spinPulse:.res 2
leapLeft: .res 2
leapVx:   .res 2
leapVy:   .res 2
heroLift: .res 2
metLeft:  .res 2
metX:     .res 2
metY:     .res 2
metRad:   .res 2
metDmg:   .res 2
fighting: .res 2
skDirty:  .res 2
sk:       .res 2
skPow:    .res 2
skA:      .res 2
skB:      .res 2
skW:      .res 2
s0:       .res 2
s1:       .res 2
s2:       .res 2
s3:       .res 2
s4:       .res 2
s5:       .res 2
s6:       .res 2
s7:       .res 2
s8:       .res 2
s9:       .res 2
q0:       .res 2
q1:       .res 2
q2:       .res 2
q3:       .res 2
sx:       .res 2
sy:       .res 2
sdx:      .res 2
sdy:      .res 2
sHit:     .res 2
sStun:    .res 2
sChill:   .res 2
sRad:     .res 2
spellDmg: .res 2
px:       .res 2
py:       .res 2
vx:       .res 2
vy:       .res 2
pz:       .res 2
vz:       .res 2
ringR:    .res 2
ringT:    .res 2
ringI:    .res 2
shVx:     .res 2
shVy:     .res 2
shKind:   .res 2
shMult:   .res 2
shBurst:  .res 2
shPierce: .res 2
shRange:  .res 2
shSpeed:  .res 2
aimRange: .res 2
aimCos:   .res 2
shot:     .res 2
