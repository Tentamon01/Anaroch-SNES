; Anaroch SNES: the graveyard, with the mechanics of the N64 version (Anaroch_N64_Sprite/src/main.c, items.c).
; LoROM, 65816, built with tools/asm816.mjs. Mode 1: BG1 = the graveyard (streamed from a 72x72 cell map),
; BG2 = the HUD (life vial, belt, words), sprites = the N64's pre-rendered hero / ghouls / skeleton archer (32x32,
; frames DMA'd when they change) and 16x16 loot and arrows.
; Units: 1 metre = 16 px. Positions are 12.4 fixed point (px * 16). 60 frames a second.

.macro lsr2
 lsr
 lsr
.endmacro
.macro lsr3
 lsr
 lsr
 lsr
.endmacro
.macro lsr4
 lsr
 lsr
 lsr
 lsr
.endmacro
.macro asl4
 asl
 asl
 asl
 asl
.endmacro
.macro wait16
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
.endmacro

; joypad bits
PAD_B = $8000
PAD_Y = $4000
PAD_SELECT = $2000
PAD_START = $1000
PAD_UP = $0800
PAD_DOWN = $0400
PAD_A = $0080
PAD_X = $0040
PAD_L = $0020
PAD_R = $0010

; actor states (main.c ST_*)
ST_IDLE = 0
ST_MOVE = 1
ST_ATTACK = 2
ST_HIT = 3
ST_DEAD = 4
ST_GONE = 5

; modes
M_PLAY = 0
M_DEAD = 1
M_PAUSE = 2
M_STATS = 3

NACT = 5                     ; the hero + 4 monsters (main.c: 3 + lvl1 / 3 for the graveyard)
ARCHER_X = 6                 ; every third monster is a skeleton archer (ghouls[2] -> actor 3)
NDROP = 8
NARROW = 6
HUD_PRIO = $2000
.if MODE7
WINC = 128                   ; the Mode 7 map: 128 x 128 tiles, a window round the camera
WINR = 128
MSG_ROW1 = 21                ; the ground fills lines 0-159: words go in the HUD strip
MSG_ROW2 = 23
VIS_MIN = RELY_MIN
VIS_X = 200
VIS_MAX = RELY_MAX
PTAB = props_m7
PBUCK = pbucket_m7
PLY0 = PROPS_M7_LY0
PLX0 = PROPS_M7_LX0
PNR = PROPS_M7_NR
PNC = PROPS_M7_NC
.else
WINC = 64
WINR = 32
MSG_ROW1 = 12
MSG_ROW2 = 14
VIS_MIN = -112
VIS_X = 152
VIS_MAX = 174
PTAB = props_flat
PBUCK = pbucket_flat
PLY0 = PROPS_FLAT_LY0
PLX0 = PROPS_FLAT_LX0
PNR = PROPS_FLAT_NR
PNC = PROPS_FLAT_NC
.endif
CH_SLASH = FONT_BASE+37
CH_MINUS = FONT_BASE+40
CH_GT = FONT_BASE+44

; ---------------------------------------------------------------- RAM
.ram $10
vbl:      .res 2
ready:    .res 2
pad:      .res 2
padold:   .res 2
padnew:   .res 2
camx:     .res 2
camy:     .res 2
camc0:    .res 2
camr0:    .res 2
colflag:  .res 2
colmap:   .res 2
rowflag:  .res 2
rowmap:   .res 2
rng:      .res 2
nq:       .res 2
oamn:     .res 2
oamprev:  .res 2
rebuild:  .res 2
done:     .res 2
frame:    .res 2
tmp0:     .res 2
tmp1:     .res 2
tmp2:     .res 2
tmp3:     .res 2
tmp4:     .res 2
tmp5:     .res 2
tmp6:     .res 2
tmp7:     .res 2
tmp8:     .res 2
tmp9:     .res 2
tmpA:     .res 2
tmpB:     .res 2
tmpC:     .res 2
tmpD:     .res 2
tmpF:     .res 2
tmpG:     .res 2
ct0:      .res 2
ct1:      .res 2
ct2:      .res 2
us0:      .res 2
us1:      .res 2
us2:      .res 2
us3:      .res 2
us4:      .res 2
n0:       .res 2
n1:       .res 2
n2:       .res 2
n3:       .res 2
n4:       .res 2
n5:       .res 2
n6:       .res 2
; the player (items.c P)
level:    .res 2
xp:       .res 2
strb:     .res 2
defb:     .res 2
lifeb:    .res 2
points:   .res 2
gold:     .res 2
kills:    .res 2
hstr:     .res 2
hdef:     .res 2
atkmin:   .res 2
atkmax:   .res 2
beltsel:  .res 2
regen:    .res 2
hitstop:  .res 2
mode:     .res 2
modet:    .res 2
sayt:     .res 2
hudflag:  .res 2
nearshown: .res 2
statcur:  .res 2
hdmg:     .res 2
hfx:      .res 2
hfy:      .res 2
hcrit:    .res 2
landed:   .res 2
strp:     .res 2
attr:     .res 2
jmpv:     .res 2
lx:       .res 2
ly:       .res 2
lsx:      .res 2
lsy:      .res 2
ln:       .res 2
fontoff:  .res 2

.ram $0100
ex:       .res 10
ey:       .res 10
edir:     .res 10
est:      .res 10
etm:      .res 10
ehp:      .res 10
emaxhp:   .res 10
estr:     .res 10
edef:     .res 10
elvl:     .res 10
ecool:    .res 10
ekind:    .res 10
echamp:   .res 10
ealert:   .res 10
elost:    .res 10
ecall:    .res 10
ehomex:   .res 10
ehomey:   .res 10
ewx:      .res 10
ewy:      .res 10
ewt:      .res 10
eflash:   .res 10
edealt:   .res 10
ecur:     .res 10
estk:     .res 10
ealt:     .res 10
eanimt:   .res 10
dtyp:     .res 16
dpx:      .res 16
dpy:      .res 16
damt:     .res 16
dage:     .res 16
ax:       .res 12
ay:       .res 12
avx:      .res 12
avy:      .res 12
alife:    .res 12
astr:     .res 12
adir:     .res 12
belt:     .res 8
qbuf:     .res 48
numbuf:   .res 12
hudd:     .res 32
tmpw0:    .res 2
tmpw2:    .res 2
mk:       .res 2
mk1:      .res 2
mk2:      .res 2
mk3:      .res 2
rt0:      .res 2
rt1:      .res 2
rt2:      .res 2
fx:       .res 2
fy:       .res 2
flx:      .res 2
fly:      .res 2
hdmaen:   .res 2
tmpv:     .res 2
ndyn:     .res 2
dpos:     .res 2
ps:       .res 2
pl:       .res 2
pend:     .res 2
prow:     .res 2
prow0:    .res 2
pcol0:    .res 2
pcol1:    .res 2
dyn_key:  .res 48
dyn_rx:   .res 48
dyn_ref:  .res 48
.ram $0400
oam:      .res 544
.ram $0700
colbuf:   .res 128
rowbuf:   .res 128
.ram $0800
hudmap:   .res 2048

; ---------------------------------------------------------------- reset
.bank 0
.org $8000
Reset:
 sei
 clc
 xce
 rep #$38
 .a16
 .i16
 ldx #$1FFF
 txs
 lda #0
 tcd
 sep #$20
 .a8
 lda #$8F
 sta $2100
 lda #0
 ldx #$0001
@zp:
 sta.w $2100,x
 inx
 cpx #$0034
 bne @zp
 lda #$8F
 sta $2100
 stz $4200
 stz $420B
 stz $420C
 rep #$20
 .a16
 ldx #0
 lda #0
@clr:
 sta.w $0000,x
 inx
 inx
 cpx #$1F00
 bne @clr
 lda #$ACE1
 sta rng
 lda #512
 sta oamprev
 jsr InitVideo
 jsr NewGame
 jsr UpdateCam
 jsr FullMap
 jsr HudRefresh
 jsr BuildOam
 sep #$20
 .a8
 lda #$81
 sta $4200
 rep #$20
 .a16
 cli
 jmp MainLoop

InitVideo:
 .a16
 .i16
 sep #$20
 .a8
.if MODE7
 lda #$07
 sta $2105              ; mode 7 (the HDMA tables switch to mode 1 for the HUD strip)
 stz $211A
.else
 lda #$01
 sta $2105              ; mode 1
 lda #$01
 sta $2107              ; BG1 map at $0000, 64x32
.endif
 lda #$50
 sta $2108              ; BG2 (the HUD) map at $5000, 32x32
 lda #$42
 sta $210B              ; BG1 tiles $2000, BG2 tiles $4000
 lda #$63
 sta $2101              ; OBJ 16x16 / 32x32, tiles at $6000 (and $7000)
 lda #$13
 sta $212C              ; BG1 + BG2 + OBJ
 lda #$FF
 sta $2110              ; BG2 one line up (the PPU shows line VOFS + 1)
 sta $2110
 rep #$20
 .a16
 lda #$80
 sta n4
.if MODE7
 lda #m7_chars          ; the 8bpp tiles: the high bytes of VRAM $0000-$3FFF
 sta n0
 lda #^m7_chars
 sta n1
 stz n2
 lda #16384
 sta n3
 lda #$1900
 jsr DmaVc
.else
 lda #bg_tiles
 sta n0
 lda #^bg_tiles
 sta n1
 lda #$2000
 sta n2
 lda #8192
 sta n3
 jsr DmaV
.endif
 lda #hud_tiles
 sta n0
 lda #^hud_tiles
 sta n1
 lda #$4000
 sta n2
 lda #HUD_TILES_BYTES
 sta n3
 jsr DmaV
 lda #obj_static
 sta n0
 lda #^obj_static
 sta n1
 lda #$6800
 sta n2
 lda #2048
 sta n3
 jsr DmaV
 lda #obj_props
 sta n0
 lda #^obj_props
 sta n1
 lda #$7000
 sta n2
 lda #8192
 sta n3
 jsr DmaV
 lda #bg_cgram
 sta n0
 stz n1
 stz n2
 lda #256
 sta n3
 jsr DmaC
 lda #hud_pals
 sta n0
 lda #16
 sta n2
 lda #128
 sta n3
 jsr DmaC
 lda #obj_pals
 sta n0
 lda #128
 sta n2
 lda #256
 sta n3
 jsr DmaC
.if MODE7
 jsr HdmaSetup
.endif
 rts

.if MODE7
; HDMA: channels 1-4 the Mode 7 matrix per line (the tilt), 5 the mode, 6 the screens, 7 the fog of the far rows
HdmaSetup:
 .a16
 .i16
 ldx #0
 ldy #$10
@l:
 sep #$20
 .a8
 lda.w hdma_cfg,x
 sta.w $4300,y
 lda.w hdma_cfg+1,x
 sta.w $4301,y
 lda #0
 sta.w $4304,y
 rep #$20
 .a16
 lda.w hdma_cfg+2,x
 sta.w $4302,y
 inx
 inx
 inx
 inx
 tya
 clc
 adc #$10
 tay
 cpy #$80
 bne @l
 lda #$FE
 sta hdmaen
 rts
hdma_cfg:
 .byte 2, $1B
 .word hdma_A
 .byte 2, $1C
 .word hdma_B
 .byte 2, $1D
 .word hdma_C
 .byte 2, $1E
 .word hdma_D
 .byte 0, $05
 .word hdma_mode
 .byte 0, $2C
 .word hdma_tm
 .byte 0, $00
 .word hdma_fog
.endif

; n0 = source, n1 = bank, n2 = VRAM word address, n3 = bytes, n4 = VMAIN; DmaVc: A = the DMA mode and register
DmaV:
 .a16
 lda #$1801
DmaVc:
 sta tmpv
 sep #$20
 .a8
 lda n4
 sta $2115
 lda n1
 sta $4304
 rep #$20
 .a16
 lda n2
 sta $2116
 lda tmpv
 sta $4300
 lda n0
 sta $4302
 lda n3
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

; n0 = source, n1 = bank, n2 = CGRAM index, n3 = bytes
DmaC:
 .a16
 sep #$20
 .a8
 lda n2
 sta $2121
 lda n1
 sta $4304
 rep #$20
 .a16
 lda #$2200
 sta $4300
 lda n0
 sta $4302
 lda n3
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

; ---------------------------------------------------------------- NMI: everything for the PPU, in vblank
Nmi:
 rep #$30
 .a16
 .i16
 pha
 phx
 phy
 sep #$20
 .a8
 lda $4210
 rep #$20
 .a16
 lda ready
 bne @go
 jmp @out
@go:
 stz ready
 sep #$20
 .a8
 stz $2102
 stz $2103
 lda #0
 sta $4300
 lda #4
 sta $4301
 ldx #oam
 stx $4302
 stz $4304
 ldx #544
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
 lda nq
 beq @noq
 sta n5
 ldx #0
@qe:
 lda.w qbuf,x
 sta n0
 lda.w qbuf+2,x
 sta n1
 lda.w qbuf+4,x
 sta n2
 lda #128
 sta n3
 lda #$80
 sta n4
 stz n6
@rows:
 jsr DmaV
 lda n0
 clc
 adc #128
 sta n0
 lda n2
 clc
 adc #256
 sta n2
 inc n6
 lda n6
 cmp #4
 bne @rows
 txa
 clc
 adc #6
 tax
 dec n5
 bne @qe
@noq:
 lda colflag
 beq @nocol
 stz colflag
.if MODE7
 lda colmap
 sta n2
 lda #colbuf
 sta n0
 stz n1
 lda #128
 sta n3
 lda #$02
 sta n4
 lda #$1800
 jsr DmaVc
.else
 lda colmap
 and #$001F
 sta n2
 lda colmap
 and #$0020
 beq @c0
 lda n2
 clc
 adc #$0400
 sta n2
@c0:
 lda #colbuf
 sta n0
 stz n1
 lda #64
 sta n3
 lda #$81
 sta n4
 jsr DmaV
.endif
@nocol:
 lda rowflag
 beq @hud
 stz rowflag
.if MODE7
 lda rowmap
 xba
 lsr
 sta n2
 lda #rowbuf
 sta n0
 stz n1
 lda #128
 sta n3
 stz n4
 lda #$1800
 jsr DmaVc
.else
 lda rowmap
 asl
 asl
 asl
 asl
 asl
 sta n2
 lda #rowbuf
 sta n0
 stz n1
 lda #64
 sta n3
 lda #$80
 sta n4
 jsr DmaV
 lda n2
 clc
 adc #$0400
 sta n2
 lda #rowbuf+64
 sta n0
 jsr DmaV
.endif
@hud:
 lda #8                 ; HUD rows that changed (at most 8 a frame)
 sta n5
 ldx #0
@hr:
 lda.w hudd,x
 and #$00FF
 beq @hn
 sep #$20
 .a8
 stz.w hudd,x
 rep #$20
 .a16
 txa
 asl
 asl
 asl
 asl
 asl
 sta n6
 clc
 adc #$5000
 sta n2
 lda n6
 asl
 clc
 adc #hudmap
 sta n0
 stz n1
 lda #64
 sta n3
 lda #$80
 sta n4
 jsr DmaV
 dec n5
 beq @scroll
@hn:
 inx
 cpx #32
 bne @hr
@scroll:
 sep #$20
 .a8
 lda camx
 sta $210D
 lda camx+1
 sta $210D
 lda camy
 sta $210E
 lda camy+1
 sta $210E
.if MODE7
 lda fx                 ; the Mode 7 centre: the hero
 sta $211F
 lda fx+1
 sta $211F
 lda fy
 sta $2120
 lda fy+1
 sta $2120
 lda hdmaen
 sta $420C
 bne @hd
 lda #$01               ; no HDMA (the character window): mode 1, the HUD layer only
 sta $2105
 lda #$02
 sta $212C
@hd:
.endif
 lda #$0F
 sta $2100
 rep #$20
 .a16
 lda #1
 sta vbl
@out:
 rep #$30
 ply
 plx
 pla
 rti

Rti:
 rti

WaitVbl:
 .a16
@w:
 lda vbl
 beq @w
 stz vbl
 rts

; ---------------------------------------------------------------- main loop
MainLoop:
 .a16
 .i16
 inc frame
 lda $4218
 sta pad
 eor padold
 and pad
 sta padnew
 lda pad
 sta padold
 lda mode
 asl
 tax
 lda mode_jt,x
 sta jmpv
 jsr @go
 jsr UpdateCam
 lda rebuild
 beq @stream
 stz rebuild
 jsr FullMap
 bra @oam
@stream:
 jsr UpdateStream
@oam:
 lda hudflag
 beq @nh
 stz hudflag
 jsr HudRefresh
@nh:
 jsr BuildOam
 jsr QueueUploads
 lda #1
 sta ready
 jsr WaitVbl
 jmp MainLoop
@go:
 jmp (jmpv)

mode_jt: .word GamePlay, GameDead, GamePause, GameStats

GamePlay:
 .a16
 .i16
 lda padnew
 and #PAD_START
 beq @np
 lda #M_PAUSE
 sta mode
 lda #MSG_ROW1
 ldx #str_paused
 ldy #$0400|HUD_PRIO
 jmp PrintCenter
@np:
 lda padnew
 and #PAD_SELECT
 beq @ns
 lda #M_STATS
 sta mode
 stz statcur
.if MODE7
 stz hdmaen
.endif
 jmp StatsDraw
@ns:
 lda hitstop
 beq @run
 dec hitstop
 rts
@run:
 jsr UpdateHero
 jmp UpdateWorld

UpdateWorld:
 .a16
 .i16
 ldx #2
@m:
 phx
 jsr UpdateMonster
 plx
 inx
 inx
 cpx #NACT*2
 bne @m
 jsr UpdateArrows
 jsr UpdateDrops
 lda sayt
 beq @r
 dec sayt
 bne @r
 lda #22
 jsr ClearRow
@r:
 rts

GameDead:
 .a16
 .i16
 inc.w etm
 stz.w eflash
 jsr UpdateWorld
 inc modet
 lda modet
 cmp #150
 bne @w
 lda #MSG_ROW1
 ldx #str_died
 ldy #$0C00|HUD_PRIO
 jsr PrintCenter
 lda #MSG_ROW2
 ldx #str_rise
 ldy #$1000|HUD_PRIO
 jsr PrintCenter
@w:
 lda modet
 cmp #150
 bcc @r
 lda padnew
 and #PAD_START
 beq @r
 lda #MSG_ROW1
 jsr ClearRow
 lda #MSG_ROW2
 jsr ClearRow
 jsr RiseAgain
@r:
 rts

GamePause:
 .a16
 lda padnew
 and #PAD_START
 beq @r
 lda #MSG_ROW1
 jsr ClearRow
 stz mode
@r:
 rts

; ---------------------------------------------------------------- a new game / rising again (main.c new_game, respawn)
NewGame:
 .a16
 .i16
 lda #1
 sta level
 stz xp
 lda #10
 sta strb
 sta defb
 sta lifeb
 stz points
 stz gold
 stz kills
 stz beltsel
 lda #1
 sta.w belt
 sta.w belt+2               ; two healing potions to start with
 stz.w belt+4
 stz.w belt+6
 lda #$FFFF
 sta nearshown
 ldx #0
@k:
 stz.w ekind,x
 inx
 inx
 cpx #NACT*2
 bne @k
 lda #1
 ldx #ARCHER_X
 sta.w ekind,x
 lda #2
 sta.w ekind               ; (the hero's pictures)
 jsr RecalcStats
 lda.w emaxhp
 sta.w ehp
 jmp RiseAgain

RiseAgain:
 .a16
 .i16
 lda.w emaxhp
 sta.w ehp
 lda #START_X*16
 sta.w ex
 lda #START_Y*16
 sta.w ey
 lda #2
 sta.w edir
 stz.w est
 stz.w etm
 stz.w eflash
 stz mode
 stz hitstop
 ldx #0
 lda #$FFFF
@e:
 sta.w ecur,x
 inx
 inx
 cpx #NACT*2
 bne @e
 ldx #0
@d:
 stz.w dtyp,x
 inx
 inx
 cpx #NDROP*2
 bne @d
 ldx #0
@a:
 stz.w alife,x
 inx
 inx
 cpx #NARROW*2
 bne @a
 ldx #2
@g:
 phx
 jsr MonsterSpawn
 plx
 inx
 inx
 cpx #NACT*2
 bne @g
 lda #1
 sta rebuild
 sta hudflag
 rts

; the hero's numbers: the stats plus the Wooden Sword (6-11, +3 STR) and the Wooden Armor (+5 life, +4 DEF)
RecalcStats:
 .a16
 .i16
 lda strb
 clc
 adc #3
 sta hstr
 lda defb
 clc
 adc #4
 sta hdef
 lda lifeb
 clc
 adc #5
 sta.w emaxhp
 ; min = 6 * (100 + STR) / 100, max = STR + 11 * (100 + STR) / 100   (items.c calc_damage)
 lda hstr
 clc
 adc #100
 sta tmp0
 asl
 clc
 adc tmp0
 asl
 sta tmp1
 lda #100
 sta tmp7
 lda tmp1
 jsr Div
 sta atkmin
 lda tmp0
 asl
 asl
 asl
 clc
 adc tmp0
 clc
 adc tmp0
 clc
 adc tmp0
 jsr Div
 clc
 adc hstr
 sta atkmax
 lda.w ehp
 cmp.w emaxhp
 bcc @ok
 lda.w emaxhp
 sta.w ehp
@ok:
 rts

; ---------------------------------------------------------------- arithmetic
; Div: A (16 bit) / tmp7 (1..255) -> A = quotient, tmp6 = remainder
Div:
 .a16
 sta $4204
 sep #$20
 .a8
 lda tmp7
 sta $4206
 rep #$20
 .a16
 wait16
 lda $4216
 sta tmp6
 lda $4214
 rts

Rand:
 .a16
 lda rng
 asl
 asl
 asl
 asl
 asl
 asl
 asl
 eor rng
 sta rng
 xba
 and #$00FF
 lsr
 eor rng
 sta rng
 xba
 and #$FF00
 eor rng
 sta rng
 rts

; RandRange: A = n (1..255) -> A = 0 .. n-1
RandRange:
 .a16
 sta tmp7
 jsr Rand
 jsr Div
 lda tmp6
 rts

Abs16:
 .a16
 bpl @p
 eor #$FFFF
 inc a
@p:
 rts

; Dist: tmp0 = dx, tmp2 = dy -> A = approximate length (max + min * 3/8)
Dist:
 .a16
 lda tmp0
 jsr Abs16
 sta tmp3
 lda tmp2
 jsr Abs16
 sta tmp5
 cmp tmp3
 bcs @ymax
 lda tmp3                   ; |dx| is the bigger: swap
 sta tmp9
 lda tmp5
 sta tmp3
 lda tmp9
 sta tmp5
@ymax:
 lda tmp3                   ; tmp5 = max, tmp3 = min
 lsr
 lsr
 sta tmp9
 lda tmp3
 lsr3
 clc
 adc tmp9
 clc
 adc tmp5
 rts

; DirFrom: tmp0 = dx, tmp2 = dy -> A = direction 0..7 (0 S, 1 SW, 2 W, 3 NW, 4 N, 5 NE, 6 E, 7 SE), $FFFF for none
DirFrom:
 .a16
 lda tmp0
 jsr Abs16
 sta tmp8
 lda tmp2
 jsr Abs16
 sta tmp9
 ora tmp8
 bne @some
 lda #$FFFF
 rts
@some:
 lda tmp9
 asl
 cmp tmp8
 bcs @notx
 lda tmp0
 bmi @w
 lda #6
 rts
@w:
 lda #2
 rts
@notx:
 lda tmp8
 asl
 cmp tmp9
 bcs @diag
 lda tmp2
 bmi @n
 lda #0
 rts
@n:
 lda #4
 rts
@diag:
 lda tmp2
 bmi @up
 lda tmp0
 bmi @sw
 lda #7
 rts
@sw:
 lda #1
 rts
@up:
 lda tmp0
 bmi @nw
 lda #5
 rts
@nw:
 lda #3
 rts

; DotDir: Y = direction * 2, tmp0 = dx, tmp2 = dy -> A = 10 * (the direction's unit vector . (dx, dy)), signed
DotDir:
 .a16
 stz tmp3
 lda.w dirx,y
 beq @fy
 bmi @xm
 lda tmp0
 sta tmp3
 bra @fy
@xm:
 lda #0
 sec
 sbc tmp0
 sta tmp3
@fy:
 lda.w diry,y
 beq @one
 bmi @ym
 lda tmp3
 clc
 adc tmp2
 sta tmp3
 bra @two
@ym:
 lda tmp3
 sec
 sbc tmp2
 sta tmp3
@two:
 lda.w dirx,y
 beq @one
 lda tmp3                   ; diagonal: * 7 (10 / sqrt 2)
 asl
 asl
 asl
 sec
 sbc tmp3
 rts
@one:
 lda tmp3                   ; * 10
 asl
 asl
 clc
 adc tmp3
 asl
 rts

; RelHero: X = actor -> tmp0 = hero.x - x, tmp2 = hero.y - y (px), A = tmp4 = distance
RelHero:
 .a16
 .i16
 lda.w ex
 lsr4
 sta tmp0
 lda.w ex,x
 lsr4
 sta tmp1
 lda tmp0
 sec
 sbc tmp1
 sta tmp0
 lda.w ey
 lsr4
 sta tmp2
 lda.w ey,x
 lsr4
 sta tmp1
 lda tmp2
 sec
 sbc tmp1
 sta tmp2
 sta tmpw2
 lda tmp0
 sta tmpw0
 jsr Dist
 sta tmp4
 jsr Rot
 lda tmp4
 rts

; MulK: A = signed value, mk = 0..255 -> A = (A * mk) / 256, signed; X, Y kept
MulK:
 .a16
 sta mk1
 bpl @p
 eor #$FFFF
 inc a
@p:
 sta mk2
 sep #$20
 .a8
 lda mk
 sta $4202
 lda mk2
 sta $4203
 rep #$20
 .a16
 nop
 nop
 nop
 lda $4216
 xba
 and #$00FF
 sta mk3
 sep #$20
 .a8
 lda mk2+1
 sta $4203
 rep #$20
 .a16
 nop
 nop
 nop
 lda $4216
 clc
 adc mk3
 bit mk1
 bpl @r
 eor #$FFFF
 inc a
@r:
 rts

; Rot: tmp0 / tmp2 = a world vector -> the same seen from the camera (lx right, ly down the screen); the Mode 7
; camera has the N64's yaw (main.c CAM_YAW); the flat one looks straight down
Rot:
 .a16
.if MODE7
 lda #ROT_C
 sta mk
 lda tmp0
 jsr MulK
 sta rt0
 lda tmp2
 jsr MulK
 sta rt2
 lda #ROT_S
 sta mk
 lda tmp2
 jsr MulK
 sta rt1
 lda tmp0
 jsr MulK
 clc
 adc rt2
 sta tmp2
 lda rt0
 sec
 sbc rt1
 sta tmp0
.endif
 rts

; CalcDamage (items.c calc_damage): tmpC = attack min, tmpD = attack max, tmpF = defender's defense
;   -> A = damage, hcrit = 1 on a critical strike (x1.6)
CalcDamage:
 .a16
 .i16
 lda tmpD
 sec
 sbc tmpC
 inc a
 jsr RandRange
 clc
 adc tmpC
 sta tmpG                   ; the attack roll
 lda tmpF
 inc a
 jsr RandRange              ; the defense roll
 sta tmp8
 lda tmpG
 sec
 sbc tmp8
 bpl @pos
 lda #0
@pos:
 sta tmpG                   ; raw
 asl4
 sta tmp8
 asl
 asl
 clc
 adc tmp8
 sta tmp8                   ; raw * 80
 lda tmpF
 clc
 adc #80
 sta tmp7
 lsr
 clc
 adc tmp8
 jsr Div                    ; raw * (1 - def / (def + 80)), rounded
 sta tmpG
 stz hcrit
 lda #100
 jsr RandRange
 cmp #5
 bcs @nc
 lda #1
 sta hcrit
 lda tmpG
 asl
 asl
 asl
 clc
 adc #2
 sta tmp8
 lda #5
 sta tmp7
 lda tmp8
 jsr Div
 sta tmpG
@nc:
 lda tmpG
 rts

; ---------------------------------------------------------------- the map
TileEntry:
 .a16
 .i16
 lda tmp0
 cmp #144
 bcs @void
 lda tmp2
 cmp #144
 bcs @void
 lsr
 sta tmp4
 asl
 asl
 asl
 sta tmp5
 lda tmp4
 asl
 asl
 asl
 asl
 asl
 asl
 clc
 adc tmp5
 sta tmp5
 lda tmp0
 lsr
 clc
 adc tmp5
 tax
 sep #$20
 .a8
 lda.l world,x
 rep #$20
 .a16
 and #$00FF
.if MODE7
 asl
 asl
 sta tmp4
.else
 sta tmp5
 asl
 tax
 lda type_pal,x
 sta tmp4
 lda tmp5
 asl
 asl
 ora tmp4
 sta tmp4
.endif
 lda tmp0
 and #1
 ora tmp4
 sta tmp4
 lda tmp2
 and #1
 asl
 ora tmp4
 rts
@void:
 lda #252
 rts

; BuildCol: A = world tile column -> colbuf (the window's rows, in map-row order)
BuildCol:
 .a16
 .i16
 sta us0
 stz us2
 ldx #0
@r:
 lda us2
 sec
 sbc camr0
 and #WINR-1
 clc
 adc camr0
 sta tmp2
 lda us0
 sta tmp0
 phx
 jsr TileEntry
 plx
.if MODE7
 sep #$20
 .a8
 sta.w colbuf,x
 rep #$20
 .a16
 inx
.else
 sta.w colbuf,x
 inx
 inx
.endif
 inc us2
 lda us2
 cmp #WINR
 bne @r
 rts

; BuildRow: A = world tile row -> rowbuf (the window's columns, in map-column order)
BuildRow:
 .a16
 .i16
 sta tmp2
 stz us2
 ldx #0
@c:
 lda us2
 sec
 sbc camc0
 and #WINC-1
 clc
 adc camc0
 sta tmp0
 phx
 jsr TileEntry
 plx
.if MODE7
 sep #$20
 .a8
 sta.w rowbuf,x
 rep #$20
 .a16
 inx
.else
 sta.w rowbuf,x
 inx
 inx
.endif
 inc us2
 lda us2
 cmp #WINC
 bne @c
 rts

; CamTiles -> tmpA / tmpB = the map window's first world column / row
CamTiles:
 .a16
.if MODE7
 lda fx
 lsr3
 sec
 sbc #64
 sta tmpA
 lda fy
 lsr3
 sec
 sbc #64
 sta tmpB
.else
 lda camx
 lsr3
 sta tmpA
 lda camy
 lsr3
 sta tmpB
.endif
 rts

; the whole map for the current camera, during forced blank
FullMap:
 .a16
 .i16
 sep #$20
 .a8
 lda #$80
 sta $2100
 stz $420C              ; (the HDMA would write the brightness)
 rep #$20
 .a16
 jsr CamTiles
 lda tmpA
 sta camc0
 lda tmpB
 sta camr0
 stz us3
@col:
 lda us3
 sec
 sbc camc0
 and #WINC-1
 clc
 adc camc0
 sta us4
 jsr BuildCol
.if MODE7
 lda us4
 and #127
 sta n2
 lda #colbuf
 sta n0
 stz n1
 lda #128
 sta n3
 lda #$02
 sta n4
 lda #$1800
 jsr DmaVc
.else
 lda us4
 and #$001F
 sta n2
 lda us4
 and #$0020
 beq @lo
 lda n2
 clc
 adc #$0400
 sta n2
@lo:
 lda #colbuf
 sta n0
 stz n1
 lda #64
 sta n3
 lda #$81
 sta n4
 jsr DmaV
.endif
 inc us3
 lda us3
 cmp #WINC
 bne @col
 stz colflag
 stz rowflag
 rts

UpdateStream:
 .a16
 .i16
 jsr CamTiles
 lda camc0
 sta tmp2
 lda camr0
 sta tmp3
 lda tmpA
 sta camc0
 lda tmpB
 sta camr0
 lda tmpA
 sec
 sbc tmp2
 beq @row
 bmi @left
 lda tmpA
 clc
 adc #WINC-1
 bra @cb
@left:
 lda tmpA
@cb:
 sta tmp4
 and #WINC-1
 sta colmap
 lda tmp4
 jsr BuildCol
 lda #1
 sta colflag
@row:
 lda tmpB
 sec
 sbc tmp3
 beq @done
 bmi @up
 lda tmpB
 clc
 adc #WINR-1
 bra @rb
@up:
 lda tmpB
@rb:
 sta tmp4
 and #WINR-1
 sta rowmap
 lda tmp4
 jsr BuildRow
 lda #1
 sta rowflag
@done:
 rts

UpdateCam:
 .a16
 .i16
.if MODE7
 lda.w ex                   ; the camera turns round the hero, who stands at (128, M7_PY)
 lsr4
 sta fx
 sec
 sbc #128
 sta camx
 lda.w ey
 lsr4
 sta fy
 sec
 sbc #M7_PY
 sta camy
 rts
.else
 lda.w ex
 lsr4
 sec
 sbc #128
 bpl @a
 lda #0
@a:
 cmp #896
 bcc @b
 lda #896
@b:
 sta camx
 clc
 adc #128
 sta fx
 lda.w ey
 lsr4
 sec
 sbc #112
 bpl @c
 lda #0
@c:
 cmp #928
 bcc @d
 lda #928
@d:
 sta camy
 clc
 adc #112
 sta fy
 rts
.endif

; ---------------------------------------------------------------- collision and sight
; CellType: tmp6 = x px, tmp7 = y px -> A = the N64 grid's value there (0 free, 1 low, 2 tall; 2 outside); X kept
CellType:
 .a16
 .i16
 lda tmp6
 lsr4
 cmp #72
 bcs @out
 sta ct0
 lda tmp7
 lsr4
 cmp #72
 bcs @out
 sta ct1
 asl
 asl
 asl
 sta ct2
 lda ct1
 asl
 asl
 asl
 asl
 asl
 asl
 clc
 adc ct2
 clc
 adc ct0
 phx
 tax
 sep #$20
 .a8
 lda.l coll,x
 rep #$20
 .a16
 plx
 and #$00FF
 rts
@out:
 lda #2
 rts

; Blocked: tmp6 / tmp7 = px -> carry set when the cell is blocked (anything in the N64 grid: walls, trees, graves)
Blocked:
 .a16
 jsr CellType
 cmp #1
 rts

CheckFoot:
 .a16
 .i16
 lda tmpF
 lsr4
 sta tmp8
 lda tmpG
 lsr4
 sta tmp9
 lda tmp8
 sec
 sbc #4
 sta tmp6
 lda tmp9
 sec
 sbc #3
 sta tmp7
 jsr Blocked
 bcs @r
 lda tmp8
 clc
 adc #4
 sta tmp6
 jsr Blocked
 bcs @r
 lda tmp9
 clc
 adc #3
 sta tmp7
 jsr Blocked
 bcs @r
 lda tmp8
 sec
 sbc #4
 sta tmp6
 jsr Blocked
@r:
 rts

; MoveEnt: X = actor, tmpC / tmpD = velocity (12.4); each axis alone so walls are slid along (main.c move_slide)
MoveEnt:
 .a16
 .i16
 lda.w ex,x
 clc
 adc tmpC
 sta tmpF
 lda.w ey,x
 sta tmpG
 jsr CheckFoot
 bcs @ny
 lda tmpF
 sta.w ex,x
@ny:
 lda.w ex,x
 sta tmpF
 lda.w ey,x
 clc
 adc tmpD
 sta tmpG
 jsr CheckFoot
 bcs @ret
 lda tmpG
 sta.w ey,x
@ret:
 rts

; ClearLine (main.c clear_line): from actor X to the hero, a look every third of a metre; carry set when something tall
; (a wall, a tree, the crypt: 2 in the N64 grid) is in the way. Uses tmp0 / tmp2 / tmp4 from RelHero, keeps them.
ClearLine:
 .a16
 .i16
 lda #5
 sta tmp7
 lda tmp4
 jsr Div
 cmp #2
 bcs @some
 clc
 rts
@some:
 sta ln
 sta tmp7
 lda tmpw0
 jsr Abs16
 asl4
 jsr Div
 sta lsx
 lda tmpw0
 bpl @px
 lda #0
 sec
 sbc lsx
 sta lsx
@px:
 lda tmpw2
 jsr Abs16
 asl4
 jsr Div
 sta lsy
 lda tmpw2
 bpl @py
 lda #0
 sec
 sbc lsy
 sta lsy
@py:
 lda.w ex,x
 sta lx
 lda.w ey,x
 sta ly
 dec ln
@l:
 lda lx
 clc
 adc lsx
 sta lx
 lsr4
 sta tmp6
 lda ly
 clc
 adc lsy
 sta ly
 lsr4
 sta tmp7
 jsr CellType
 cmp #2
 bcs @blocked
 dec ln
 bne @l
 clc
 rts
@blocked:
 sec
 rts

; ---------------------------------------------------------------- the hero (main.c hero_update)
HERO_SWING = 45              ; the Wooden Sword: 0.75 s
HERO_HIT_AT = 20             ; heroAtkHit[sword] 0.44 of the swing
HERO_CHAIN = 41              ; a press after 0.92 of the swing chains the next
HERO_CANCEL = 36             ; movement cancels it after 0.8
REGEN_STEP = 12000           ; half a percent of life a second: maxHp / 12000 per frame

UpdateHero:
 .a16
 .i16
 inc.w etm
 lda.w eflash
 beq @nf
 dec.w eflash
@nf:
 lda padnew                 ; the belt: L / R choose a slot, X drinks from it
 and #PAD_L
 beq @nl
 lda beltsel
 clc
 adc #3
 and #3
 sta beltsel
 lda #1
 sta hudflag
@nl:
 lda padnew
 and #PAD_R
 beq @nr
 lda beltsel
 inc a
 and #3
 sta beltsel
 lda #1
 sta hudflag
@nr:
 lda padnew
 and #PAD_X
 beq @nx
 jsr BeltDrink
@nx:
 lda regen                  ; regeneration
 clc
 adc.w emaxhp
 sta regen
 cmp #REGEN_STEP
 bcc @nreg
 sec
 sbc #REGEN_STEP
 sta regen
 lda.w ehp
 cmp.w emaxhp
 bcs @nreg
 inc a
 sta.w ehp
 lda #1
 sta hudflag
@nreg:
 jsr PadDir
 sta tmpB                   ; the d-pad's direction or $FFFF
 lda.w est
 cmp #ST_ATTACK
 bne @na
 jmp @attack
@na:
 cmp #ST_HIT
 bne @nh
 lda.w etm
 cmp #15
 bcc @r
 stz.w est
 stz.w etm
@r:
 rts
@nh:
 lda padnew
 and #PAD_B|PAD_Y
 beq @move
 lda tmpB
 cmp #$FFFF
 beq @sw
 sta.w edir
@sw:
 lda #ST_ATTACK
 sta.w est
 stz.w etm
 stz.w edealt
 rts
@move:
 lda tmpB
 cmp #$FFFF
 beq @idle
 sta.w edir
 asl
 tax
 lda spd_hx,x
 sta tmpC
 lda spd_hy,x
 sta tmpD
 ldx #0
 jsr MoveEnt
 lda.w est
 cmp #ST_MOVE
 beq @wk
 lda #ST_MOVE
 sta.w est
 stz.w etm
@wk:
 lda.w eanimt
 clc
 adc #16
 sta.w eanimt
 rts
@idle:
 lda.w est
 beq @i2
 stz.w est
 stz.w etm
@i2:
 rts
@attack:
 lda.w etm
 cmp #HERO_HIT_AT
 bne @nd
 jsr HeroStrike
@nd:
 lda.w etm
 cmp #HERO_CHAIN
 bcc @nochain
 lda padnew
 and #PAD_B|PAD_Y
 beq @nochain
 lda tmpB
 cmp #$FFFF
 beq @c2
 sta.w edir
@c2:
 stz.w etm
 stz.w edealt
 rts
@nochain:
 lda.w etm
 cmp #HERO_SWING
 bcs @toidle
 cmp #HERO_CANCEL
 bcc @r2
 lda tmpB
 cmp #$FFFF
 beq @r2
@toidle:
 stz.w est
 stz.w etm
@r2:
 rts

; PadDir -> A = direction from the d-pad, $FFFF for none
PadDir:
 .a16
 lda pad
 xba
 and #$000F
 asl
 tax
 lda dir_of,x
 rts

BeltDrink:
 .a16
 .i16
 lda beltsel
 asl
 tax
 lda.w belt,x
 bne @have
 ldx #str_empty
 jmp Say
@have:
 lda.w ehp
 cmp.w emaxhp
 bcc @drink
 ldx #str_full
 jmp Say
@drink:
 lda beltsel
 asl
 tax
 stz.w belt,x
 lda.w emaxhp               ; heal 45 % of life (13/29), at least 1
 asl
 asl
 asl
 sta tmp0
 lda.w emaxhp
 asl
 asl
 clc
 adc tmp0
 clc
 adc.w emaxhp
 sta tmp0
 lda #29
 sta tmp7
 lda tmp0
 jsr Div
 bne @h1
 lda #1
@h1:
 clc
 adc.w ehp
 cmp.w emaxhp
 bcc @h2
 lda.w emaxhp
@h2:
 sta.w ehp
 lda #1
 sta hudflag
 rts

; the sword: every live monster within reach (1.8 m + 0.3) and in front (cos > 0.2)
HeroStrike:
 .a16
 .i16
 stz landed
 ldx #2
@l:
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 jmp @n
@alive:
 jsr RelHero
 lda #0
 sec
 sbc tmp0
 sta tmp0
 lda #0
 sec
 sbc tmp2
 sta tmp2                   ; hero -> monster
 lda tmp4
 cmp #34
 bcc @inreach
 jmp @n
@inreach:
 lda.w edir
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 sta tmp3
 lda tmp5
 bmi @n
 cmp tmp3
 bcc @n
 lda atkmin
 sta tmpC
 lda atkmax
 sta tmpD
 lda.w edef,x
 sta tmpF
 jsr CalcDamage
 sta hdmg
 lda.w ex
 lsr4
 sta hfx
 lda.w ey
 lsr4
 sta hfy
 lda hcrit
 beq @nc
 lda #2
 sta landed
 bra @hit
@nc:
 lda landed
 bne @hit
 lda #1
 sta landed
@hit:
 phx
 jsr HurtActor
 plx
@n:
 inx
 inx
 cpx #NACT*2
 beq @end
 jmp @l
@end:
 lda landed                 ; hitstop: 0.05 s, 0.09 s on a crit
 beq @r
 cmp #2
 beq @hc
 lda #3
 sta hitstop
 rts
@hc:
 lda #5
 sta hitstop
@r:
 rts

; HurtActor (main.c hurt): X = actor, hdmg, hfx / hfy = where the blow came from (px), hcrit = a bigger knockback
HurtActor:
 .a16
 .i16
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 rts
@alive:
 lda.w ehp,x
 sec
 sbc hdmg
 bcs @hp
 lda #0
@hp:
 sta.w ehp,x
 lda #9
 sta.w eflash,x
 cpx #0
 bne @kb
 lda #1
 sta hudflag
@kb:
 lda.w ex,x                 ; knockback: 0.25 m, 0.45 m on a crit
 lsr4
 sec
 sbc hfx
 sta tmp0
 lda.w ey,x
 lsr4
 sec
 sbc hfy
 sta tmp2
 jsr Rot
 jsr DirFrom
 cmp #$FFFF
 beq @nokb
 asl
 tay
 lda hcrit
 bne @big
 lda.w spd_kx,y
 sta tmpC
 lda.w spd_ky,y
 sta tmpD
 bra @mv
@big:
 lda.w spd_cx,y
 sta tmpC
 lda.w spd_cy,y
 sta tmpD
@mv:
 jsr MoveEnt
@nokb:
 cpx #0
 beq @state
 lda #1                     ; a monster struck knows where it came from
 sta.w ealert,x
 stz.w elost,x
@state:
 lda.w ehp,x
 bne @live
 lda #ST_DEAD
 sta.w est,x
 stz.w etm,x
 cpx #0
 beq @herodead
 jmp MonsterKilled
@herodead:
 lda #M_DEAD
 sta mode
 stz modet
 rts
@live:
 cpx #0
 bne @tohit
 lda.w est
 cmp #ST_ATTACK
 beq @r
@tohit:
 lda #ST_HIT
 sta.w est,x
 stz.w etm,x
@r:
 rts

; ---------------------------------------------------------------- the rewards (main.c ghoul_killed, items.c xp_for_kill / gain_xp)
MonsterKilled:
 .a16
 .i16
 inc kills
 lda.w elvl,x               ; experience: 8 + 4 per level (x3 champion), 20 % less per level below the hero's
 inc a
 sta tmp1
 asl
 asl
 clc
 adc #8
 sta tmp0
 lda.w echamp,x
 beq @nc
 lda tmp0
 asl
 clc
 adc tmp0
 sta tmp0
@nc:
 lda level
 sec
 sbc tmp1
 beq @full
 bmi @full
 asl
 sta tmp2                   ; 2 * below
 lda #10
 sec
 sbc tmp2
 beq @tiny
 bmi @tiny
 sta tmp2
 stz tmp9
@mul:
 lda tmp9
 clc
 adc tmp0
 sta tmp9
 dec tmp2
 bne @mul
 lda #10
 sta tmp7
 lda tmp9
 jsr Div
 sta tmp0
 bra @full
@tiny:
 lda tmp0                   ; at least 5 %
 lsr4
 bne @t1
 lda #1
@t1:
 sta tmp0
@full:
 lda tmp0
 jsr GainXp
 lda #100                   ; gold now and then (15 %, a champion 60 %)
 jsr RandRange
 sta tmp0
 lda #15
 ldy.w echamp,x
 beq @g1
 lda #60
@g1:
 cmp tmp0
 bcc @nog
 beq @nog
 lda.w echamp,x
 asl4
 sta tmp1
 lda.w elvl,x
 asl
 clc
 adc tmp1
 tay
 lda.w gold_tab,y
 sta tmpB
 lda #1
 jsr DropAt
@nog:
 lda #100                   ; a healing potion 5 %
 jsr RandRange
 cmp #5
 bcs @nop
 stz tmpB
 lda #2
 jsr DropAt
@nop:
 lda #100                   ; a Tome (one stat point) 1 %, a champion 10 %
 jsr RandRange
 sta tmp0
 lda #1
 ldy.w echamp,x
 beq @t2
 lda #10
@t2:
 cmp tmp0
 bcc @r
 beq @r
 stz tmpB
 lda #3
 jsr DropAt
@r:
 rts

; GainXp: A = experience
GainXp:
 .a16
 .i16
 clc
 adc xp
 sta xp
 stz tmp9
@lv:
 lda level
 cmp #50
 bcs @done
 asl
 tay
 lda xp
 cmp.w xp_next,y
 bcc @done
 sec
 sbc.w xp_next,y
 sta xp
 inc level
 inc points
 inc points
 inc tmp9
 bra @lv
@done:
 lda tmp9
 beq @r
 phx
 jsr RecalcStats
 plx
 lda.w emaxhp               ; a level up heals
 sta.w ehp
 lda #1
 sta hudflag
@r:
 rts

; ---------------------------------------------------------------- monsters (main.c ghoul_update, ghoul_spawn)
SIGHT = 144                  ; 9 m
HEAR = 48                    ; 3 m
LOSE = 256                   ; 16 m
LOSE_TIME = 240              ; 4 s
CALL_RANGE = 96              ; 6 m

MonsterSpawn:
 .a16
 .i16
 lda #40                    ; a spawn point 9 to 24 m from the hero
 sta tmpB
@try:
 jsr PickSpawn
 jsr RelHero
 lda tmp4
 cmp #144
 bcc @near
 cmp #384
 bcc @ok
@near:
 dec tmpB
 bne @try
 lda #16                    ; none there: anywhere not too close
 sta tmpB
@try2:
 jsr PickSpawn
 jsr RelHero
 lda tmp4
 cmp #128
 bcs @ok
 dec tmpB
 bne @try2
@ok:
 lda.w ex,x
 lsr4
 sta.w ehomex,x
 sta.w ewx,x
 lda.w ey,x
 lsr4
 sta.w ehomey,x
 sta.w ewy,x
 lda #3                     ; the graveyard: monster levels 1 to 3
 jsr RandRange
 inc a
 sta.w elvl,x
 stz.w echamp,x
 lda #100                   ; a champion 8 %: blue, three times the life
 jsr RandRange
 cmp #8
 bcs @nch
 lda #1
 sta.w echamp,x
@nch:
 lda.w ekind,x              ; mon_tab[(archer * 2 + champion) * 8 + level] = hp, str, def
 asl
 clc
 adc.w echamp,x
 asl
 asl
 asl
 clc
 adc.w elvl,x
 sta tmp0
 asl
 clc
 adc tmp0
 asl
 tay
 lda.w mon_tab,y
 sta.w ehp,x
 sta.w emaxhp,x
 lda.w mon_tab+2,y
 sta.w estr,x
 lda.w mon_tab+4,y
 sta.w edef,x
 lda #8
 jsr RandRange
 sta.w edir,x
 stz.w est,x
 stz.w etm,x
 lda #60
 sta.w ecool,x
 stz.w eflash,x
 stz.w ealert,x
 stz.w elost,x
 stz.w ecall,x
 stz.w estk,x
 lda #180
 jsr RandRange
 sta.w ewt,x
 rts

PickSpawn:
 .a16
 .i16
 lda #SPAWN_COUNT
 jsr RandRange
 asl
 asl
 tay
 lda.w spawn_tab,y
 asl4
 sta.w ex,x
 lda.w spawn_tab+2,y
 asl4
 sta.w ey,x
 rts

UpdateMonster:
 .a16
 .i16
 inc.w etm,x
 lda.w est,x
 cmp #ST_DEAD
 bcc @alive
 jmp @dead
@alive:
 lda.w ecool,x
 beq @c
 dec.w ecool,x
@c:
 lda.w eflash,x
 beq @f
 dec.w eflash,x
@f:
 lda.w ealert,x             ; senses: a look every fourth frame
 bne @alert
 txa
 lsr
 clc
 adc frame
 and #3
 bne @think
 jsr Sees
 bcc @think
 lda #1
 sta.w ealert,x
 stz.w elost,x
@alert:
 jsr RelHero
 lda.w est
 cmp #ST_DEAD
 bcs @lose
 lda tmp4
 cmp #LOSE
 bcc @kept
@lose:
 inc.w elost,x              ; it forgets the hero far away after a while
 lda.w elost,x
 cmp #LOSE_TIME
 bcc @call
 stz.w ealert,x
 lda.w ex,x
 lsr4
 sta.w ehomex,x
 sta.w ewx,x
 lda.w ey,x
 lsr4
 sta.w ehomey,x
 sta.w ewy,x
 bra @think
@kept:
 stz.w elost,x
@call:
 lda.w ecall,x              ; and calls the others near it, once a second
 beq @docall
 dec.w ecall,x
 bra @think
@docall:
 lda #60
 sta.w ecall,x
 jsr CallOthers
@think:
 lda.w est,x
 asl
 tay
 lda mon_jt,y
 sta jmpv
 jmp (jmpv)
@dead:
 cmp #ST_GONE
 beq @gone
 lda.w etm,x
 cmp #210                   ; the body lies 3.5 s
 bcc @r
 lda #ST_GONE
 sta.w est,x
 stz.w etm,x
@r:
 rts
@gone:
 lda.w etm,x
 cmp #360                   ; then 6 s before another rises
 bcc @r
 jmp MonsterSpawn

mon_jt: .word MonIdle, MonIdle, MonAttack, MonHit

; Sees (main.c sees): X = monster -> carry set when it sees the hero
Sees:
 .a16
 .i16
 lda.w est
 cmp #ST_DEAD
 bcs @no
 jsr RelHero
 cmp #SIGHT
 bcs @no
 cmp #HEAR
 bcc @line
 lda.w edir,x               ; behind it: (d . facing) / |d| < -0.3
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 clc
 adc tmp4
 clc
 adc tmp5
 bmi @no
@line:
 jsr ClearLine
 bcs @no
 sec
 rts
@no:
 clc
 rts

; CallOthers: an alerted monster calls the others within 6 m
CallOthers:
 .a16
 .i16
 stx tmpB
 ldy #2
@l:
 cpy tmpB
 beq @n
 lda.w est,y
 cmp #ST_DEAD
 bcs @n
 lda.w ealert,y
 bne @n
 lda.w ex,y
 lsr4
 sta tmp0
 lda.w ex,x
 lsr4
 sta tmp1
 lda tmp0
 sec
 sbc tmp1
 sta tmp0
 lda.w ey,y
 lsr4
 sta tmp2
 lda.w ey,x
 lsr4
 sta tmp1
 lda tmp2
 sec
 sbc tmp1
 sta tmp2
 phy
 jsr Dist
 ply
 cmp #CALL_RANGE
 bcs @n
 lda #1
 sta.w ealert,y
 lda #60
 sta.w ecall,y
@n:
 iny
 iny
 cpy #NACT*2
 bne @l
 ldx tmpB
 rts

; idle / moving
MonIdle:
 .a16
 .i16
 lda.w ealert,x
 bne @hunt
 jmp MonWander
@hunt:
 lda.w est
 cmp #ST_DEAD
 bcc @heroup
 stz.w est,x
 rts
@heroup:
 jsr RelHero
 lda.w ekind,x
 beq @ghoul
 jmp MonArcher
@ghoul:
 jsr DirFrom
 cmp #$FFFF
 beq @close
 sta.w edir,x
 lda tmp4
 cmp #19                    ; 1.15 m
 bcc @close
 lda.w edir,x
 jsr Walk
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #13
 sta.w eanimt,x
 rts
@close:
 stz.w est,x
 lda.w ecool,x
 bne @r
 lda #ST_ATTACK
 sta.w est,x
 stz.w etm,x
 stz.w edealt,x
@r:
 rts

; Walk: X = monster, A = direction; at the ghouls' 1.5 m/s, round what is in the way (main.c steer)
Walk:
 .a16
 .i16
 ldy.w estk,x
 beq @dir
 dec.w estk,x
 lda.w ealt,x
@dir:
 asl
 tay
 lda.w spd_gx,y
 sta tmpC
 lda.w spd_gy,y
 sta tmpD
WalkV:
 lda.w ex,x
 sta us0
 lda.w ey,x
 sta us1
 jsr MoveEnt
 lda.w ex,x
 cmp us0
 bne @moved
 lda.w ey,x
 cmp us1
 bne @moved
 lda #24
 sta.w estk,x
 jsr Rand
 and #4
 dec a
 dec a
 clc
 adc.w edir,x
 and #7
 sta.w ealt,x
@moved:
 rts

; wandering near home: a few steps, a pause, a few steps (0.6 m/s)
MonWander:
 .a16
 .i16
 lda.w ewt,x
 dec a
 sta.w ewt,x
 bpl @go
 lda #240
 jsr RandRange
 clc
 adc #150
 sta.w ewt,x
 lda #113
 jsr RandRange
 sec
 sbc #56
 clc
 adc.w ehomex,x
 sta.w ewx,x
 lda #113
 jsr RandRange
 sec
 sbc #56
 clc
 adc.w ehomey,x
 sta.w ewy,x
@go:
 lda.w ex,x
 lsr4
 sta tmp1
 lda.w ewx,x
 sec
 sbc tmp1
 sta tmp0
 lda.w ey,x
 lsr4
 sta tmp1
 lda.w ewy,x
 sec
 sbc tmp1
 sta tmp2
 jsr Dist
 cmp #7
 bcc @stand
 lda.w ewt,x
 cmp #150
 bcs @stand
 jsr Rot
 jsr DirFrom
 sta.w edir,x
 asl
 tay
 lda.w spd_wx,y
 sta tmpC
 lda.w spd_wy,y
 sta tmpD
 jsr WalkV
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #6
 sta.w eanimt,x
 rts
@stand:
 stz.w est,x
 rts

; the skeleton archer: shoots whenever it can, keeps 4.5 to 9 m away between shots
MonArcher:
 .a16
 .i16
 jsr DirFrom
 cmp #$FFFF
 beq @r
 sta tmpB
 jsr ClearLine
 bcs @approach
 lda tmp4
 cmp #176                   ; 11 m
 bcs @farline
 lda.w ecool,x
 bne @farline
 lda tmpB
 sta.w edir,x
 lda #ST_ATTACK
 sta.w est,x
 stz.w etm,x
 stz.w edealt,x
@r:
 rts
@farline:
 lda tmp4
 cmp #144
 bcs @approach
 cmp #72
 bcc @back
 lda tmpB
 sta.w edir,x
 stz.w est,x
 rts
@approach:
 lda tmpB
 sta.w edir,x
 jsr Walk
 bra @moving
@back:
 lda tmpB
 eor #4                     ; the other way, a little slower
 sta.w edir,x
 asl
 tay
 lda.w spd_rx,y
 sta tmpC
 lda.w spd_ry,y
 sta tmpD
 jsr WalkV
@moving:
 lda #ST_MOVE
 sta.w est,x
 lda.w eanimt,x
 clc
 adc #13
 sta.w eanimt,x
 rts

MonAttack:
 .a16
 .i16
 lda.w ekind,x
 beq @ghoul
 jsr RelHero                ; the archer: turns to aim while drawing, looses half way (0.35 s of 0.7)
 jsr DirFrom
 cmp #$FFFF
 beq @a1
 sta.w edir,x
@a1:
 lda.w etm,x
 cmp #21
 bne @a2
 jsr ShootArrow
@a2:
 lda.w etm,x
 cmp #42
 bcc @r
 stz.w est,x
 lda #72
 jsr RandRange
 clc
 adc #84
 sta.w ecool,x
@r:
 rts
@ghoul:
 lda.w etm,x
 cmp #25                    ; the blow lands at 0.42 s
 bne @end
 jsr RelHero
 lda tmp4
 cmp #26                    ; 1.6 m, in front
 bcs @end
 lda.w edir,x
 asl
 tay
 jsr DotDir
 sta tmp5
 lda tmp4
 asl
 clc
 adc tmp4
 sta tmp3
 lda tmp5
 bmi @end
 cmp tmp3
 bcc @end
 jsr MonsterBlow
@end:
 lda.w etm,x
 cmp #60
 bcc @r2
 stz.w est,x
 lda #48
 jsr RandRange
 clc
 adc #48
 sta.w ecool,x
@r2:
 rts

; MonsterBlow: X = monster: its strength (0 .. STR) against the hero's defense
MonsterBlow:
 .a16
 .i16
 stz tmpC
 lda.w estr,x
 sta tmpD
 lda hdef
 sta tmpF
 jsr CalcDamage
 sta hdmg
 stz hcrit
 lda.w ex,x
 lsr4
 sta hfx
 lda.w ey,x
 lsr4
 sta hfy
 phx
 ldx #0
 jsr HurtActor
 plx
 rts

MonHit:
 .a16
 .i16
 lda #25                    ; the ghoul's recoil 0.42 s, the skeleton's 0.33 s
 ldy.w ekind,x
 beq @g
 lda #20
@g:
 cmp.w etm,x
 beq @done
 bcs @r
@done:
 stz.w est,x
 lda #30
 sta.w ecool,x
@r:
 rts

; ---------------------------------------------------------------- arrows (main.c earrows_update)
ShootArrow:
 .a16
 .i16
 ldy #0
@f:
 lda.w alife,y
 beq @got
 iny
 iny
 cpy #NARROW*2
 bne @f
 rts
@got:
 sty tmpB
 jsr RelHero
 lda tmp4
 bne @d
 rts
@d:
 sta tmp7                   ; 2.75 m/s: 12/16 px a frame along the line to the hero
 lda tmpw0
 jsr Abs16
 sta tmp8
 asl
 clc
 adc tmp8
 asl
 asl
 jsr Div
 sta tmp8
 lda tmpw0
 bpl @vx
 lda #0
 sec
 sbc tmp8
 sta tmp8
@vx:
 lda tmpw2
 jsr Abs16
 sta tmp9
 asl
 clc
 adc tmp9
 asl
 asl
 jsr Div
 sta tmp9
 lda tmpw2
 bpl @vy
 lda #0
 sec
 sbc tmp9
 sta tmp9
@vy:
 jsr DirFrom
 ldy tmpB
 sta.w adir,y
 lda tmp8
 sta.w avx,y
 lda tmp9
 sta.w avy,y
 lda.w ex,x
 sta.w ax,y
 lda.w ey,x
 sta.w ay,y
 lda.w estr,x
 sta.w astr,y
 lda #300                   ; 14 m
 sta.w alife,y
 rts

UpdateArrows:
 .a16
 .i16
 ldx #0
@l:
 lda.w alife,x
 bne @on
 jmp @n
@on:
 dec a
 sta.w alife,x
 bne @fly0
 jmp @n
@fly0:
 lda.w ax,x
 clc
 adc.w avx,x
 sta.w ax,x
 lsr4
 sta tmp6
 lda.w ay,x
 clc
 adc.w avy,x
 sta.w ay,x
 lsr4
 sta tmp7
 jsr Blocked
 bcc @fly
 stz.w alife,x
 bra @n
@fly:
 lda.w est
 cmp #ST_DEAD
 bcs @n
 lda.w ex
 lsr4
 sec
 sbc tmp6
 jsr Abs16
 cmp #7
 bcs @n
 lda.w ey
 lsr4
 sec
 sbc tmp7
 jsr Abs16
 cmp #7
 bcs @n
 stz.w alife,x
 stz tmpC
 lda.w astr,x
 sta tmpD
 lda hdef
 sta tmpF
 phx
 jsr CalcDamage
 sta hdmg
 stz hcrit
 plx
 lda.w ax,x
 sec
 sbc.w avx,x
 lsr4
 sta hfx
 lda.w ay,x
 sec
 sbc.w avy,x
 lsr4
 sta hfy
 phx
 ldx #0
 jsr HurtActor
 plx
@n:
 inx
 inx
 cpx #NARROW*2
 beq @end
 jmp @l
@end:
 rts

; ---------------------------------------------------------------- loot on the ground (main.c drop_spawn, hero_update)
; DropAt: A = type (1 gold, 2 potion, 3 tome), tmpB = amount, X = the monster it falls from
DropAt:
 .a16
 .i16
 sta tmp0
 ldy #0
@f:
 lda.w dtyp,y
 beq @got
 iny
 iny
 cpy #NDROP*2
 bne @f
 rts
@got:
 lda tmp0
 sta.w dtyp,y
 lda tmpB
 sta.w damt,y
 lda #0
 sta.w dage,y
 phy
 lda #15
 jsr RandRange
 sec
 sbc #7
 sta tmp1
 lda #15
 jsr RandRange
 sec
 sbc #7
 sta tmp2
 ply
 lda.w ex,x
 lsr4
 clc
 adc tmp1
 sta.w dpx,y
 lda.w ey,x
 lsr4
 clc
 adc tmp2
 sta.w dpy,y
 rts

PICKUP_REACH = 22            ; 1.4 m
UpdateDrops:
 .a16
 .i16
 lda #$FFFF
 sta tmpB                   ; the nearest potion / tome
 lda #PICKUP_REACH
 sta tmpC
 ldx #0
@l:
 lda.w dtyp,x
 bne @on
 jmp @n
@on:
 lda.w dage,x
 cmp #24                    ; 0.4 s before it can be picked up
 bcs @ready
 inc a
 sta.w dage,x
 jmp @n
@ready:
 lda.w ex
 lsr4
 sec
 sbc.w dpx,x
 sta tmp0
 lda.w ey
 lsr4
 sec
 sbc.w dpy,x
 sta tmp2
 jsr Dist
 sta tmp4
 lda.w dtyp,x
 cmp #1
 bne @item
 lda tmp4                   ; gold: walked over
 cmp #11
 bcs @n
 lda gold
 clc
 adc.w damt,x
 bcc @g
 lda #$FFFF
@g:
 sta gold
 stz.w dtyp,x
 bra @n
@item:
 lda tmp4
 cmp tmpC
 bcs @n
 sta tmpC
 stx tmpB
@n:
 inx
 inx
 cpx #NDROP*2
 beq @end
 jmp @l
@end:
 lda mode
 bne @r
 lda tmpB
 cmp nearshown
 beq @same
 sta nearshown
 jsr ShowPrompt
@same:
 lda tmpB
 cmp #$FFFF
 beq @r
 lda padnew
 and #PAD_A
 beq @r
 ldx tmpB
 lda.w dtyp,x
 cmp #3
 beq @tome
 ldy #0                     ; a potion: into the first free belt slot
@b:
 lda.w belt,y
 beq @put
 iny
 iny
 cpy #8
 bne @b
 ldx #str_beltfull
 jmp Say
@put:
 lda #1
 sta.w belt,y
 stz.w dtyp,x
 lda #1
 sta hudflag
 rts
@tome:
 stz.w dtyp,x
 inc points
 lda #1
 sta hudflag
 ldx #str_tome_read
 jmp Say
@r:
 rts

ShowPrompt:
 .a16
 .i16
 lda nearshown
 cmp #$FFFF
 bne @show
 lda #23
 jmp ClearRow
@show:
 tax
 lda.w dtyp,x
 cmp #3
 beq @t
 lda #23
 ldx #str_pick_potion
 ldy #$0C00|HUD_PRIO
 jmp PrintCenter
@t:
 lda #23
 ldx #str_pick_tome
 ldy #$0800|HUD_PRIO
 jmp PrintCenter

; ---------------------------------------------------------------- HUD (BG2)
; Say: X = string; a message in gold for 2.5 s
Say:
 .a16
 .i16
 lda #150
 sta sayt
 lda #22
 ldy #$0800|HUD_PRIO
 jmp PrintCenter

; ClearRow: A = row (columns 3..31: the vial and the life numbers at 1-2 stay)
ClearRow:
 .a16
 .i16
 tay
 asl
 asl
 asl
 asl
 asl
 asl
 clc
 adc #6
 tax
 lda #29
 sta tmp0
@c:
 stz.w hudmap,x
 inx
 inx
 dec tmp0
 bne @c
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 rts

; PrintCenter: A = row, X = string, Y = attributes
PrintCenter:
 .a16
 .i16
 sta tmp1
 sty attr
 stx strp
 jsr ClearRow
 ldy #0
@len:
 sep #$20
 .a8
 lda (strp),y
 rep #$20
 .a16
 and #$00FF
 beq @got
 iny
 bra @len
@got:
 tya
 sta tmp0
 lda #32
 sec
 sbc tmp0
 lsr
 sta tmp0
 lda tmp1
 asl
 asl
 asl
 asl
 asl
 clc
 adc tmp0
 asl
 tax
 jmp PrintStr

; PrintAt: A = row * 32 + column, X = string, Y = attributes
PrintAt:
 .a16
 .i16
 sty attr
 stx strp
 asl
 tax
PrintStr:
 txa
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tay
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 ldy #0
@c:
 sep #$20
 .a8
 lda (strp),y
 rep #$20
 .a16
 and #$00FF
 beq @end
 phy
 sec
 sbc #32
 tay
 sep #$20
 .a8
 lda.w charmap,y
 rep #$20
 .a16
 and #$00FF
 clc
 adc fontoff
 ora attr
 sta.w hudmap,x
 ply
 inx
 inx
 iny
 bra @c
@end:
 rts

; PrintNum: A = value, X = map byte offset, attr set -> X after the digits
PrintNum:
 .a16
 .i16
 stx tmpA
 sta tmp0
 ldy #0
@d:
 lda #10
 sta tmp7
 lda tmp0
 jsr Div
 sta tmp0
 lda tmp6
 sta.w numbuf,y
 iny
 iny
 lda tmp0
 bne @d
 sty tmp1
 lda tmpA
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tay
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 ldy tmp1
 ldx tmpA
@o:
 dey
 dey
 lda.w numbuf,y
 clc
 adc #FONT_BASE+1
 clc
 adc fontoff
 ora attr
 sta.w hudmap,x
 inx
 inx
 cpy #0
 bne @o
 rts

; PutTile: A = entry, X = map byte offset (marks the row); X kept
PutTile:
 .a16
 .i16
 sta.w hudmap,x
 phx
 txa
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tax
 sep #$20
 .a8
 lda #1
 sta.w hudd,x
 rep #$20
 .a16
 plx
 rts

VIAL_ROW = 20
BELT_ROW = 25
HudRefresh:
 .a16
 .i16
 lda.w emaxhp               ; the vial: liquid from cut = top + (1 - life / max) * (bot - top) down
 sec
 sbc.w ehp
 sta tmp0
 asl
 asl
 asl
 sta tmp1
 lda tmp0
 asl
 asl
 asl
 asl
 asl
 clc
 adc tmp1
 sec
 sbc tmp0
 sta tmp1
 lda.w emaxhp
 sta tmp7
 lda tmp1
 jsr Div
 clc
 adc #VIAL_TOP
 sta tmpB
 stz tmpC
@vr:
 lda tmpC
 asl
 asl
 asl
 clc
 adc #8
 sec
 sbc tmpB                   ; full rows in this tile: 0..8
 bpl @s0
 lda #0
@s0:
 cmp #9
 bcc @s1
 lda #8
@s1:
 sta tmp2
 lda tmpC
 asl
 asl
 asl
 clc
 adc tmpC
 clc
 adc tmp2
 asl
 clc
 adc #VIAL_BASE
 ora #$0400|HUD_PRIO
 sta tmpD
 lda tmpC
 clc
 adc #VIAL_ROW
 asl
 asl
 asl
 asl
 asl
 inc a
 asl
 tax
 lda tmpD
 jsr PutTile
 inx
 inx
 lda tmpD
 inc a
 jsr PutTile
 inc tmpC
 lda tmpC
 cmp #6
 bne @vr
 lda #VIAL_ROW+6            ; the life numbers under it
 jsr ClearRow
 lda #$1000|HUD_PRIO
 sta attr
 ldx #((VIAL_ROW+6)*32+1)*2
 lda.w ehp
 jsr PrintNum
 lda #CH_SLASH|$1000|HUD_PRIO
 jsr PutTile
 inx
 inx
 lda.w emaxhp
 jsr PrintNum
 stz tmpC                   ; the belt: four slots, the chosen one framed in gold
@b:
 lda tmpC
 asl
 tax
 lda.w belt,x
 sta tmp0
 stz tmp1
 lda tmpC
 cmp beltsel
 bne @ns
 lda #2
 sta tmp1
@ns:
 lda tmp1
 clc
 adc tmp0
 asl
 asl
 clc
 adc #BELT_BASE
 ora #$0400|HUD_PRIO
 sta tmpD
 lda tmpC
 asl
 clc
 adc #BELT_ROW*32+12
 asl
 tax
 lda tmpD
 jsr PutTile
 inx
 inx
 lda tmpD
 inc a
 jsr PutTile
 txa
 clc
 adc #62
 tax
 lda tmpD
 inc a
 inc a
 jsr PutTile
 inx
 inx
 lda tmpD
 clc
 adc #3
 jsr PutTile
 inc tmpC
 lda tmpC
 cmp #4
 bne @b
 lda #24                    ; unspent stat points
 jsr ClearRow
 lda points
 beq @r
 lda mode
 bne @r
 lda #$0800|HUD_PRIO
 sta attr
 ldx #(24*32+6)*2
 lda points
 jsr PrintNum
 txa
 lsr
 inc a
 ldx #str_points
 ldy #$0800|HUD_PRIO
 jsr PrintAt
@r:
 rts

; ---------------------------------------------------------------- the character window (Select)
StatsDraw:
 .a16
 .i16
 lda #FONT2_BASE-FONT_BASE
 sta fontoff
 ldx #(5*32)*2
@bg:
 txa
 and #$003F
 cmp #4*2
 bcc @skip
 cmp #28*2
 bcs @skip
 lda #1|$0400|HUD_PRIO
 sta.w hudmap,x
@skip:
 inx
 inx
 cpx #(18*32)*2
 bne @bg
 ldx #5
@m:
 sep #$20
 .a8
 lda #1
 sta.w hudd,x
 rep #$20
 .a16
 inx
 cpx #18
 bne @m
 lda #6*32+6
 ldx #str_level
 ldy #$0800|HUD_PRIO
 jsr PrintAt
 lda #$0800|HUD_PRIO
 sta attr
 ldx #(6*32+12)*2
 lda level
 jsr PrintNum
 lda #7*32+6
 ldx #str_exp
 ldy #$0400|HUD_PRIO
 jsr PrintAt
 lda #$0400|HUD_PRIO
 sta attr
 ldx #(7*32+17)*2
 lda xp
 jsr PrintNum
 lda #CH_SLASH+FONT2_BASE-FONT_BASE|$0400|HUD_PRIO
 jsr PutTile
 inx
 inx
 lda level
 asl
 tay
 lda.w xp_next,y
 jsr PrintNum
 lda #9*32+7
 ldx #str_life
 ldy #$0400|HUD_PRIO
 jsr PrintAt
 ldx #(9*32+18)*2
 lda.w emaxhp
 jsr PrintNum
 lda #10*32+7
 ldx #str_strength
 ldy #$0400|HUD_PRIO
 jsr PrintAt
 ldx #(10*32+18)*2
 lda hstr
 jsr PrintNum
 lda #11*32+7
 ldx #str_defense
 ldy #$0400|HUD_PRIO
 jsr PrintAt
 ldx #(11*32+18)*2
 lda hdef
 jsr PrintNum
 lda #13*32+6
 ldx #str_damage
 ldy #$1000|HUD_PRIO
 jsr PrintAt
 lda #$1000|HUD_PRIO
 sta attr
 ldx #(13*32+17)*2
 lda atkmin
 jsr PrintNum
 lda #CH_MINUS+FONT2_BASE-FONT_BASE|$1000|HUD_PRIO
 jsr PutTile
 inx
 inx
 lda atkmax
 jsr PrintNum
 lda #14*32+6
 ldx #str_gold
 ldy #$1000|HUD_PRIO
 jsr PrintAt
 ldx #(14*32+17)*2
 lda gold
 jsr PrintNum
 lda #15*32+6
 ldx #str_kills
 ldy #$1000|HUD_PRIO
 jsr PrintAt
 ldx #(15*32+17)*2
 lda kills
 jsr PrintNum
 lda #16*32+6
 ldx #str_points_left
 ldy #$0800|HUD_PRIO
 jsr PrintAt
 lda #$0800|HUD_PRIO
 sta attr
 ldx #(16*32+18)*2
 lda points
 jsr PrintNum
 ldy #0                     ; the cursor
@cur:
 tya
 clc
 adc #9
 asl
 asl
 asl
 asl
 asl
 clc
 adc #5
 asl
 tax
 lda #1|$0400|HUD_PRIO
 cpy statcur
 bne @nc
 lda #CH_GT+FONT2_BASE-FONT_BASE|$0800|HUD_PRIO
@nc:
 phy
 jsr PutTile
 ply
 iny
 cpy #3
 bne @cur
 stz fontoff
 rts

GameStats:
 .a16
 .i16
 lda padnew
 and #PAD_SELECT|PAD_B|PAD_START
 beq @in
 ldy #5
@clr:
 tya
 phy
 jsr ClearRow
 ply
 iny
 cpy #18
 bne @clr
 stz mode
 lda #1
 sta hudflag
.if MODE7
 lda #$FE
 sta hdmaen
.endif
 rts
@in:
 lda padnew
 and #PAD_UP
 beq @nu
 lda statcur
 beq @nu
 dec statcur
 jmp StatsDraw
@nu:
 lda padnew
 and #PAD_DOWN
 beq @nd
 lda statcur
 cmp #2
 bcs @nd
 inc statcur
 jmp StatsDraw
@nd:
 lda padnew
 and #PAD_A
 beq @r
 lda points                 ; items.c spend_point: life, strength or defense
 beq @r
 dec points
 lda statcur
 bne @s1
 inc lifeb
 bra @sp
@s1:
 cmp #1
 bne @s2
 inc strb
 bra @sp
@s2:
 inc defb
@sp:
 jsr RecalcStats
 lda #1
 sta hudflag
 jmp StatsDraw
@r:
 rts

; ---------------------------------------------------------------- sprites
; FrameId: X = actor -> A = direction * 15 + pose (0-1 idle, 2-5 walk, 6-9 attack, 10 hit, 11-14 death)
FrameId:
 .a16
 .i16
 lda.w est,x
 asl
 tay
 lda fid_jt,y
 sta jmpv
 jmp (jmpv)
fid_jt: .word FidIdle, FidWalk, FidAtk, FidHit, FidDead, FidIdle
FidIdle:
 lda.w etm,x
 lsr4
 lsr2
 and #1
 jmp FidGo
FidWalk:
 lda.w eanimt,x
 xba
 and #3
 clc
 adc #2
 jmp FidGo
FidHit:
 lda #10
 jmp FidGo
FidDead:
 lda.w etm,x                ; 2.4 s over the 4 pictures, then the body
 sta tmp0
 asl
 asl
 asl
 sec
 sbc tmp0
 xba
 and #$00FF
 cmp #3
 bcc @d
 lda #3
@d:
 clc
 adc #11
 jmp FidGo
FidAtk:
 lda.w ekind,x
 beq @g
 cmp #1
 beq @k
 lda.w etm,x                ; the hero: 45 frames (etm * 23 / 256)
 sta tmp0
 asl4
 sta tmp1
 lda tmp0
 asl
 asl
 asl
 clc
 adc tmp1
 sec
 sbc tmp0
 xba
 and #$00FF
 bra @c
@g:
 lda.w etm,x                ; the ghoul: 60 frames
 lsr4
 bra @c
@k:
 lda.w etm,x                ; the skeleton: 42 frames
 sta tmp0
 asl
 clc
 adc tmp0
 lsr4
 lsr
@c:
 cmp #3
 bcc @o
 lda #3
@o:
 clc
 adc #6
FidGo:
 sta tmp0
 lda.w edir,x
 asl4
 sec
 sbc.w edir,x
 clc
 adc tmp0
 rts

QueueUploads:
 .a16
 .i16
 stz nq
 ldx #0
@l:
 lda nq
 cmp #5
 bcs @done
 lda.w est,x
 cmp #ST_GONE
 beq @n
 jsr FrameId
 cmp.w ecur,x
 beq @n
 jsr Enqueue
@n:
 inx
 inx
 cpx #NACT*2
 bne @l
@done:
 rts

; Enqueue: X = actor, A = frame id
Enqueue:
 .a16
 .i16
 sta tmp2
 sta.w ecur,x
 asl
 clc
 adc tmp2
 tay
 stz tmp4
 lda.w ekind,x
 beq @g
 cmp #1
 beq @k
 lda.w hero_ptrs,y
 sta tmp3
 lda.w hero_ptrs+2,y
 bra @q
@g:
 lda.w ghoul_ptrs,y
 sta tmp3
 lda.w ghoul_ptrs+2,y
 bra @q
@k:
 lda.w skel_ptrs,y
 sta tmp3
 lda.w skel_ptrs+2,y
@q:
 and #$00FF
 sta tmp4
 lda nq
 asl
 sta tmp5
 asl
 clc
 adc tmp5
 tay
 lda tmp3
 sta.w qbuf,y
 lda tmp4
 sta.w qbuf+2,y
 lda.w slot_vram,x
 sta.w qbuf+4,y
 inc nq
 rts

BuildOam:
 .a16
 .i16
 ldx #0
 lda #$E000
@c:
 sta.w oam,x
 inx
 inx
 inx
 inx
 cpx oamprev
 bcc @c
 ldx #0
 lda #0
@h:
 sta.w oam+512,x
 inx
 inx
 cpx #32
 bne @h
 stz oamn
 lda fx                     ; the focus, seen from the camera
 sta tmp0
 lda fy
 sta tmp2
 jsr Rot
 lda tmp0
 sta flx
 lda tmp2
 sta fly
 stz ndyn                   ; the things that move, sorted by depth
 ldx #0
@ac:
 lda.w est,x
 cmp #ST_GONE
 beq @an
 cpx #0
 beq @vis
 lda.w eflash,x             ; a monster struck blinks
 beq @vis
 lda frame
 and #2
 bne @an
@vis:
 lda.w ex,x
 lsr4
 sta tmp0
 lda.w ey,x
 lsr4
 sta tmp2
 txa
 jsr AddDyn
@an:
 inx
 inx
 cpx #NACT*2
 bne @ac
 ldx #0
@ar:
 lda.w alife,x
 beq @arn
 lda.w ax,x
 lsr4
 sta tmp0
 lda.w ay,x
 lsr4
 sta tmp2
 txa
 ora #$0100
 jsr AddDyn
@arn:
 inx
 inx
 cpx #NARROW*2
 bne @ar
 ldx #0
@dr:
 lda.w dtyp,x
 beq @drn
 lda.w dpx,x
 sta tmp0
 lda.w dpy,x
 sta tmp2
 txa
 ora #$0200
 jsr AddDyn
@drn:
 inx
 inx
 cpx #NDROP*2
 bne @dr
 stz dpos
 jsr EmitProps
 lda #0                     ; what is left of the moving things
 jsr FlushDyn
 lda oamn
 sta oamprev
 rts

; AddDyn: tmp0 / tmp2 = world px, A = what (0 actor, 1 arrow, 2 loot | its offset); inserted by depth, nearest first
AddDyn:
 .a16
 .i16
 sta tmp9
 jsr Rot
 lda tmp0
 sec
 sbc flx
 sta tmp0
 lda tmp2
 sec
 sbc fly
 clc
 adc #$4000                 ; (the key: depth + $4000, compared unsigned)
 sta tmp2
 ldy ndyn
@ins:
 cpy #0
 beq @put
 lda.w dyn_key-2,y
 cmp tmp2
 bcs @put
 sta.w dyn_key,y
 lda.w dyn_rx-2,y
 sta.w dyn_rx,y
 lda.w dyn_ref-2,y
 sta.w dyn_ref,y
 dey
 dey
 bra @ins
@put:
 lda tmp2
 sta.w dyn_key,y
 lda tmp0
 sta.w dyn_rx,y
 lda tmp9
 sta.w dyn_ref,y
 lda ndyn
 clc
 adc #2
 sta ndyn
 rts

; FlushDyn: A = a depth key; emits the moving things at least that near. X kept
FlushDyn:
 .a16
 .i16
 sta tmpA
 phx
@l:
 ldy dpos
 cpy ndyn
 bcc @more
 jmp @r
@more:
 lda.w dyn_key,y
 cmp tmpA
 bcs @take
 jmp @r
@take:
 sec
 sbc #$4000
 sta tmpD
 lda.w dyn_rx,y
 sta tmpC
 lda.w dyn_ref,y
 sta tmpB
 iny
 iny
 sty dpos
 jsr Project
 bcc @vis
 jmp @l
@vis:
 lda tmpB
 xba
 and #$00FF
 beq @actor
 cmp #1
 beq @arrow
 lda tmpB                   ; loot
 and #$00FF
 tax
 lda.w dtyp,x
 asl
 tay
 lda.w drop_tile-2,y
 sta tmp3
 lda pl
 sec
 sbc #9
 sta tmp1
 bra @small
@arrow:
 lda tmpB
 and #$00FF
 tax
 lda.w adir,x
 asl
 tay
 lda.w arrow_tile,y
 sta tmp3
 lda pl
 sec
 sbc #23
 sta tmp1
@small:
 lda ps
 sec
 sbc #8
 sta tmp0
 lda #$2E00                 ; palette 7, priority 2
 ora tmp3
 sta tmp3
 stz tmp4
 jsr EmitOne
 jmp @l
@actor:
 lda tmpB
 and #$00FF
 tax
 jsr EmitActor
 jmp @l
@r:
 plx
 rts

; Project: tmpC = x, tmpD = depth from the focus (camera px) -> ps = screen x, pl = screen line; carry set when out of view
Project:
 .a16
 .i16
.if MODE7
 lda tmpD
 sec
 sbc #RELY_MIN
 bmi @no
 cmp #RELY_MAX-RELY_MIN+1
 bcs @no
 tax
 sep #$20
 .a8
 lda.w ly2line,x
 rep #$20
 .a16
 and #$00FF
 sta pl
 tax
 sep #$20
 .a8
 lda.w ik7,x
 rep #$20
 .a16
 and #$00FF
 sta mk
 lda tmpC
 jsr MulK
 asl
 clc
 adc #128
 sta ps
 clc
 rts
@no:
 sec
 rts
.else
 lda tmpD
 clc
 adc #112
 sta pl
 lda tmpC
 clc
 adc #128
 sta ps
 clc
 rts
.endif

; EmitProps: the graves, crosses, rocks, bones, braziers and trees in view, nearest first, the moving things between
EmitProps:
 .a16
 .i16
 lda fly                    ; the bucket rows (16 px of depth) that can be seen, nearest first
 clc
 adc #VIS_MAX
 sec
 sbc #PLY0
 bpl @g1
 rts
@g1:
 lsr4
 cmp #PNR
 bcc @r1
 lda #PNR-1
@r1:
 sta prow
 lda fly
 clc
 adc #VIS_MIN
 sec
 sbc #PLY0
 bpl @r2
 lda #0
@r2:
 lsr4
 sta prow0
 lda flx                    ; and the columns (128 px)
 sec
 sbc #VIS_X+PLX0
 bpl @c1
 lda #0
@c1:
 asl
 xba
 and #$00FF                 ; / 128
 sta pcol0
 lda flx
 clc
 adc #VIS_X
 sec
 sbc #PLX0
 bpl @c2
 rts
@c2:
 asl
 xba
 and #$00FF
 cmp #PNC
 bcc @c3
 lda #PNC-1
@c3:
 sta pcol1
@row:
 lda prow                   ; bucket = row * PNC + column
 cmp prow0
 bcs @rowok
 rts
@rowok:
 sep #$20                   ; row * PNC on the multiplier
 .a8
 sta $4202
 lda #PNC
 sta $4203
 rep #$20
 .a16
 nop
 nop
 nop
 lda $4216
 sta tmp1
 clc
 adc pcol0
 asl
 tax
 lda.l PBUCK,x
 sta tmpF                   ; the first prop of the row's visible columns
 lda tmp1
 clc
 adc pcol1
 inc a
 asl
 tax
 lda.l PBUCK,x
 tax                        ; one past the last
@l:
 cpx tmpF
 beq @nextrow
 bcs @g2
@nextrow:
 dec prow
 bmi @done
 jmp @row
@done:
 rts
@g2:
 txa
 sec
 sbc #6
 tax
 lda.l PTAB,x               ; across: one unsigned test
 sec
 sbc flx
 sta tmpC
 clc
 adc #VIS_X
 cmp #VIS_X*2
 bcs @l0
 lda.l PTAB+2,x             ; in depth
 sec
 sbc fly
 sta tmpD
 sec
 sbc #VIS_MIN
 cmp #VIS_MAX-VIS_MIN+1
 bcc @in0
@l0:
 jmp @l
@in0:
 ldy dpos                   ; something moving in front of it still to draw?
 cpy ndyn
 bcs @nofl
 lda tmpD
 clc
 adc #$4000
 cmp.w dyn_key,y
 beq @fl
 bcs @nofl
@fl:
 lda tmpC
 pha
 lda tmpD
 pha
 clc
 adc #$4000
 jsr FlushDyn
 pla
 sta tmpD
 pla
 sta tmpC
@nofl:
 lda oamn
 cmp #512
 bcc @g3
 rts
@g3:
 phx
 lda.l PTAB+4,x
 and #$00FF
 sta tmpG
 jsr Project
 bcs @skip
 lda tmpG
 cmp #BRAZIER_TYPE          ; the braziers' flames flicker
 bne @nb
 lda frame
 and #16
 beq @nb
 inc tmpG
@nb:
 jsr EmitProp
@skip:
 plx
 jmp @l

; EmitProp: tmpG = prop type, ps / pl = where its foot is on screen
EmitProp:
 .a16
 .i16
 lda tmpG
 asl
 tax
 lda prop_ofs,x
 tax
 lda.w $0000,x
 and #$00FF
 sta tmpB                   ; parts
 inx
@p:
 lda.w $0000,x              ; dx (signed byte)
 and #$00FF
 cmp #$0080
 bcc @dxp
 ora #$FF00
@dxp:
 clc
 adc ps
 sta tmp0
 lda.w $0001,x              ; dy
 and #$00FF
 cmp #$0080
 bcc @dyp
 ora #$FF00
@dyp:
 clc
 adc pl
 sta tmp1
 lda.w $0002,x
 and #$00FF
 sta tmp4                   ; 2: a 32x32 part
 lda.w $0004,x
 sta tmp3
 phx
 jsr EmitOne
 plx
 txa
 clc
 adc #6
 tax
 dec tmpB
 bne @p
 rts

; EmitActor: X = actor, ps / pl = its feet on screen
EmitActor:
 .a16
 .i16
 lda ps
 sec
 sbc #16
 sta tmp0
 lda pl
 sec
 sbc #31
 sta tmp1
 lda.w eflash,x             ; palette: the hero 0 (5 struck), ghoul 1 / skeleton 2 (champions 3 / 4)
 beq @nf
 cpx #0
 bne @nf
 lda #5
 bra @pal
@nf:
 lda #0
 cpx #0
 beq @pal
 lda.w ekind,x
 inc a
 ldy.w echamp,x
 beq @pal
 inc a
 inc a
@pal:
 asl
 ora #$20                   ; priority 2
 xba
 ora slot_tile,x
 sta tmp3
 lda #2
 sta tmp4                   ; large
EmitOne:
 lda tmp0
 clc
 adc #32
 cmp #288
 bcs @out
 lda tmp1
 clc
 adc #32
 cmp #256
 bcs @out
 ldy oamn
 cpy #512
 bcs @out
 lda tmp1
 and #$00FF
 xba
 sta tmp2
 lda tmp0
 and #$00FF
 ora tmp2
 sta.w oam,y
 lda tmp3
 sta.w oam+2,y
 lda oamn                   ; the high table: x bit 8 and the size, 2 bits a sprite
 and #$000C
 lsr
 tay
 lda tmp4
 beq @sm
 lda.w hi_large,y
@sm:
 sta tmp4
 lda tmp0
 and #$0100
 beq @x8
 lda.w hi_x8,y
 ora tmp4
 sta tmp4
@x8:
 lda tmp4
 beq @s
 lda oamn
 lsr4
 tay
 lda.w oam+512,y
 ora tmp4
 sta.w oam+512,y
@s:
 lda oamn
 clc
 adc #4
 sta oamn
@out:
 rts

; ---------------------------------------------------------------- tables and words
bit_tab:    .word 1, 2, 4, 8, 16, 32, 64, 128
hi_large:   .word 2, 8, 32, 128
hi_x8:      .word 1, 4, 16, 64
slot_tile:  .word $00, $04, $08, $0C, $40
slot_vram:  .word $6000, $6040, $6080, $60C0, $6400
dir_of:     .word $FFFF, 6, 2, $FFFF, 0, 7, 1, $FFFF, 4, 5, 3, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
arrow_tile: .word $86, $88, $8A, $8C, $8E, $A0, $A2, $A4
drop_tile:  .word $82, $80, $84

str_paused:      .byte "PAUSED", 0
str_died:        .byte "YOU HAVE DIED", 0
str_rise:        .byte "PRESS START TO RISE AGAIN", 0
str_empty:       .byte "EMPTY SLOT", 0
str_full:        .byte "FULL LIFE", 0
str_beltfull:    .byte "BELT FULL", 0
str_tome_read:   .byte "+1 STAT POINT", 0
str_pick_potion: .byte "A  PICK UP HEALING POTION", 0
str_pick_tome:   .byte "A  PICK UP TOME OF INSIGHT", 0
str_points:      .byte "STAT POINTS (SELECT)", 0
str_level:       .byte "LEVEL", 0
str_exp:         .byte "EXPERIENCE", 0
str_life:        .byte "LIFE", 0
str_strength:    .byte "STRENGTH", 0
str_defense:     .byte "DEFENSE", 0
str_damage:      .byte "DAMAGE", 0
str_gold:        .byte "GOLD", 0
str_kills:       .byte "KILLS", 0
str_points_left: .byte "STAT POINTS", 0

.include "data.inc"

; ---------------------------------------------------------------- header + vectors
.bank 0
.org $FFC0
.byte "ANAROCH SNES         "
.org $FFD5
.byte $20, $00, $09, $00, $01, $33, $00
.org $FFE4
.word Rti, Rti, Rti, Nmi, Rti, Rti
.org $FFF4
.word Rti, Rti, Rti, Nmi, Reset, Rti
