; The sound: the driver, music and effects go to the sound chip at boot (tools/build_audio.mjs); the game then asks
; for effects by number. A higher number wins when two are asked for in the same frame.
SFX_SWING = 1
SFX_COIN = 2
SFX_BOW = 3
SFX_PICK = 4
SFX_HIT = 5
SFX_DRINK = 6
SFX_HURT = 7
SFX_MDIE = 8
SFX_LEVEL = 9
SFX_DIE = 10

; Sfx: A = effect. X and Y kept
Sfx:
 .a16
 cmp sfxreq
 bcc @r
 sta sfxreq
@r:
 rts

; once a frame: the request goes to the sound chip (port 1 the effect, port 2 a new count)
SfxSend:
 .a16
 lda sfxreq
 beq @r
 sep #$20
 .a8
 sta $2141
 lda sfxseq
 inc a
 sta sfxseq
 sta $2142
 rep #$20
 .a16
 stz sfxreq
@r:
 rts

; the boot loader's upload (to $0200, start at SPC_ENTRY)
UploadSound:
 .a16
 .i16
 lda #spc_data
 sta mptr
 sep #$20
 .a8
 lda #^spc_data
 sta mptr+2
 rep #$20
 .a16
@ready:
 lda $2140
 cmp #$BBAA
 bne @ready
 lda #$0200
 sta $2142
 sep #$20
 .a8
 lda #1
 sta $2141
 lda #$CC
 sta $2140
@w0:
 cmp $2140
 bne @w0
 ldx #0
 ldy #0
@byte:
 lda [mptr],y
 sta $2141
 txa
 sta $2140
@w1:
 cmp $2140
 bne @w1
 iny
 cpy #$8000
 bne @same
 ldy #0
 inc mptr+2                 ; (the next ROM bank)
@same:
 inx
 cpx #SPC_SIZE
 bne @byte
 ldy #SPC_ENTRY
 sty $2142
 stz $2141
 clc
 adc #2
 bne @go
 lda #3
@go:
 sta $2140
@w2:
 cmp $2140
 bne @w2
 rep #$20
 .a16
 rts
