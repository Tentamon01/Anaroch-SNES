; 16-bit arithmetic for the rules. All routines: A, X, Y 16-bit.

; RandN: A = n -> A = 0 .. n-1  (the random word times n, upper half)
RandN:
 .a16
 .i16
 sta rm
 jsl FarRand
 jsr Mul16
 lda rh
 rts

; Chance: A = a chance of 1000 -> carry set when it happens
Chance:
 .a16
 pha
 lda #1000
 jsr RandN
 sta dv
 pla
 cmp dv                     ; carry set: chance >= roll; equal must fail
 beq @no
 rts
@no:
 clc
 rts

; Mul16: A * rm -> rh:rl.  X, Y kept
Mul16:
 .a16
 .i16
 phx
 sta rem                    ; a
 sep #$20
 .a8
 lda rem
 sta $4202
 lda rm
 sta $4203
 nop
 nop
 nop
 rep #$20
 .a16
 lda $4216
 sta rl                     ; al * bl
 stz rh
 sep #$20
 .a8
 lda rm+1
 sta $4203
 nop
 nop
 nop
 rep #$20
 .a16
 ldx $4216                  ; al * bh
 sep #$20
 .a8
 lda rem+1
 sta $4202
 lda rm
 sta $4203
 nop
 nop
 nop
 rep #$20
 .a16
 txa
 clc
 adc $4216                  ; + ah * bl (17 bits: the carry goes to bit 24)
 tax
 lda #0
 rol
 xba
 sta rh
 txa
 xba
 and #$FF00                 ; the middle sum's low byte, into bits 8-15
 clc
 adc rl
 sta rl
 txa
 xba
 and #$00FF
 adc rh
 sta rh
 sep #$20
 .a8
 lda rm+1
 sta $4203
 nop
 nop
 nop
 rep #$20
 .a16
 lda $4216
 clc
 adc rh                     ; + ah * bh in the upper word
 sta rh
 plx
 rts

; Div32: rh:rl / A -> rh:rl the quotient, rem the remainder.  X, Y kept
Div32:
 .a16
 .i16
 phx
 sta dv
 stz rem
 ldx #32
@l:
 asl rl
 rol rh
 rol rem
 bcs @sub
 lda rem
 cmp dv
 bcc @next
@sub:
 lda rem
 sec
 sbc dv
 sta rem
 inc rl
@next:
 dex
 bne @l
 plx
 rts

; MulDiv: A * rm / dv -> A (low word of the quotient)
MulDiv:
 .a16
 jsr Mul16
 lda dv
 jsr Div32
 lda rl
 rts

; Pct: A * (100 + Y) / 100 -> A, at most 65535
Pct:
 .a16
 .i16
 pha
 tya
 clc
 adc #100
 sta rm
 pla
 jsr Mul16
 lda #100
 jsr Div32
 lda rh
 beq @ok
 lda #$FFFF
 rts
@ok:
 lda rl
 rts
