; Dual-chip cartridge test: SuperFX 2 + SPC7110 on the custom ares board ANAROCH-DUAL (see tools/build_dual.mjs).
; SPC7110: reads its data ROM through the data port and through the $D0 bank. SuperFX: runs a short GSU program from
; its RAM and reads back the result. Results are printed on screen.
.ram $10
tmp0:     .res 2
tmp1:     .res 2
tmpv:     .res 2
n0:       .res 2
n1:       .res 2
n2:       .res 2
n3:       .res 2
strp:     .res 2
attr:     .res 2
res0:     .res 2
.ram $0100
txt:      .res 32
.ram $0800
hudmap:   .res 2048

ROW = 64                      ; bytes per map row

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
 stz $4200
 stz $420C
 rep #$20
 .a16
 ldx #0
 lda #0
@c:
 sta.w hudmap,x
 inx
 inx
 cpx #2048
 bne @c

 lda #$0400                  ; gold title
 sta attr
 ldx #str_title
 ldy #3*ROW+4
 jsr Print
 jsr TestSpc
 jsr TestSfx

 ; video: mode 1, BG2 with the game's font
 sep #$20
 .a8
 lda #$01
 sta $2105
 lda #$50
 sta $2108
 lda #$40
 sta $210B
 lda #$02
 sta $212C
 rep #$20
 .a16
 lda #hud_tiles
 sta n0
 lda #^hud_tiles
 sta n1
 lda #$4000
 sta n2
 lda #HUD_TILES_BYTES
 sta n3
 jsr DmaV
 lda #hudmap
 sta n0
 stz n1
 lda #$5000
 sta n2
 lda #2048
 sta n3
 jsr DmaV
 sep #$20
 .a8
 stz $2121
 ldx #0
@bk:
 lda.w black,x
 sta $2122
 inx
 cpx #2
 bne @bk
 rep #$20
 .a16
 lda #hud_pals
 sta n0
 stz n1
 lda #16
 sta n2
 lda #128
 sta n3
 jsr DmaC
 sep #$20
 .a8
 lda #$0F
 sta $2100
 rep #$20
 .a16
@forever:
 bra @forever

; ---------------------------------------------------------------- SPC7110
TestSpc:
 .a16
 .i16
 sep #$20
 .a8
 lda #$01
 sta $4834                    ; data ROM is 2 MB wide decode
 stz $4818                    ; step 1 per read
 stz $4811
 stz $4812
 stz $4813                    ; address 0: latches the first byte
 ldx #0
@r:
 lda $4810
 sta.w txt,x
 inx
 cpx #20
 bne @r
 stz.w txt,x
 rep #$20
 .a16
 lda #$0800                   ; white
 sta attr
 ldx #str_spc1
 ldy #6*ROW+4
 jsr Print
 ldx #txt
 ldy #7*ROW+6
 jsr Print
 ; the data port at offset $20000 vs the $D0 bank mapping of data ROM
 sep #$20
 .a8
 stz $4831                    ; $D0 bank = data ROM megabyte 0
 stz $4811
 lda #$00
 sta $4812
 lda #$02
 sta $4813
 lda $4810
 sta tmp0
 lda $4810
 sta tmp0+1
 lda.l $D20000
 sta tmp1
 lda.l $D20001
 sta tmp1+1
 rep #$20
 .a16
 ldx #str_spc2
 ldy #9*ROW+4
 jsr Print
 ldx #str_spc3
 ldy #10*ROW+4
 jsr Print
 lda tmp1
 sta res0
 lda tmp0
 ldy #9*ROW+44
 jsr PrintHex
 lda res0
 ldy #10*ROW+44
 jsr PrintHex
 rts

; ---------------------------------------------------------------- SuperFX 2
TestSfx:
 .a16
 .i16
 ldx #0                       ; the program into the GSU's RAM
 sep #$20
 .a8
@cp:
 lda.l gsu_code,x
 sta.l $700000,x
 inx
 cpx #gsu_len
 bne @cp
 rep #$20
 .a16
 lda #0
 sta.l $700100
 sta.l $700102
 sep #$20
 .a8
 lda #$70
 sta $3034                    ; program bank: RAM
 lda #$01
 sta $3039                    ; 21 MHz
 lda #$08
 sta $303A                    ; the GSU owns its RAM (not the ROM, the CPU keeps running from it)
 rep #$20
 .a16
 lda #0
 sta $301E                    ; R15 = $0000: start
 ldx #0                       ; wait for STOP (G cleared), counting
@w:
 inx
 lda $3030
 and #$0020
 bne @w
 stx res0
 sep #$20
 .a8
 stz $303A                    ; RAM back to the CPU
 rep #$20
 .a16
 lda #$0800
 sta attr
 ldx #str_sfx1
 ldy #12*ROW+4
 jsr Print
 lda.l $700100
 ldy #12*ROW+48
 jsr PrintHex
 ldx #str_sfx2
 ldy #14*ROW+4
 jsr Print
 lda.l $700102
 ldy #14*ROW+48
 jsr PrintHex
 ldx #str_sfx3
 ldy #16*ROW+4
 jsr Print
 lda res0
 ldy #16*ROW+48
 jsr PrintHex
 rts

; Print: X = string, Y = map byte offset, attr set
Print:
 .a16
 .i16
 stx strp
 tyx
@l:
 sep #$20
 .a8
 lda (strp)
 rep #$20
 .a16
 and #$00FF
 beq @end
 sec
 sbc #32
 tay
 sep #$20
 .a8
 lda.w charmap,y
 rep #$20
 .a16
 and #$00FF
 ora attr
 ora #$2000
 sta.w hudmap,x
 inx
 inx
 inc strp
 bra @l
@end:
 rts

; PrintHex: A = word, Y = map byte offset
PrintHex:
 .a16
 .i16
 sta tmpv
 tyx
 lda #4
 sta tmp1
@d:
 lda tmpv
 xba
 lsr
 lsr
 lsr
 lsr
 and #$000F
 cmp #10
 bcc @n
 clc
 adc #'A'-'0'-10
@n:
 clc
 adc #'0'-32
 tay
 sep #$20
 .a8
 lda.w charmap,y
 rep #$20
 .a16
 and #$00FF
 ora attr
 ora #$2000
 sta.w hudmap,x
 inx
 inx
 lda tmpv
 asl
 asl
 asl
 asl
 sta tmpv
 dec tmp1
 bne @d
 rts

DmaV:
 .a16
 sep #$20
 .a8
 lda #$80
 sta $2115
 lda n1
 sta $4304
 rep #$20
 .a16
 lda n2
 sta $2116
 lda #$1801
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

Rti:
 rti

black: .word $0000
; GSU program (runs from its RAM at $70:0000)
;   iwt r1,#$1234 ; iwt r2,#$0111 ; with r1 / add r2        r1 = $1345
;   sm ($0100),r1
;   iwt r12,#$C350 ; iwt r13,#loop ; ibt r3,#0 ; loop: inc r3 ; loop ; nop      r3 = 50000 = $C350
;   sm ($0102),r3 ; stop ; nop
gsu_code:
 .byte $F1, $34, $12
 .byte $F2, $11, $01
 .byte $21, $52
 .byte $3E, $F1, $00, $01
 .byte $FC, $50, $C3
 .byte $FD
 .word GSU_LOOP
 .byte $A3, $00
GSU_LOOP = * - gsu_code
 .byte $D3, $3C, $01
 .byte $3E, $F3, $02, $01
 .byte $00, $01
gsu_len = * - gsu_code

str_title: .byte "ANAROCH DUAL CHIP TEST", 0
str_spc1:  .byte "SPC7110 DATA PORT:", 0
str_spc2:  .byte "DATA PORT AT 20000:", 0
str_spc3:  .byte "BANK D2:0000:", 0
str_sfx1:  .byte "SUPERFX 1234+0111:", 0
str_sfx2:  .byte "SUPERFX LOOP OF C350:", 0
str_sfx3:  .byte "CPU POLLS MEANWHILE:", 0

.include "data.inc"

.bank 0
.org $FFC0
.byte "ANAROCH DUAL TEST    "
.org $FFD5
.byte $20, $15, $09, $07, $01, $33, $00
.org $FFE4
.word Rti, Rti, Rti, Rti, Rti, Rti
.org $FFF4
.word Rti, Rti, Rti, Rti, Reset, Rti
