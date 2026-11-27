; The studio's splash (tools/build_splash.py draws it from the N64 version's scene). Played at boot: 20 pictures a
; second, each built in a back buffer over two blanks and shown at the third with its colours, the window that
; uncovers the mark, and its sound. A or Start passes it by.
SPLASH_MAP = $7E6000         ; a picture's map, built here
.ram $1D00
spk:      .res 2             ; the picture
spback:   .res 2             ; the buffer being filled: 0 or 1
spcount:  .res 2             ; the picture's tiles
spbytes:  .res 2             ; their size
spsrc:    .res 2             ; for a copy to video memory: address, bank, bytes
spbank:   .res 2
splen:    .res 2
spold:    .res 2             ; the buttons last time
.bank 43
.org $8000

SplashPlay:                  ; (jsl; A, X, Y 16-bit; the screen and everything on it is set up here)
 .a16
 .i16
 sep #$20
 .a8
 lda #$80
 sta $2100
 lda #$01
 sta $2105
 lda #$38
 sta $2107                  ; BG1 map at $3800
 lda #$30
 sta $2108                  ; BG2 (the floor) map at $3000
 lda #$40
 sta $210B                  ; BG1 tiles $0000, BG2 tiles $4000
 lda #$60
 sta $2101                  ; sprites (the mark) from $0000, their tiles at $0C00
 lda #$13
 sta $212C
 stz $212D
 stz $2130
 stz $2131
 stz $2123
 stz $2124
 lda #$02
 sta $2125                  ; the sprites have window 1 ...
 lda #$10
 sta $212E                  ; ... which hides them on the screen
 stz $2126
 lda #$FF
 sta $2127                  ; (all of them, for now)
 stz $212A
 stz $212B
 stz $210D
 stz $210D
 stz $210F
 stz $210F
 lda #$F8                   ; the picture's first row on screen line 8
 sta $210E
 lda #$03
 sta $210E
 lda #$F8
 sta $2110
 lda #$03
 sta $2110
 stz $2121                  ; black until the first picture
 ldx #512
@black:
 stz $2122
 dex
 bne @black
 lda #$01
 sta $4200                  ; the buttons read by themselves
 rep #$20
 .a16
 stz spk
 lda #1
 sta spback
 lda #$FFFF
 sta spold
 ; the still things: the floor, its map, the mark and where its sprites stand
 lda #splash_floor & $FFFF
 ldx #^splash_floor
 ldy #SPLASH_FLOOR_BYTES
 jsr SplashFrom
 lda #$4000
 jsr SplashVram
 lda #splash_map & $FFFF
 ldx #^splash_map
 ldy #2048
 jsr SplashFrom
 lda #$3000
 jsr SplashVram
 lda #splash_logo & $FFFF
 ldx #^splash_logo
 ldy #320 * 32
 jsr SplashFrom
 lda #$0C00
 jsr SplashVram
 ldx #2046                  ; both buffers' maps empty, their first tile blank
 lda #0
@m0:
 sta.l SPLASH_MAP,x
 dex
 dex
 bpl @m0
 lda #SPLASH_MAP & $FFFF
 ldx #^SPLASH_MAP
 ldy #2048
 jsr SplashFrom
 lda #$3800
 jsr SplashVram
 lda #$3C00
 jsr SplashVram
 lda #SPLASH_MAP & $FFFF
 ldx #^SPLASH_MAP
 ldy #32
 jsr SplashFrom
 lda #$0000
 jsr SplashVram
 lda #$2000
 jsr SplashVram
 sep #$20
 .a8
 stz $2102
 stz $2103
 stz $4300
 lda #4
 sta $4301
 ldx #splash_oam & $FFFF
 stx $4302
 lda #^splash_oam
 sta $4304
 ldx #544
 stx $4305
 lda #1
 sta $420B
 lda #$0F
 sta $2100                  ; light
 rep #$20
 .a16

@picture:
 jsr SplashBuild            ; its map in work memory, mptr at its tiles
 jsr SplashBlank            ; first blank: most of the tiles
 lda mptr
 sta spsrc
 lda mptr+2
 and #$00FF
 sta spbank
 lda spbytes
 cmp #4097
 bcc @a
 lda #4096
@a:
 sta splen
 lda spback
 xba
 asl
 asl
 asl
 asl
 asl                        ; $0000 or $2000
 clc
 adc #16                    ; past the blank tile
 jsr SplashVram
 jsr SplashPad
 bcc @on
 jmp @end
@on:
 jsr SplashBlank            ; second blank: the rest, and the map
 lda spbytes
 sec
 sbc #4096
 bcc @b
 beq @b
 sta splen
 lda spsrc
 clc
 adc #4096
 sta spsrc
 lda spback
 xba
 asl
 asl
 asl
 asl
 asl
 clc
 adc #16 + 2048
 jsr SplashVram
@b:
 lda #SPLASH_MAP & $FFFF
 ldx #^SPLASH_MAP
 ldy #2048
 jsr SplashFrom
 lda spback
 xba
 asl
 asl
 clc
 adc #$3800
 jsr SplashVram
 jsr SplashBlank            ; third blank: show it
 jsr SplashShow
 lda spback
 eor #1
 sta spback
 inc spk
 lda spk
 cmp #SPLASH_FRAMES
 bcs @end
 jmp @picture
@end:
 sep #$20
 .a8
 lda #$80
 sta $2100
 stz $212E
 stz $2125
 lda #$FE
 jsr SplashSound            ; the music starts
 rep #$20
 .a16
 rtl

; A = address, X = bank, Y = bytes: what SplashVram copies next
SplashFrom:
 .a16
 .i16
 sta spsrc
 stx spbank
 sty splen
 rts

; A = the video memory address (a word address)
SplashVram:
 .a16
 .i16
 pha
 sep #$20
 .a8
 lda #$80
 sta $2115
 rep #$20
 .a16
 pla
 sta $2116
 lda #$1801
 sta $4300
 lda spsrc
 sta $4302
 sep #$20
 .a8
 lda spbank
 sta $4304
 rep #$20
 .a16
 lda splen
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

; picture spk: its map into SPLASH_MAP; mptr -> its tiles, spbytes their size
SplashBuild:
 .a16
 .i16
 ldx #2046
 lda #0
@c:
 sta.l SPLASH_MAP,x
 dex
 dex
 bpl @c
 lda spk
 asl
 asl
 asl
 tax
 lda.l splash_head,x
 sta mptr
 sep #$20
 .a8
 lda.l splash_head+2,x
 sta mptr+2
 rep #$20
 .a16
 lda.l splash_head+4,x
 sta spcount
 asl4
 asl
 sta spbytes
 ldy #0
 stz tmp0                   ; the tile (from 1)
@m:
 lda tmp0
 cmp spcount
 bcs @done
 inc tmp0
 lda [mptr],y
 sta tmp1
 and #$03FF
 asl
 tax
 lda tmp1
 and #$1C00
 ora tmp0
 ora #$2000                 ; (over the mark's sprites)
 sta.l SPLASH_MAP,x
 iny
 iny
 bra @m
@done:
 lda spcount                ; the tiles follow the cells
 asl
 clc
 adc mptr
 sta mptr
 rts

; waits for the start of the next blank
SplashBlank:
 .a16
 sep #$20
 .a8
@in:
 lda $4212
 bmi @in
@out:
 lda $4212
 bpl @out
 rep #$20
 .a16
 rts

; carry set: A or Start was pressed (after the first moment)
SplashPad:
 .a16
 sep #$20
 .a8
@busy:
 lda $4212
 and #1
 bne @busy
 rep #$20
 .a16
 lda spold
 eor #$FFFF
 and $4218
 sta tmp0
 lda $4218
 sta spold
 lda spk
 cmp #12
 bcc @no
 lda tmp0
 and #PAD_A | PAD_START
 beq @no
 sec
 rts
@no:
 clc
 rts

; in the blank: the new map and tiles, the picture's colours, the window, the sound
SplashShow:
 .a16
 .i16
 sep #$20
 .a8
 lda spback
 beq @a
 lda #$3C
 sta $2107
 lda #$42
 sta $210B
 bra @pal
@a:
 lda #$38
 sta $2107
 lda #$40
 sta $210B
@pal:
 rep #$20
 .a16
 lda spk                    ; k * 224 = k * 256 - k * 32
 cmp #SPLASH_PALS_PER_BANK
 bcc @first
 sec
 sbc #SPLASH_PALS_PER_BANK
 jsr SplashPalAt
 clc
 adc #splash_pals2 & $FFFF
 ldx #^splash_pals2
 bra @have
@first:
 jsr SplashPalAt
 clc
 adc #splash_pals & $FFFF
 ldx #^splash_pals
@have:
 sta $4302
 sep #$20
 .a8
 stx $4304                  ; (the bank; its upper byte goes to the size, set next)
 stz $2121
 rep #$20
 .a16
 lda #$2200
 sta $4300
 lda #192                   ; colours 0..95: the scene
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 lda #128                   ; and 128..143: the mark
 sta $2121
 ldx #32
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
 lda spk                    ; the window: sprites hidden left of this column
 asl
 asl
 tax
 lda.l splash_meta,x
 sta tmp0
 sep #$20
 .a8
 lda tmp0+1
 bne @allhidden
 lda tmp0
 beq @shown
 dec a
 sta $2127
 stz $2126
 bra @snd
@shown:
 lda #1                     ; (an empty window)
 sta $2126
 stz $2127
 bra @snd
@allhidden:
 stz $2126
 lda #$FF
 sta $2127
@snd:
 lda.l splash_meta+2,x
 beq @r
 rep #$20
 .a16
 and #$00FF
 tax
 sep #$20
 .a8
 lda.l splash_sfx-1,x
 jsr SplashSound
@r:
 rep #$20
 .a16
 rts

SplashPalAt:                 ; A = a picture -> A = A * 224
 .a16
 xba
 and #$FF00
 sta tmp1
 lsr
 lsr
 lsr
 sta tmp2
 lda tmp1
 sec
 sbc tmp2
 rts

; A = a request for the sound chip (8-bit)
SplashSound:
 .a8
 sta $2141
 lda sfxseq
 inc a
 sta sfxseq
 sta $2142
 rts
splash_sfx: .byte SFX_GROWL, SFX_HURT, SFX_SCREAM, SFX_HIT
