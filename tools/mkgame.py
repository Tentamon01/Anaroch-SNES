# makes src/game.asm (the remake's engine) from src/main.asm: same rules, new world, camera, streaming and layout
import re
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
s = open(os.path.join(ROOT, 'src', 'main.asm')).read()

def sub(old, new, count=1):
    global s
    assert old in s, old[:70]
    s = s.replace(old, new) if count == 0 else s.replace(old, new, count)

def block(start, end, new):
    global s
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + s[j:]

head_end = s.index('.macro lsr2')
s = '''; Anaroch SNES, the remake (step 1): the pre-rendered graveyard in a three-quarter view, with the N64 version's rules.
; Built from the first version's engine; world, camera, streaming and screen layout are new (tools/build_world.py).
; World positions stay in metres * 16 (the N64 collision grid); the screen shows them through the projection
; picture x = wx - wz/2 + PIC_KX, picture y = (wx + wz)/2 + PIC_KY. The screen: 208 lines between blank bars,
; BG1 the world (a ring of 33 x 27 tiles streamed from ROM), BG2 the HUD, sprites for the characters.
; Everything is sent to the video chip by an interrupt at line 216.

''' + s[head_end:]

sub('NACT = 5                     ; the hero + 4 monsters (main.c: 3 + lvl1 / 3 for the graveyard)\nARCHER_X = 6                 ; every third monster is a skeleton archer (ghouls[2] -> actor 3)\n',
    'NACT = 9                     ; the hero + 8 monsters\nRING_C = 33                  ; the streamed window, in tiles\nRING_R = 27\nQREC = 14                    ; a stream record: source, bank + size, tile address, map address, entry, glow address, entry\nSQ = $1000                   ; the stream queue (work RAM)\n')

# HUD palettes: only two now (white, gold), so the world gets six
s = s.replace('$0400|HUD_PRIO', '@W@').replace('$0800|HUD_PRIO', '@G@').replace('$0C00|HUD_PRIO', '@G@').replace('$1000|HUD_PRIO', '@W@')
s = s.replace('@W@', '$0000|HUD_PRIO').replace('@G@', '$0400|HUD_PRIO')

# RAM: nine actors; the old map buffers go; streaming variables
for name in ('ex','ey','edir','est','etm','ehp','emaxhp','estr','edef','elvl','ecool','ekind','echamp','ealert','elost','ecall','ehomex','ehomey','ewx','ewy','ewt','eflash','edealt','ecur','estk','ealt','eanimt'):
    s = re.sub(r'^%s:(\s*)\.res 10$' % name, r'%s:\1.res NACT*2' % name, s, flags=re.M)
sub('fontoff:  .res 2\n', '''fontoff:  .res 2
mptr:     .res 3
scol:     .res 2
srow:     .res 2
slotc:    .res 2
slotr:    .res 2
sq:       .res 2
swork:    .res 2
sleft:    .res 2
uplim:    .res 2
padraw:   .res 2
''')
sub('.ram $0400\noam:      .res 544\n.ram $0700\ncolbuf:   .res 128\nrowbuf:   .res 128\n', '.ram $0540\noam:      .res 544\n')

# the walk-behind blocks' memory, and a longer depth list
sub('dyn_key:  .res 48\ndyn_rx:   .res 48\ndyn_ref:  .res 48\n', '''.ram $1600
ocid:     .res 128
ocst:     .res 128
ol_y:     .res 32
ol_t:     .res 32
oq:       .res 24
dyn_key:  .res 96
dyn_rx:   .res 96
dyn_ref:  .res 96
''')

# ---------------------------------------------------------------- boot: the frame interrupt at line 216, bars by HDMA
sub(''' sep #$20
 .a8
 lda #$81
 sta $4200
 rep #$20
 .a16
 cli
 jmp MainLoop''', ''' sep #$20
 .a8
 stz $4370                  ; HDMA channel 7: the brightness, blank bars above and below
 stz $4371
 ldx #bars
 stx $4372
 stz $4374
 lda #216
 sta $4209
 stz $420A
 lda #$21                   ; the vertical interrupt and the pad's auto-read
 sta $4200
 rep #$20
 .a16
 lda #3
 sta uplim
 cli
 jmp MainLoop

bars: .byte 8, $80, 127, $0F, 81, $0F, 1, $80, 0''')

block('InitVideo:\n', '; n0 = source, n1 = bank, n2 = VRAM word address', '''InitVideo:
 .a16
 .i16
 sep #$20
 .a8
 lda #$01
 sta $2105              ; mode 1
 lda #$41
 sta $2107              ; BG1 map at $4000, 64x32
 lda #$48
 sta $2108              ; BG2 (the HUD) map at $4800, 32x32
 lda #$39
 sta $2109              ; BG3 (the glow) map at $3800, 64x32
 lda #$04
 sta $210C              ; BG3 tiles from $4000 (the glow's start at number 384 = $4C00)
 lda #$50
 sta $210B              ; BG1 tiles $0000, BG2 tiles $5000
 lda #$63
 sta $2101              ; sprites at $6000
 lda #$13
 sta $212C              ; BG1 + BG2 + sprites
 lda #$04
 sta $212D              ; BG3 on the second screen
 lda #$02
 sta $2130
 lda #$11
 sta $2131              ; which is added to BG1 and to the sprites of palettes 4-7
 lda #$E0
 sta $2132              ; (nothing added where it is empty)
 lda #$FF
 sta $2110
 sta $2110
 rep #$20
 .a16
 lda #$80
 sta n4
 lda #hud_tiles
 sta n0
 lda #^hud_tiles
 sta n1
 lda #$5000
 sta n2
 lda #HUD_TILES_BYTES
 sta n3
 jsr DmaV
 lda #obj_static
 sta n0
 lda #^obj_static
 sta n1
 lda #$6C00
 sta n2
 lda #2048
 sta n3
 jsr DmaV
 lda #hud_pals          ; BG palettes 0 and 1: the HUD in white and in gold; 2-7: the world
 sta n0
 stz n1
 stz n2
 lda #32
 sta n3
 jsr DmaC
 lda #hud_pals+32
 sta n0
 lda #16
 sta n2
 jsr DmaC
 lda #world_pals
 sta n0
 lda #32
 sta n2
 lda #192
 sta n3
 jsr DmaC
 lda #obj_pals
 sta n0
 lda #128
 sta n2
 lda #256
 sta n3
 jsr DmaC
 lda #occ_pal           ; sprite palette 6: the walk-behind blocks
 sta n0
 lda #224
 sta n2
 lda #32
 sta n3
 jsr DmaC
 lda #glow_pal          ; colours 21-23: BG3's palette 5 (unused by the gold text)
 sta n0
 lda #21
 sta n2
 lda #6
 sta n3
 jsr DmaC
 lda #wglow_tiles
 sta n0
 lda #^wglow_tiles
 sta n1
 lda #$4C00
 sta n2
 lda #GLOW_BYTES
 sta n3
 lda #$80
 sta n4
 jsr DmaV
 rts

''')
i = s.index('.if MODE7\n; HDMA: channels 1-4') if '.if MODE7\n; HDMA: channels 1-4' in s else -1
if i >= 0:
    j = s.index('.endif', i) + len('.endif\n')
    s = s[:i] + s[j:]

# ---------------------------------------------------------------- the frame interrupt
block('Nmi:\n', 'Rti:\n', '''Frame:
 rep #$30
 .a16
 .i16
 pha
 phx
 phy
 sep #$20
 .a8
 lda $4211
 lda #$80
 sta $2100              ; blank until the HDMA lights line 8 again
 rep #$20
 .a16
 lda $4218              ; the pad, as read at the last vertical blank
 sta padraw
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
 ldy #$8001
 jsr FlushQueue         ; new world tiles first: they must be there when shown
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
 jsr OccUpload
 lda #4                 ; HUD rows that changed (at most 4 a frame)
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
 adc #$4800
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
 lda camx
 sta $2111
 lda camx+1
 sta $2111
 lda camy
 sta $2112
 lda camy+1
 sta $2112
 lda #$80
 sta $420C              ; the bars' HDMA from the next frame
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

; sends the queued stream records: each a tile's 32 bytes into its ring slot, its map entry and the glow's entry.
; Y = $0001, or $8001 to leave the bars' HDMA on (the word also writes $420C)
FlushQueue:
 .a16
 .i16
 lda sq
 bne @some
 rts
@some:
 sep #$20
 .a8
 lda #$80
 sta $2115
 rep #$20
 .a16
 lda #$1801
 sta $4300
 stz $4305
 ldx #0
@l:
 lda.w SQ+4,x
 sta $2116
 lda.w SQ,x
 sta $4302
 lda.w SQ+2,x
 sta $4304              ; the bank, and 32 bytes
 sty $420B
 lda.w SQ+6,x
 sta $2116
 lda.w SQ+8,x
 sta $2118
 lda.w SQ+10,x
 sta $2116
 lda.w SQ+12,x
 sta $2118
 txa
 clc
 adc #QREC
 tax
 cpx sq
 bne @l
 stz sq
 rts

''')

# how long the interrupt takes, in lines from 216 (over 54 it would still be sending when the picture starts)
sub(''' lda #1
 sta vbl
@out:''', ''' sep #$20
 .a8
 lda $2137
 lda $213F
 lda $213D
 sta n6
 lda $213D
 and #1
 sta n6+1
 rep #$20
 .a16
 lda n6
 sec
 sbc #216
 bpl @ln
 clc
 adc #262
@ln:
 cmp irqmax
 bcc @lm
 sta irqmax
@lm:
 lda #1
 sta vbl
@out:''')

# ---------------------------------------------------------------- the main loop reads the interrupt's pad
sub(''' lda $4218
 sta pad
 eor padold''', ''' lda padraw
 sta pad
 eor padold''')

sub(''' cli
 jmp MainLoop''', ''' sep #$20
 .a8
 lda #1
 sta $420D                  ; fast ROM
 rep #$20
 .a16
 cli
 jml $800000+RunFast
RunFast:
 phk
 plb
 jmp MainLoop''')
sub('''Frame:
 rep #$30''', '''Frame:
 jml $800000+FrameFast
FrameFast:
 rep #$30''')
# the collision grid's cell, without the long way to row * 72
i = s.index('\nCellType:\n'); j = s.index('\n; Blocked:', i)
s = s[:i] + '''
CellType:
 .a16
 .i16
 lda tmp6
 cmp #72*16
 bcs @out
 lda tmp7
 cmp #72*16
 bcs @out
 and #$FFF0                 ; row * 16 -> row * 72
 lsr
 sta ct2
 asl
 asl
 asl
 clc
 adc ct2
 sta ct2
 lda tmp6
 lsr4
 clc
 adc ct2
 phx
 tax
 lda.l coll,x
 plx
 and #$00FF
 rts
@out:
 lda #2
 rts
''' + s[j:]

# ---------------------------------------------------------------- the world: streaming, camera
block('TileEntry:\n', '; ---------------------------------------------------------------- collision and sight', '''; AddTile: world tile (scol, srow), its ring slot (slotc, slotr) -> one record on the queue
AddTile:
 .a16
 .i16
 stz swork
 stz sglow
 lda scol
 cmp #MAP_W
 bcs @out
 lda srow
 cmp #MAP_H
 bcs @out
 asl
 clc
 adc srow
 tax                        ; row * 3: its address
 lda.l rowptr,x
 sta mptr
 sep #$20
 .a8
 lda.l rowptr+2,x
 sta mptr+2
 rep #$20
 .a16
 lda scol
 asl
 tay
 lda [mptr],y
 sta swork
 lda.l glowptr,x
 sta gmp
 sep #$20
 .a8
 lda.l glowptr+2,x
 sta gmp+2
 rep #$20
 .a16
 ldy scol
 lda [gmp],y
 and #$00FF
 sta sglow
@out:
 ldx sq
 lda swork                  ; the tile's picture: 1024 to a bank
 and #$03FF
 asl
 asl
 asl
 asl
 asl
 ora #$8000
 sta.w SQ,x
 lda swork
 and #$1FFF
 xba
 lsr
 lsr
 and #$0007
 clc
 adc #TILE_BANK
 ora #$2000
 sta.w SQ+2,x
 lda slotc                  ; slot = column slot * 27 + row slot
 asl
 tay
 lda.w ring_base,y
 clc
 adc slotr
 sta tmpG
 asl
 asl
 asl
 asl
 sta.w SQ+4,x               ; its characters (16 words a tile, at $0000)
 lda srow                   ; the map cell: row & 31, column & 63 (the second 32 columns in the next screen)
 and #$001F
 asl
 asl
 asl
 asl
 asl
 sta tmpF
 lda scol
 and #$001F
 clc
 adc tmpF
 sta tmpF
 lda scol
 and #$0020
 beq @low
 lda tmpF
 clc
 adc #$0400
 sta tmpF
@low:
 lda tmpF
 clc
 adc #$4000
 sta.w SQ+6,x
 sec
 sbc #$0800
 sta.w SQ+10,x
 lda sglow                  ; the glow's tile: number 384 on, palette 5
 clc
 adc #$1400+384
 sta.w SQ+12,x
 lda swork                  ; the entry: the slot, and the tile's palette (world palettes 2-7)
 xba
 lsr
 lsr
 lsr
 lsr
 lsr
 and #$0007
 clc
 adc #2
 xba
 asl
 asl
 ora tmpG
 sta.w SQ+8,x
 txa
 clc
 adc #QREC
 sta sq
 rts

ring_base: .word 0, 27, 54, 81, 108, 135, 162, 189, 216, 243, 270, 297, 324, 351, 378, 405, 432, 459, 486, 513, 540, 567, 594, 621, 648, 675, 702, 729, 756, 783, 810, 837, 864

; QueueColumn: A = world column (rows camr0 .. camr0 + 26)
QueueColumn:
 .a16
 .i16
 sta scol
 pha
 lda #RING_C
 sta tmp7
 pla
 jsr Div
 lda tmp6
 sta slotc
 lda #RING_R
 sta tmp7
 lda camr0
 jsr Div
 lda tmp6
 sta slotr
 lda camr0
 sta srow
 lda #RING_R
 sta sleft
@l:
 jsr AddTile
 inc srow
 inc slotr
 lda slotr
 cmp #RING_R
 bne @n
 stz slotr
@n:
 dec sleft
 bne @l
 rts

; QueueRow: A = world row (columns camc0 .. camc0 + 32)
QueueRow:
 .a16
 .i16
 sta srow
 pha
 lda #RING_R
 sta tmp7
 pla
 jsr Div
 lda tmp6
 sta slotr
 lda #RING_C
 sta tmp7
 lda camc0
 jsr Div
 lda tmp6
 sta slotc
 lda camc0
 sta scol
 lda #RING_C
 sta sleft
@l:
 jsr AddTile
 inc scol
 inc slotc
 lda slotc
 cmp #RING_C
 bne @n
 stz slotc
@n:
 dec sleft
 bne @l
 rts

; the whole window for the current camera, during forced blank
FullMap:
 .a16
 .i16
 sep #$20
 .a8
 stz $420C                  ; (the bars' HDMA would light the screen)
 lda #$80
 sta $2100
 rep #$20
 .a16
 stz sq
 lda camx
 lsr3
 sta camc0
 lda camy
 lsr3
 inc a
 sta camr0
 lda camc0
 sta us3
 clc
 adc #RING_C
 sta us4
@col:
 lda us3
 jsr QueueColumn
 ldy #$0001
 jsr FlushQueue
 inc us3
 lda us3
 cmp us4
 bne @col
 rts

; a new column and / or row when the camera crosses a tile; more than one tile (a jump) redraws everything
UpdateStream:
 .a16
 .i16
 lda #3
 sta uplim
 lda #4
 sta olim
 lda camx
 lsr3
 sta us0
 lda camy
 lsr3
 inc a
 sta us1
 lda us0
 sec
 sbc camc0
 inc a
 cmp #3
 bcs @jump
 lda us1
 sec
 sbc camr0
 inc a
 cmp #3
 bcs @jump
 lda us0                    ; a column and a row at once would be too much for one frame: the row waits
 cmp camc0
 beq @single
 lda us1
 cmp camr0
 beq @single
 lda camr0
 dec a
 asl
 asl
 asl
 sta us2
 lda us1
 cmp camr0
 bcc @held
 lda us2
 ora #7
 sta us2
@held:
 lda us2
 sta camy                   ; (the camera stays a pixel short for that frame)
 lda camr0
 sta us1
@single:
 lda camc0
 sta us2
 lda camr0
 sta us3
 lda us0
 sta camc0
 lda us1
 sta camr0
 lda us0
 cmp us2
 beq @row
 bcs @right
 lda us0
 bra @col
@right:
 lda us0
 clc
 adc #RING_C-1
@col:
 jsr QueueColumn
@row:
 lda us1
 cmp us3
 beq @limit
 bcs @down
 lda us1
 bra @r
@down:
 lda us1
 clc
 adc #RING_R-1
@r:
 jsr QueueRow
@limit:
 lda sq                     ; new tiles this frame: fewer new sprite pictures
 beq @done
 lda #2
 sta uplim
 sta olim
@done:
 rts
@jump:
 jmp FullMap

; the camera on the hero, in picture pixels, kept inside the picture
UpdateCam:
 .a16
 .i16
 lda.w ey
 lsr4
 sta tmp1
 lsr
 sta tmp2
 lda.w ex
 lsr4
 sta tmp0
 sec
 sbc tmp2
 clc
 adc #PIC_KX-128
 bpl @a
 lda #0
@a:
 cmp #PIC_W-256
 bcc @b
 lda #PIC_W-256
@b:
 sta camx
 lda tmp0
 clc
 adc tmp1
 lsr
 clc
 adc #PIC_KY-112
 bpl @c
 lda #0
@c:
 cmp #PIC_H-224
 bcc @d
 lda #PIC_H-224
@d:
 sta camy
 rts

''')

# ---------------------------------------------------------------- the projection for everything that moves
block('; Rot: tmp0 / tmp2', '; CalcDamage', '''; Rot: tmp0 / tmp2 = a world vector (or place) -> as seen on screen: x = wx - wz/2, y = (wx + wz)/2
Rot:
 .a16
 lda tmp2
 cmp #$8000
 ror
 sta rt0
 lda tmp0
 clc
 adc tmp2
 cmp #$8000
 ror
 sta rt1
 lda tmp0
 sec
 sbc rt0
 sta tmp0
 lda rt1
 sta tmp2
 rts

''') if '; Rot: tmp0 / tmp2' in s else None
if 'sta rt1\n lda tmp0\n sec\n sbc rt0' not in s:
    i = s.index('\nRot:\n'); j = s.index('; CalcDamage', i)
    s = s[:i] + '''
Rot:
 .a16
 lda tmp2
 cmp #$8000
 ror
 sta rt0
 lda tmp0
 clc
 adc tmp2
 cmp #$8000
 ror
 sta rt1
 lda tmp0
 sec
 sbc rt0
 sta tmp0
 lda rt1
 sta tmp2
 rts

''' + s[j:]

# movement speeds are world velocities for screen directions
s = s.replace('spd_', 'wspd_')

# monsters: archers at 3 and 6
sub(''' lda #1
 ldx #ARCHER_X
 sta.w ekind,x''', ''' lda #1
 ldx #6
 sta.w ekind,x
 ldx #12
 sta.w ekind,x''')

# sprite pictures: at most uplim a frame
sub(''' lda nq
 cmp #5
 bcs @done''', ''' lda nq
 cmp uplim
 bcs @done''')

sub(''' txa
 jsr AddDyn
@an:''', ''' txa
 jsr AddDyn
 jsr Occlude
@an:''')
sub(''' ldy ndyn
@ins:''', '''AddDynRaw:                  ; (tmp0 = x, tmp2 = key, tmp9 = what)
 ldy ndyn
@ins:''')
sub(''' stz ndyn                   ; the things''', ''' stz ol_n
 stz ndyn                   ; the things''')
sub(''' cmp #1
 beq @arrow
 lda tmpB                   ; loot''', ''' cmp #1
 beq @arrow
 cmp #3
 bne @loot
 lda tmpB                   ; a walk-behind block
 and #$00FF
 tax
 lda.w ol_y,x
 sta tmp1
 lda.w ol_t,x
 sta tmp3
 lda ps
 sta tmp0
 stz tmp4
 jsr EmitOne
 jmp @l
@loot:
 lda tmpB                   ; loot''')

# sound: upload at boot, one request a frame, and the moments that make a noise
sub(' jsr InitVideo\n', ' jsr InitVideo\n jsr UploadSound\n')
sub(' jsr QueueUploads\n lda #1\n sta ready', ' jsr QueueUploads\n jsr SfxSend\n lda #1\n sta ready')
def noise(before, effect, after=''):
    sub(before + after, before + ' lda #%s\n jsr Sfx\n' % effect + after)
sub(' stz.w edealt\n rts\n@move:', ' stz.w edealt\n lda #SFX_SWING\n jmp Sfx\n@move:')
noise('@drink:\n', 'SFX_DRINK', ' lda beltsel')
sub('@alive:\n lda.w ehp,x\n sec\n sbc hdmg', '@alive:\n lda #SFX_HIT\n cpx #0\n bne @snd\n lda #SFX_HURT\n@snd:\n jsr Sfx\n lda.w ehp,x\n sec\n sbc hdmg')
sub(' lda.w ehp,x\n bne @live\n lda #ST_DEAD', ' lda.w ehp,x\n bne @live\n lda #SFX_MDIE\n cpx #0\n bne @snd2\n lda #SFX_DIE\n@snd2:\n jsr Sfx\n lda #ST_DEAD')
noise('@d:\n sta tmp7                   ; 2.75 m/s: 12/16 px a frame along the line to the hero\n', 'SFX_BOW')
noise('@put:\n', 'SFX_PICK', ' lda #1\n sta.w belt,y')
noise('@tome:\n', 'SFX_PICK', ' stz.w dtyp,x')
noise(' bcs @n\n', 'SFX_COIN', ' lda gold\n')
noise(' lda tmp9\n beq @r\n', 'SFX_LEVEL', ' phx\n jsr RecalcStats')

# each pose's picture sits where its figure is (build_assets.py --placed), some with a 16x16 piece more.
# The pictures are chosen before the sprite list is made, so both show the same pose.
sub(' jsr BuildOam\n jsr QueueUploads\n', ' jsr QueueUploads\n jsr BuildOam\n')
sub(' stz nq\n ldx #0\n@l:\n lda nq\n cmp uplim', ' stz nq\n stz oq_n\n ldx #0\n@l:\n lda nq\n cmp uplim')
sub(''' lda.w slot_vram,x
 sta.w qbuf+4,y
 inc nq
 rts''', ''' lda.w slot_vram,x
 sta.w qbuf+4,y
 inc nq
 jsr MetaAt                 ; the extra piece follows the square's 512 bytes
 lda.l fmeta+2,x
 plx
 and #$00FF
 cmp #$0080
 beq @none
 lda oq_n
 asl
 sta tmp5
 asl
 clc
 adc tmp5
 tay
 lda tmp3
 clc
 adc #512
 sta.w oq,y
 lda tmp4
 sta.w oq+2,y
 lda.w ex_vram,x
 sta.w oq+4,y
 inc oq_n
@none:
 rts''')
sub('QueueUploads:\n', '''; MetaAt: X = actor -> X = its picture's place in fmeta (the actor is left on the stack)
MetaAt:
 .a16
 .i16
 lda.w ekind,x
 asl
 tay
 lda.w ecur,x
 asl
 asl
 clc
 adc.w meta_base,y
 ply                        ; (the return address)
 phx
 phy
 tax
 rts

; a byte (low half of A) with its sign
Signed:
 .a16
 and #$00FF
 cmp #$0080
 bcc @r
 ora #$FF00
@r:
 rts

QueueUploads:
''')
block('; EmitActor: X = actor', 'EmitOne:\n', '''; EmitActor: X = actor, ps / pl = its feet on screen
EmitActor:
 .a16
 .i16
 lda.w ecur,x
 cmp #FRAMES*8
 bcc @have
 rts                        ; no picture of it in video memory yet
@have:
 jsr MetaAt
 lda.l fmeta,x
 sta tmp5                   ; the square's shift
 lda.l fmeta+2,x
 sta tmp6                   ; the extra piece's
 plx
 lda tmp5
 jsr Signed
 clc
 adc ps
 sec
 sbc #16
 sta tmp0
 lda tmp5
 xba
 jsr Signed
 clc
 adc pl
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
 jsr EmitOne
 lda tmp6
 and #$00FF
 cmp #$0080
 bne @extra
 rts
@extra:
 lda tmp3
 and #$FF00
 ora.w ex_tile,x
 sta tmp3
 lda tmp6
 jsr Signed
 clc
 adc ps
 sec
 sbc #16
 sta tmp0
 lda tmp6
 xba
 jsr Signed
 clc
 adc pl
 sec
 sbc #31
 sta tmp1
 stz tmp4                   ; small
''')
sub('slot_tile:  .word', '''ex_tile:    .word $84, $86, $88, $8A, $8C, $8E, $A4, $A6, $A8
ex_vram:    .word $6840, $6860, $6880, $68A0, $68C0, $68E0, $6A40, $6A60, $6A80
slot_tile:  .word''')

# the sprites' focus is the middle of the screen; no loose scenery (it is part of the world now)
sub(''' lda fx                     ; the focus, seen from the camera
 sta tmp0
 lda fy
 sta tmp2
 jsr Rot
 lda tmp0
 sta flx
 lda tmp2
 sta fly''', ''' lda camx                   ; the middle of the screen in picture space less the projection's offset
 clc
 adc #128-PIC_KX
 sta flx
 lda camy
 clc
 adc #112-PIC_KY
 sta fly''')
block('; EmitProps: the graves', '; EmitActor: X = actor', '''; (the scenery is part of the world picture now)
EmitProps:
 rts

''')

# tables: nine actor slots; the small pictures moved to tiles $C0-$FF
sub('slot_tile:  .word $00, $04, $08, $0C, $40\nslot_vram:  .word $6000, $6040, $6080, $60C0, $6400',
    'slot_tile:  .word $00, $04, $08, $0C, $40, $44, $48, $4C, $80\nslot_vram:  .word $6000, $6040, $6080, $60C0, $6400, $6440, $6480, $64C0, $6800')
sub('arrow_tile: .word $86, $88, $8A, $8C, $8E, $A0, $A2, $A4\ndrop_tile:  .word $82, $80, $84',
    'arrow_tile: .word $C6, $C8, $CA, $CC, $CE, $E0, $E2, $E4\ndrop_tile:  .word $C2, $C0, $C4')

# the HUD a row higher: the screen shows rows 1-25 whole
sub('VIAL_ROW = 20\nBELT_ROW = 25', 'VIAL_ROW = 19\nBELT_ROW = 23')
sub(' lda #22\n jsr ClearRow', ' lda #20\n jsr ClearRow')
sub(' lda #24                    ; unspent stat points', ' lda #22                    ; unspent stat points')
sub(' ldx #(24*32+6)*2', ' ldx #(22*32+6)*2')
i = s.index('\nShowPrompt:\n'); j = s.index('; ----', i)
s = s[:i] + s[i:j].replace(' lda #23\n', ' lda #21\n') + s[j:]
sub(' lda #22\n ldy #$0400|HUD_PRIO', ' lda #20\n ldy #$0400|HUD_PRIO')
# frames the logic did not finish in time (for testing: shown in the character window)
sub('padraw:   .res 2\n', 'padraw:   .res 2\nlagc:     .res 2\n' + ''.join('%-10s.res 2\n' % (v + ':') for v in 'sfxreq sfxseq opx irqmax olim ol_n oq_n okey obx obx0 obx1 oby oby1 orow oid ocnt sglow'.split()) + 'gmp:      .res 4\n')
sub(' lda ready\n bne @go\n jmp @out', ' lda ready\n bne @go\n inc lagc\n jmp @out')
sub('jsr FullMap\n bra @oam', 'jsr FullMap\n stz lagc\n bra @oam')
sub(' ldy #0                     ; the cursor', ' lda #17*32+6\n ldx #str_lag\n ldy #$0000|HUD_PRIO\n jsr PrintAt\n lda #$0000|HUD_PRIO\n sta attr\n ldx #(17*32+18)*2\n lda lagc\n jsr PrintNum\n lda #17*32+21\n ldx #str_busy\n ldy #$0000+HUD_PRIO\n jsr PrintAt\n lda #$0000+HUD_PRIO\n sta attr\n ldx #(17*32+26)*2\n lda irqmax\n jsr PrintNum\n ldy #0                     ; the cursor')
sub('str_points_left: .byte', 'str_lag:         .byte "SLOWDOWNS", 0\nstr_busy:        .byte "BUSY", 0\nstr_points_left: .byte')
s = s.replace('cpx #(18*32)*2', 'cpx #(19*32)*2').replace(' cpx #18\n bne @m', ' cpx #19\n bne @m').replace(' cpy #18\n bne @clr', ' cpy #19\n bne @clr')
# the N64 sheets turn the other way (0 faces the viewer, then toward the right): left and right were swapped
sub('FidGo:\n sta tmp0\n lda.w edir,x\n asl4\n sec\n sbc.w edir,x', 'FidGo:\n sta tmp0\n lda #8\n sec\n sbc.w edir,x\n and #7\n sta tmp1\n asl4\n sec\n sbc tmp1')
sub('.include "data.inc"', '.include "occlude.asm"\n.include "sound.asm"\n.include "data.inc"\n.include "world.inc"\n.bank 40\n.org $8000\nspc_data: .incbin "../out/audio/spc_0.bin"\n.bank 41\n.org $8000\n .incbin "../out/audio/spc_1.bin"')
sub('.byte $20, $00, $09, $00, $01, $33, $00', '.byte $30, $15, $0B, $07, $01, $33, $00')
sub('.word Rti, Rti, Rti, Nmi, Rti, Rti', '.word Rti, Rti, Rti, Rti, Rti, Frame')
sub('.word Rti, Rti, Rti, Nmi, Reset, Rti', '.word Rti, Rti, Rti, Rti, Reset, Rti')
open(os.path.join(ROOT, 'src', 'game.asm'), 'w').write(s)
print('ok', len(s.splitlines()), 'lines')
