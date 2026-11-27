; Walk-behind: what stands in front of a character is drawn again over it, as 16x16 sprites. tools/build_world.py cuts
; everything that stands up from the floor into blocks, each with the depth of its foot. The blocks the characters need
; are copied into 64 picture places on the second sprite page ($7000), a few per frame.
OCC_MAX = 16                 ; block sprites in a frame

; Occlude: after AddDyn of a character (tmp0 = x from the screen's middle, tmp2 = its depth key). X kept
Occlude:
 .a16
 .i16
 phx
 lda tmp0
 clc
 adc #128+16
 cmp #256+32
 bcc @on
 jmp @out
@on:
 lda tmp2
 sec
 sbc #$4000-112
 sta oby                    ; its feet on screen
 clc
 adc #16
 cmp #224+48
 bcc @on2
 jmp @out
@on2:
 lda tmp2
 clc
 adc #3
 sta okey                   ; hidden only by what stands at least this near
 lda tmp0
 clc
 adc camx
 clc
 adc #128
 sta opx                    ; its column in the picture
 sec
 sbc #10                    ; the columns of blocks across its body
 bpl @x0
 lda #0
@x0:
 sta orow
 lsr4
 sta obx0
 lda orow
 clc
 adc #20
 lsr4
 cmp #OCC_W
 bcc @x1
 lda #OCC_W-1
@x1:
 sta obx1
 lda oby
 clc
 adc camy
                            ; the rows: from the feet up to the head
 bpl @feet
 jmp @out
@feet:
 sta orow
 clc
 adc #10                    ; (feet and fallen bodies reach a few lines below the ground point)
 lsr4
 cmp #OCC_H
 bcc @y1
 lda #OCC_H-1
@y1:
 sta oby1
 lda orow
 sec
 sbc #30
 bpl @y0
 lda #0
@y0:
 lsr4
 sta oby
 lda obx1
 sec
 sbc obx0
 bpl @cols
 jmp @out
@cols:
 inc a
 sta obx1                   ; (now: how many columns)
@row:
 lda oby1
 cmp oby
 bcc @out
 lda oby
 asl
 tax
 lda.w occrow,x
 sta orow
 lda obx0
 asl
 clc
 adc orow
 tax
 ldy obx1
@col:
 lda.l wocc_map,x
 bne @some
@next:
 inx
 inx
 dey
 bne @col
 inc oby
 bra @row
@some:
 sta oid
 txa                        ; the block's middle column in the picture: column * 16 + 8
 sec
 sbc orow
 asl
 asl
 asl
 clc
 adc #8
 sta obx
 lda oid
 asl
 bcs @south
 bmi @east
 lda.l wocc_depth,x
 bra @have
@south:                     ; a wall running south: its foot comes 1 nearer for every column to the left
 lda obx
 sec
 sbc opx
 clc
 adc.l wocc_depth,x
 bra @have
@east:                      ; one running east: half a step nearer for every column to the right
 lda opx
 sec
 sbc obx
 cmp #$8000
 ror
 clc
 adc.l wocc_depth,x
@have:
 sec
 sbc fly
 clc
 adc #$4000
 cmp okey
 bcc @next
 sta tmp2
 phx
 phy
 lda oid
 and #$3FFF
 sta oid
 lda obx
 lsr4
 sta obx
 jsr AddBlock
 ply
 plx
 bra @next
@out:
 plx
 rts

; AddBlock: block oid at (obx, oby), depth key tmp2. A picture place is found (or it waits for a later frame) and the
; sprite joins the depth-sorted list
AddBlock:
 .a16
 .i16
 lda ol_n
 cmp #OCC_MAX*2
 bcc @room
 rts
@room:
 lda oid
 and #63
 asl
 tax
 ldy #$FFFF                 ; the first place nobody uses this frame
 lda #8
 sta ocnt
@probe:
 lda.w ocid,x
 cmp oid
 beq @hit
 cpy #$FFFF
 bne @skip
 lda.w ocst,x
 cmp frame
 beq @skip
 txy
@skip:
 inx
 inx
 txa
 and #127
 tax
 dec ocnt
 bne @probe
 cpy #$FFFF
 beq @full
 lda oq_n
 cmp olim
 bcc @new
@full:
 rts
@new:
 tyx
 lda oid
 sta.w ocid,x
 lda oq_n                   ; queue its picture: source, bank, video address
 asl
 sta ocnt
 asl
 clc
 adc ocnt
 tay
 lda oid
 xba
 and #$00FF
 clc
 adc #OCC_BANK
 sta.w oq+2,y
 lda oid
 and #$00FF
 xba
 lsr
 ora #$8000
 sta.w oq,y
 lda.w ob_tile,x
 asl4
 clc
 adc #$7000
 sta.w oq+4,y
 inc oq_n
 bra @show
@hit:
 lda.w ocst,x
 cmp frame
 beq @no                    ; already listed for another character
@show:
 lda frame
 sta.w ocst,x
 lda.w ob_tile,x
 ora #$2D00                 ; second sprite page, palette 6, priority 2
 ldy ol_n
 sta.w ol_t,y
 lda oby
 asl4
 sec
 sbc camy
 dec a                      ; (sprites show a line below their number)
 sta.w ol_y,y
 lda obx
 asl4
 sec
 sbc camx
 sec
 sbc #128
 sta tmp0
 tya
 ora #$0300
 sta tmp9
 iny
 iny
 sty ol_n
 jmp AddDynRaw
@no:
 rts

; OccUpload (in the frame interrupt): the new blocks' pictures, two rows of 64 bytes each
OccUpload:
 .a16
 .i16
 lda oq_n
 beq @r
 sta n5
 lda #$80
 sta n4
 ldx #0
@l:
 lda.w oq,x
 sta n0
 lda.w oq+2,x
 sta n1
 lda.w oq+4,x
 sta n2
 lda #64
 sta n3
 jsr DmaV
 lda n0
 clc
 adc #64
 sta n0
 lda n2
 clc
 adc #256
 sta n2
 jsr DmaV
 txa
 clc
 adc #6
 tax
 dec n5
 bne @l
 stz oq_n
@r:
 rts

ob_tile: .word 0, 2, 4, 6, 8, 10, 12, 14, 32, 34, 36, 38, 40, 42, 44, 46
 .word 64, 66, 68, 70, 72, 74, 76, 78, 96, 98, 100, 102, 104, 106, 108, 110
 .word 128, 130, 132, 134, 136, 138, 140, 142, 160, 162, 164, 166, 168, 170, 172, 174
 .word 192, 194, 196, 198, 200, 202, 204, 206, 224, 226, 228, 230, 232, 234, 236, 238
