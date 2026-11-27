; ---------------------------------------------------------------- the map
; AddTile: world tile (scol, srow), its ring slot (slotc, slotr) -> one record on the queue
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
