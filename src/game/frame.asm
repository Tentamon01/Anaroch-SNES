; ---------------------------------------------------------------- NMI: everything for the PPU, in vblank
Frame:
 jml $800000+FrameFast
FrameFast:
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
 inc lagc
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
 lda inMenu
 beq @world
 jsr MenuFrame
 jmp @timed
@world:
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
@timed:
 sep #$20
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

Rti:
 rti

WaitVbl:
 .a16
@w:
 lda vbl
 beq @w
 stz vbl
 rts
