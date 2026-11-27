; Step 0 of the remake: can the game's code run from the SPC7110's ROM window while the SuperFX owns the cartridge?
; The engine below runs at $C1:8000 (the same file bytes the SuperFX sees at $03:8000), with the frame interrupt and
; a mid-screen interrupt on, while the SuperFX draws almost all the time. Everything it does is checked, and the CPU
; time left over each frame is measured with slow and with fast ROM.
GSU_START = $C000
SUMBYTES = 4096
CHUNK = 512

.ram $10
frames:   .res 2             ; frames seen by the frame interrupt
irqs:     .res 2             ; mid-screen interrupts
pictures: .res 2             ; SuperFX pictures shown
bad:      .res 2             ; wrong results of code and data fetched from the window
passes:   .res 2             ; checksum passes that were right
busy:     .res 2             ; frames in which the SuperFX held the ROM while the CPU worked
held:     .res 2             ; of those, how often $00:FFEA read as the SuperFX's stand-in vector
spare:    .res 2             ; idle loops counted this frame
spareslow: .res 2
sparefast: .res 2
flag:     .res 2
state:    .res 2
front:    .res 2
pos:      .res 2
sum:      .res 2
tmp0:     .res 2
tmp1:     .res 2
tmp2:     .res 2
tmpv:     .res 2
upcount:  .res 2
.ram $0200
textbuf:  .res 2048

; ---------------------------------------------------------------- boot (bank 0: the SuperFX is idle)
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
 stz $420D
 stz $303A
 rep #$20
 .a16
 ldx #0
 lda #0
@c:
 sta.w $0000,x
 inx
 inx
 cpx #$1F00
 bne @c
 ; the interrupt trampolines in work RAM: while the SuperFX owns the ROM, the CPU is sent to $0108 / $010C
 sep #$20
 .a8
 lda #$5C                    ; jml
 sta.w $0108
 sta.w $010C
 lda #$C1
 sta.w $010B
 sta.w $010F
 rep #$20
 .a16
 lda #Nmi & $FFFF
 sta.w $0109
 lda #Irq & $FFFF
 sta.w $010D
 ; clear video memory
 sep #$20
 .a8
 lda #$80
 sta $2115
 ldx #0
 stx $2116
 ldx #$1809
 stx $4300
 ldx #zero
 stx $4302
 stz $4304
 ldx #0
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
 jsr Video
 ; the SuperFX's parameters: six pictures, in a row and a half
 ldx #0
@p:
 lda.w params,x
 sta.l $70E000,x
 inx
 inx
 cpx #60
 bne @p
 sep #$20
 .a8
 lda #$A0
 sta $3037
 stz $3038
 lda #$01
 sta $3039
 stz $3034
 lda #112                    ; the mid-screen interrupt
 sta $4209
 stz $420A
 rep #$20
 .a16
 lda #3
 sta state
 jml.l $C10000+(Main & $FFFF)

zero: .word 0

Vram:                        ; X = source, A = bytes, tmp1 = VRAM word address
 .a16
 sta tmp2
 sep #$20
 .a8
 lda #$80
 sta $2115
 stz $4304
 rep #$20
 .a16
 lda tmp1
 sta $2116
 lda #$1801
 sta $4300
 stx $4302
 lda tmp2
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

Video:
 .a16
 .i16
 sep #$20
 .a8
 lda #$09
 sta $2105
 lda #$24
 sta $2107
 lda #$2C
 sta $2109
 stz $210B
 lda #$03
 sta $210C
 lda #$05
 sta $212C                   ; the SuperFX picture and the words
 lda #$FF
 sta $210E
 sta $210E
 sta $2112
 sta $2112
 stz $2121
 ldx #0
@p0:
 lda.w txtpal,x
 sta $2122
 inx
 cpx #8
 bne @p0
 lda #32
 sta $2121
 ldx #0
@p1:
 lda.w texpal,x
 sta $2122
 inx
 cpx #32
 bne @p1
 ; the font
 lda #$80
 sta $2115
 lda #^font_data
 sta $4304
 ldx #$3000
 stx $2116
 ldx #$1801
 stx $4300
 ldx #font_data
 stx $4302
 ldx #FONT_BYTES
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
 lda #512
 sta tmpv
 lda #$2400
 sta tmp1
 jsr ArenaMap
 lda #256
 sta tmpv
 lda #$2800
 sta tmp1
 jsr ArenaMap
 ldx #0
 lda #0
@t:
 sta.w textbuf,x
 inx
 inx
 cpx #2048
 bne @t
 lda #$2C00
 sta tmp1
 ldx #textbuf
 lda #2048
 jmp Vram

ArenaMap:
 .a16
 .i16
 ldx #0
 ldy #0
@row:
 lda #0
 sta tmp2
@col:
 lda tmp2
 cmp #8
 bcc @blank
 cmp #24
 bcs @blank
 cpy #6
 bcc @blank
 cpy #22
 bcs @blank
 sec
 sbc #8
 asl
 asl
 asl
 asl
 sta tmp0
 tya
 sec
 sbc #6
 clc
 adc tmp0
 ora #$2800
 bra @put
@blank:
 lda tmpv
@put:
 sta.w textbuf,x
 inx
 inx
 inc tmp2
 lda tmp2
 cmp #32
 bne @col
 iny
 cpy #32
 bne @row
 ldx #textbuf
 lda #2048
 jmp Vram

;          x, y, size, step, texture
params:
 .word  2,  4, 60, 136, $8000
 .word 66,  4, 60, 136, $9000
 .word  6, 66, 40, 204, $A000
 .word 50, 70, 32, 256, $8000
 .word 86, 70, 24, 341, $9000
 .word 60, 40, 78, 105, $A000

.include "../out/chip/chip.inc"

.org GSU_START
 .incbin "../out/chip/gsu.bin"
.org $FF00
Rti:
 rti

.bank 1
 .incbin "../out/chip/textures.bin"
.bank 2
.org $8000
font_data:
 .incbin "../out/chip/font.bin"

; ---------------------------------------------------------------- the engine: file bank 3, run at $C1:8000
.bank 3
.org $8000
Main:
 .a16
 .i16
 sep #$20
 .a8
 lda #$0F
 sta $2100
 lda #$A1                    ; frame and mid-screen interrupts
 sta $4200
 rep #$20
 .a16
 cli
@loop:
 lda flag
 beq @loop
 stz flag
 lda $3030                   ; is the SuperFX drawing while we work?
 and #$0020
 beq @idle
 inc busy
 lda.l $00FFEA               ; read the real cartridge: the SuperFX answers with its stand-in
 cmp #$0108
 bne @idle
 inc held
@idle:
 jsr SumChunk
 jsr Figures
 ; the first 240 frames on slow ROM, then fast
 lda frames
 cmp #240
 bcc @count
 sep #$20
 .a8
 lda #1
 sta $420D
 rep #$20
 .a16
@count:
 stz spare
@spin:
 inc spare
 lda flag
 beq @spin
 lda frames
 cmp #240
 bcs @fast
 lda spare
 sta spareslow
 bra @loop
@fast:
 lda spare
 sta sparefast
 bra @loop

; 512 bytes of a table in the window added up through a subroutine; every full table must give the build's sum
SumChunk:
 .a16
 .i16
 ldx pos
 ldy #CHUNK/2
@l:
 jsr AddWord
 inx
 inx
 dey
 bne @l
 stx pos
 cpx #SUMBYTES
 bne @r
 lda sum
 cmp #SUM
 beq @ok
 inc bad
 bra @z
@ok:
 inc passes
@z:
 stz sum
 stz pos
@r:
 rts

AddWord:
 .a16
 lda.l $C10000+(table & $FFFF),x
 clc
 adc sum
 sta sum
 rts

Irq:
 rep #$30
 .a16
 .i16
 pha
 sep #$20
 .a8
 lda $4211
 rep #$20
 .a16
 inc irqs
 pla
 rti

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
 inc frames
 lda state
 bne @s1
 lda $3030
 and #$0020
 bne @text
 sep #$20
 .a8
 stz $303A
 rep #$20
 .a16
 lda #1
 sta state
@s1:
 lda state
 cmp #1
 bne @s2
 lda #0
 jsr Half
 lda #2
 sta state
 bra @text
@s2:
 cmp #2
 bne @text
 lda #1
 jsr Half
 lda front
 eor #1
 sta front
 sep #$20
 .a8
 lda front
 bne @b
 stz $210B
 lda #$24
 sta $2107
 bra @f
@b:
 lda #$01
 sta $210B
 lda #$28
 sta $2107
@f:
 rep #$20
 .a16
 inc pictures
 lda #3
 sta state
@text:
 jsr TextOut
 lda state
 cmp #3
 bne @done
 ; the walk: each picture's texture moves on
 lda pictures
 lsr
 lsr
 and #3
 xba
 asl
 asl
 sta tmpv
 clc
 adc #$8000
 sta.l $70E008
 sta.l $70E026
 lda tmpv
 clc
 adc #$9000
 sta.l $70E012
 sta.l $70E030
 lda tmpv
 clc
 adc #$A000
 sta.l $70E01C
 sta.l $70E03A
 sep #$20
 .a8
 lda #$19
 sta $303A
 rep #$20
 .a16
 lda #GSU_START
 sta $301E
 stz state
@done:
 lda #1
 sta flag
 ply
 plx
 pla
 rti

Half:
 .a16
 sta tmp0
 xba
 asl
 asl
 asl
 asl
 sta tmp1
 lda tmp0
 beq @a
 lda #$0800
@a:
 sta tmp2
 lda front
 bne @into_a
 lda tmp2
 clc
 adc #$1000
 sta tmp2
@into_a:
 sep #$20
 .a8
 lda #$80
 sta $2115
 lda #$70
 sta $4304
 rep #$20
 .a16
 lda tmp2
 sta $2116
 lda #$1801
 sta $4300
 lda tmp1
 sta $4302
 lda #4096
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

TextOut:
 .a16
 sep #$20
 .a8
 lda #$80
 sta $2115
 stz $4304
 rep #$20
 .a16
 lda #$2C00+32
 sta $2116
 ldx #textbuf+64
 stx $4302
 lda #$1801
 sta $4300
 lda #320
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 lda #$2C00+23*32
 sta $2116
 ldx #textbuf+23*64
 stx $4302
 lda #256
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

; ---------------------------------------------------------------- words (all data through the window)
.macro line
 ldy #\1
 ldx #\2*64+4
 jsr Text
 lda \3
 ldx #\2*64+48
 jsr Hex
.endmacro

Figures:
 .a16
 .i16
 line str_title, 1, frames
 line str_pictures, 2, pictures
 line str_irqs, 3, irqs
 line str_busy, 4, busy
 line str_held, 5, held
 line str_passes, 23, passes
 line str_bad, 24, bad
 line str_slow, 25, spareslow
 line str_fast, 26, sparefast
 rts

; Y = string (in this bank), X = byte offset in the text buffer
Text:
 .a16
 phx
 tyx
 ply
@l:
 lda.l $C10000,x
 and #$00FF
 beq @e
 sec
 sbc #32
 phx
 tax
 lda.l $C10000+(charmap & $FFFF),x
 plx
 and #$00FF
 ora #$2000
 phx
 tyx
 sta.w textbuf,x
 plx
 inx
 iny
 iny
 bra @l
@e:
 rts

Hex:
 .a16
 sta tmpv
 lda #4
 sta upcount
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
 adc #7
@n:
 clc
 adc #'0'-32
 phx
 tax
 lda.l $C10000+(charmap & $FFFF),x
 plx
 and #$00FF
 ora #$2000
 sta.w textbuf,x
 inx
 inx
 lda tmpv
 asl
 asl
 asl
 asl
 sta tmpv
 dec upcount
 bne @d
 rts

str_title:    .byte "STEP 0  FRAMES", 0
str_pictures: .byte "SUPERFX PICTURES", 0
str_irqs:     .byte "MID SCREEN IRQS", 0
str_busy:     .byte "WORKED DURING GSU", 0
str_held:     .byte "ROM HELD BY GSU", 0
str_passes:   .byte "CODE CHECKS OK", 0
str_bad:      .byte "CODE CHECKS BAD", 0
str_slow:     .byte "SPARE SLOW ROM", 0
str_fast:     .byte "SPARE FAST ROM", 0
charmap:
 .incbin "../out/chip/charmap.bin"
table:
 .incbin "../out/chip/table.bin"

; ---------------------------------------------------------------- header + vectors
.bank 0
.org $FFC0
.byte "ANAROCH STEP ZERO    "
.org $FFD5
.byte $20, $15, $09, $07, $01, $33, $00
.org $FFE4
.word Rti, Rti, Rti, $0108, Rti, $010C
.org $FFF4
.word Rti, Rti, Rti, Rti, Reset, Rti
