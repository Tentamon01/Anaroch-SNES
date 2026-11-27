; Dual-chip test cartridge (custom ares board ANAROCH-DUAL): SuperFX 2 + SPC7110 + the sound chip, together.
; Boot: the sound driver is uploaded; the SPC7110 unpacks a 28 KB picture to VRAM and, a second time, into the CPU to
; be compared byte by byte with the unpacked original. Then every frame: the SuperFX draws six scaled characters from
; cartridge ROM into its RAM (while the CPU runs from WRAM, off the ROM), the CPU copies the finished picture to VRAM
; in two halves and flips it, the SPC7110 keeps unpacking and checking, and any dropped frame is counted.
GSU_START = $C000
COUNT = 6

.ram $10
tmp0:     .res 2
tmp1:     .res 2
tmp2:     .res 2
tmpv:     .res 2
frames:   .res 2
missed:   .res 2
renders:  .res 2
state:    .res 2
front:    .res 2
bootbad:  .res 2
loadok:   .res 2
loadbad:  .res 2
loadpos:  .res 2
loadsum:  .res 2
strp:     .res 2
upcount:  .res 2
.ram $0100
posx:     .res 12
posy:     .res 12
velx:     .res 12
vely:     .res 12
phase:    .res 12
.ram $0200
textbuf:  .res 2048

; ---------------------------------------------------------------- boot (from ROM)
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
 stz $303A                   ; ROM and RAM to the CPU
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
 jsr UploadSound
 ; clear VRAM
 sep #$20
 .a8
 lda #$80
 sta $2115
 ldx #0
 stx $2116
 ldx #$1809                  ; 2 registers, the source held still
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
 jsr BootSpc
 jsr Video
 jsr InitActors
 ; the SuperFX: no interrupt, fast multiply, 21 MHz, screen at the start of its RAM
 sep #$20
 .a8
 lda #$A0
 sta $3037
 stz $3038
 lda #$01
 sta $3039
 stz $3034
 rep #$20
 .a16
 ; the frame loop runs from WRAM
 ldx #0
@cp:
 lda.l loop_image,x
 sta.l $001000,x
 inx
 inx
 cpx #loop_size+1
 bcc @cp
 jmp.w $1000

zero: .word 0

; ---------------------------------------------------------------- sound: the IPL's upload
UploadSound:
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
@byte:
 lda.l spc_data,x
 sta $2141
 txa
 sta $2140
@w1:
 cmp $2140
 bne @w1
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

; ---------------------------------------------------------------- SPC7110 at boot
; start the decompression of directory entry 0 from the beginning
SpcStart:
 .a16
 sep #$20
 .a8
 stz $4801
 stz $4802
 stz $4803
 stz $4804
 stz $480B
 stz $4805
 stz $4806                   ; (this write starts it)
@w:
 lda $480C
 bpl @w
 rep #$20
 .a16
 rts

BootSpc:
 .a16
 .i16
 jsr SpcStart
 sep #$20
 .a8
 lda #$80
 sta $2115
 ldx #$4000
 stx $2116
 ldx #$1809                  ; DMA from the chip's port to VRAM
 stx $4300
 ldx #$0000
 stx $4302
 lda #$50
 sta $4304
 ldx #PIC_BYTES
 stx $4305
 lda #1
 sta $420B
 rep #$20
 .a16
 ; again, compared with the original through the data port
 jsr SpcStart
 sep #$20
 .a8
 lda #$01
 sta $4834
 stz $4818
 stz $4811
 stz $4812
 lda #$08
 sta $4813                   ; data ROM $080000
 ldx #0
@cmp:
 lda $4800
 cmp $4810
 beq @same
 rep #$20
 .a16
 inc bootbad
 sep #$20
 .a8
@same:
 inx
 cpx #PIC_BYTES
 bne @cmp
 rep #$20
 .a16
 rts

; ---------------------------------------------------------------- video
; X = source (bank 0..), A = bytes, tmp0 = bank, tmp1 = VRAM word address
Vram:
 .a16
 sta tmp2
 sep #$20
 .a8
 lda #$80
 sta $2115
 lda tmp0
 sta $4304
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
 sta $2105                   ; mode 1, BG3 on top
 lda #$24
 sta $2107
 lda #$34
 sta $2108
 lda #$2C
 sta $2109
 lda #$40
 sta $210B
 lda #$03
 sta $210C
 lda #$07
 sta $212C
 lda #$FF
 sta $210E
 sta $210E
 sta $2110
 sta $2110
 sta $2112
 sta $2112
 ; palettes: text 0-3, SuperFX picture 32-47, SPC7110 picture 48-63
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
 lda #48
 sta $2121
 ldx #0
@p2:
 lda.w picpal,x
 sta $2122
 inx
 cpx #32
 bne @p2
 rep #$20
 .a16
 stz tmp0
 lda #^font_data
 sta tmp0
 lda #$3000
 sta tmp1
 ldx #font_data
 lda #FONT_BYTES
 jsr Vram
 ; the picture's map: tiles in order, palette 3
 ldx #0
 lda #$0C00
@m2:
 sta.w textbuf,x             ; (used as a work area, cleared after)
 inc a
 inx
 inx
 cpx #1792
 bne @m2
 stz tmp0
 lda #$3400
 sta tmp1
 ldx #textbuf
 lda #1792
 jsr Vram
 ; the SuperFX screen's two maps: 16 x 16 tiles in the middle, column by column; blank elsewhere
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
 ; the text map: empty
 ldx #0
 lda #0
@t:
 sta.w textbuf,x
 inx
 inx
 cpx #2048
 bne @t
 stz tmp0
 lda #$2C00
 sta tmp1
 ldx #textbuf
 lda #2048
 jsr Vram
 rts

; tmpv = the blank tile, tmp1 = map address
ArenaMap:
 .a16
 .i16
 ldx #0
 ldy #0                      ; row
@row:
 lda #0                      ; column
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
 ora #$2800                  ; palette 2, in front of the picture
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
 stz tmp0
 ldx #textbuf
 lda #2048
 jmp Vram

InitActors:
 .a16
 .i16
 ldx #0
@a:
 lda.w init_x,x
 sta.w posx,x
 lda.w init_y,x
 sta.w posy,x
 lda.w init_vx,x
 sta.w velx,x
 lda.w init_vy,x
 sta.w vely,x
 lda.w init_ph,x
 sta.w phase,x
 inx
 inx
 cpx #COUNT*2
 bne @a
 stz front
 lda #3                      ; state 3: waiting to start the SuperFX
 sta state
 rts

init_x:  .word 4*16, 70*16, 30*16, 90*16, 10*16, 60*16
init_y:  .word 8*16, 4*16, 60*16, 70*16, 80*16, 36*16
init_vx: .word 11, -7, 14, -10, 6, -13
init_vy: .word 5, 9, -8, -6, -11, 7
init_ph: .word 0, 5, 10, 16, 21, 27

.include "../out/chip/chip.inc"

; ---------------------------------------------------------------- the frame loop (copied to $00:1000 and run there)
loop_image:
.phase $1000
Main:
 .a16
 .i16
 lda $4210                   ; did a frame start while the last one's work was still going on?
 and #$0080
 beq @wait
 lda frames
 beq @wait
 inc missed
@wait:
 lda $4210
 and #$0080
 beq @wait
 sep #$20
 .a8
 lda #$0F
 sta $2100
 rep #$20
 .a16
 inc frames
 ; ---- in vblank: the SuperFX picture
 lda state
 bne @s1
 lda $3030                   ; still drawing?
 and #$0020
 bne @text
 sep #$20
 .a8
 stz $303A                   ; its RAM back to the CPU
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
 ; show it
 lda front
 eor #1
 sta front
 sep #$20
 .a8
 lda front
 bne @b
 lda #$40
 sta $210B
 lda #$24
 sta $2107
 bra @f
@b:
 lda #$41
 sta $210B
 lda #$28
 sta $2107
@f:
 rep #$20
 .a16
 inc renders
 lda #3
 sta state
@text:
 ; ---- the figures, written while still in vblank
 jsr TextOut
 lda state
 cmp #3
 bne @work
 jsr Actors                  ; the next picture's parameters, then the SuperFX draws while the CPU goes on
 sep #$20
 .a8
 lda #$19
 sta $303A                   ; it owns ROM and RAM; 4 bits a pixel, 128 lines
 rep #$20
 .a16
 lda #GSU_START
 sta $301E
 stz state
@work:
 ; ---- outside vblank: more unpacking, checked; the figures for the next frame
 jsr Load
 jsr Figures
 jmp Main

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
 lda #256
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
 lda #192
 sta $4305
 sep #$20
 .a8
 lda #1
 sta $420B
 rep #$20
 .a16
 rts

; A = 0 / 1: the first or second 4 KB of the picture into the hidden screen
Half:
 .a16
 sta tmp0
 xba
 asl
 asl
 asl
 asl
 sta tmp1                    ; the source: 0 or $1000
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

; the characters: move, grow and shrink (as with distance), into the SuperFX's parameter table
Actors:
 .a16
 .i16
 ldx #0
 ldy #0                      ; the record's offset
@l:
 lda.w phase,x
 inc a
 and #127
 sta.w phase,x
 lsr
 lsr
 asl
 phx
 tax
 lda.w size_tab,x
 sta tmp0                    ; size
 lda.w step_tab,x
 sta tmp1
 plx
 lda #128
 sec
 sbc tmp0
 asl
 asl
 asl
 asl
 sta tmp2                    ; the furthest it may go (12.4)
 lda.w posx,x
 clc
 adc.w velx,x
 bpl @x1
 lda.w velx,x
 eor #$FFFF
 inc a
 sta.w velx,x
 lda #0
@x1:
 cmp tmp2
 bcc @x2
 lda.w velx,x
 bmi @x3
 eor #$FFFF
 inc a
 sta.w velx,x
@x3:
 lda tmp2
@x2:
 sta.w posx,x
 lda.w posy,x
 clc
 adc.w vely,x
 bpl @y1
 lda.w vely,x
 eor #$FFFF
 inc a
 sta.w vely,x
 lda #0
@y1:
 cmp tmp2
 bcc @y2
 lda.w vely,x
 bmi @y3
 eor #$FFFF
 inc a
 sta.w vely,x
@y3:
 lda tmp2
@y2:
 sta.w posy,x
 phx
 tyx
 ply
 lda.w posx,y
 lsr
 lsr
 lsr
 lsr
 sta.l $70E000,x
 lda.w posy,y
 lsr
 lsr
 lsr
 lsr
 sta.l $70E002,x
 lda tmp0
 sta.l $70E004,x
 lda tmp1
 sta.l $70E006,x
 lda renders                 ; the walk: 4 pictures; hero, ghoul, skeleton in turn
 lsr
 lsr
 and #3
 sta tmp0
 lda.w kind_tab,y
 clc
 adc tmp0
 xba
 asl
 asl
 clc
 adc #$8000                  ; texture address in its bank: $8000 + n * 1024
 sta.l $70E008,x
 phx
 tyx
 ply
 tya
 clc
 adc #10
 tay
 inx
 inx
 cpx #COUNT*2
 beq @done
 jmp @l
@done:
 rts

; unpack 512 bytes more each frame and add it up; a full picture must add up to the same each time
Load:
 .a16
 .i16
 lda loadpos
 bne @go
 stz loadsum
 sep #$20
 .a8
 stz $4801
 stz $4802
 stz $4803
 stz $4804
 stz $480B
 stz $4805
 stz $4806
@w:
 lda $480C
 bpl @w
 rep #$20
 .a16
@go:
 ldy #512
@l:
 lda $4800                   ; two bytes: the low half then the high
 and #$00FF
 sta tmpv
 lda $4800
 and #$00FF
 clc
 adc tmpv
 clc
 adc loadsum
 sta loadsum
 dey
 dey
 bne @l
 lda loadpos
 clc
 adc #512
 cmp #PIC_BYTES
 bne @keep
 lda loadsum
 cmp #PIC_SUM
 beq @good
 inc loadbad
 bra @zero
@good:
 inc loadok
@zero:
 lda #0
@keep:
 sta loadpos
 rts

; the numbers into the text buffer
Figures:
 .a16
 .i16
 ldy #str_title
 ldx #1*64+10
 jsr Text
 ldy #str_boot
 ldx #2*64+4
 jsr Text
 lda bootbad
 ldx #2*64+46
 jsr Hex
 ldy #str_frames
 ldx #3*64+4
 jsr Text
 lda frames
 ldx #3*64+18
 jsr Hex
 ldy #str_missed
 ldx #3*64+32
 jsr Text
 lda missed
 ldx #3*64+46
 jsr Hex
 ldy #str_sfx
 ldx #4*64+4
 jsr Text
 lda renders
 ldx #4*64+46
 jsr Hex
 ldy #str_load
 ldx #23*64+4
 jsr Text
 lda loadok
 ldx #23*64+32
 jsr Hex
 ldy #str_bad
 ldx #23*64+44
 jsr Text
 lda loadbad
 ldx #23*64+52
 jsr Hex
 ldy #str_sound
 ldx #24*64+4
 jsr Text
 lda $2142                   ; (the driver: which voices sound, and the "alive" mark)
 ldx #24*64+30
 jsr Hex
 ldy #str_loop
 ldx #24*64+44
 jsr Text
 lda $2140
 ldx #24*64+54
 jsr Hex
 rts

; Y = string, X = byte offset in the text buffer
Text:
 .a16
@l:
 lda.w $0000,y
 and #$00FF
 beq @e
 sec
 sbc #32
 phy
 tay
 lda.w ram_charmap,y
 and #$00FF
 ora #$2000
 sta.w textbuf,x
 ply
 iny
 inx
 inx
 bra @l
@e:
 rts

; A = value, X = byte offset: 4 digits
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
 tay
 lda.w ram_charmap,y
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

size_tab:  .word 20, 21, 23, 26, 30, 34, 39, 45, 51, 57, 63, 68, 72, 75, 77, 78, 78, 77, 75, 72, 68, 63, 57, 51, 45, 39, 34, 30, 26, 23, 21, 20
step_tab:  .word 409, 390, 356, 315, 273, 240, 210, 182, 160, 143, 130, 120, 113, 109, 106, 105, 105, 106, 109, 113, 120, 130, 143, 160, 182, 210, 240, 273, 315, 356, 390, 409
kind_tab:  .word 0, 4, 8, 0, 4, 8
str_title:  .byte "ANAROCH DUAL CHIP", 0
str_boot:   .byte "SPC7110 BOOT BAD:", 0
str_frames: .byte "FRAMES", 0
str_missed: .byte "MISSED", 0
str_sfx:    .byte "SUPERFX PICTURES", 0
str_load:   .byte "UNPACKED OK", 0
str_bad:    .byte "BAD", 0
str_sound:  .byte "SOUND VOICES", 0
str_loop:   .byte "SONG", 0
ram_charmap:
 .incbin "../out/chip/charmap.bin"
loop_end:
.dephase
loop_size = loop_end - $1000

; ---------------------------------------------------------------- data
.bank 0
.org GSU_START
 .incbin "../out/chip/gsu.bin"
.bank 1
 .incbin "../out/chip/textures.bin"
.bank 2
spc_data:
 .incbin "../out/audio/spc_chip.bin"   ; (the music is all in the first 32 KB; effects are not used here)
.bank 3
font_data:
 .incbin "../out/chip/font.bin"

.bank 0
.org $FFC0
.byte "ANAROCH CHIP TEST    "
.org $FFD5
.byte $20, $15, $09, $07, $01, $33, $00
.org $FFE4
.word Rti, Rti, Rti, Rti, Rti, Rti
.org $FFF4
.word Rti, Rti, Rti, Rti, Reset, Rti
.org $FF00
Rti:
 rti
