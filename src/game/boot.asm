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
 jsr UploadSound
 jsl $800000+SplashPlay     ; the studio's splash
 jsr InitVideo
 ldx #8                     ; the bars' table in work memory, so a fade can dim it
@bars:
 lda.w bars,x
 sta barsR,x
 dex
 dex
 bpl @bars
 jsr NewGame
 jsl $800000+X_AnySave
 bcc @nosave
 inc startAsk
@nosave:
 jsr UpdateCam
 jsr FullMap
 jsr HudRefresh
 jsr BuildOam
 sep #$20
 .a8
 stz $4370                  ; HDMA channel 7: the brightness, blank bars above and below
 stz $4371
 ldx #barsR
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
 sep #$20
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
 jmp MainLoop

bars: .byte 8, $80, 127, $0F, 81, $0F, 1, $80, 0

InitVideo:
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
 lda #hudmap                ; the whole text layer, empty (the splash left its pictures there)
 sta n0
 stz n1
 lda #$4800
 sta n2
 lda #2048
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
 lda #fx_tiles              ; the skills' sparks: sprite tiles $AA-$AF and $BA-$BF
 sta n0
 lda #^fx_tiles
 sta n1
 lda #$6AA0
 sta n2
 lda #192
 sta n3
 jsr DmaV
 lda #fx_tiles + 192
 sta n0
 lda #$6BA0
 sta n2
 jsr DmaV
 jsr PlaceVideo             ; the place's glow and colours (nothing yet at boot)
 rts

; every colour the game shows (the bag screen has its own: this brings them back)
InitColors:
 .a16
 .i16
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
 lda #W_PALS
 sta n0
 lda #$007F
 sta n1
 lda #32
 sta n2
 lda #192
 sta n3
 jsr DmaC
 stz n1
 lda #obj_pals
 sta n0
 lda #128
 sta n2
 lda #256
 sta n3
 jsr DmaC
 lda #W_PALS+192        ; sprite palette 6: the walk-behind blocks
 sta n0
 lda #$007F
 sta n1
 lda #224
 sta n2
 lda #32
 sta n3
 jsr DmaC
 lda #W_PALS+224        ; colours 21-23: BG3's palette 5 (unused by the gold text)
 sta n0
 lda #21
 sta n2
 lda #6
 sta n3
 jsr DmaC
 stz n1
 jmp PeoplePals         ; the townspeople's colours, in the monsters' places

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
