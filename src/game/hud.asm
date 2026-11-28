; ---------------------------------------------------------------- HUD (BG2)
; Say: X = string; a message in gold for 2.5 s
Say:
 .a16
 .i16
 lda #150
 sta sayt
 lda #20
 ldy #$0400|HUD_PRIO
 jmp PrintCenter

; ClearRow: A = row (columns 3..31: the vial and the life numbers at 1-2 stay)
ClearRow:
 .a16
 .i16
 tay
 asl
 asl
 asl
 asl
 asl
 asl
 clc
 adc #6
 tax
 lda #29
 sta tmp0
@c:
 stz.w hudmap,x
 inx
 inx
 dec tmp0
 bne @c
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 rts

; PrintCenter: A = row, X = string, Y = attributes
PrintCenter:
 .a16
 .i16
 sta tmp1
 sty attr
 stx strp
 jsr ClearRow
 ldy #0
@len:
 sep #$20
 .a8
 lda (strp),y
 rep #$20
 .a16
 and #$00FF
 beq @got
 iny
 bra @len
@got:
 tya
 sta tmp0
 lda #32
 sec
 sbc tmp0
 lsr
 sta tmp0
 lda tmp1
 asl
 asl
 asl
 asl
 asl
 clc
 adc tmp0
 asl
 tax
 jmp PrintStr

; PrintAt: A = row * 32 + column, X = string, Y = attributes
PrintAt:
 .a16
 .i16
 sty attr
 stx strp
 asl
 tax
PrintStr:
 txa
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tay
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 ldy #0
@c:
 sep #$20
 .a8
 lda (strp),y
 rep #$20
 .a16
 and #$00FF
 beq @end
 phy
 sec
 sbc #32
 tay
 sep #$20
 .a8
 lda.w charmap,y
 rep #$20
 .a16
 and #$00FF
 clc
 adc fontoff
 ora attr
 sta.w hudmap,x
 ply
 inx
 inx
 iny
 bra @c
@end:
 rts

; PrintNum: A = value, X = map byte offset, attr set -> X after the digits
PrintNum:
 .a16
 .i16
 stx tmpA
 sta tmp0
 ldy #0
@d:
 lda #10
 sta tmp7
 lda tmp0
 jsr Div
 sta tmp0
 lda tmp6
 sta.w numbuf,y
 iny
 iny
 lda tmp0
 bne @d
 sty tmp1
 lda tmpA
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tay
 sep #$20
 .a8
 lda #1
 sta.w hudd,y
 rep #$20
 .a16
 ldy tmp1
 ldx tmpA
@o:
 dey
 dey
 lda.w numbuf,y
 clc
 adc #FONT_BASE+1
 clc
 adc fontoff
 ora attr
 sta.w hudmap,x
 inx
 inx
 cpy #0
 bne @o
 rts

; PutTile: A = entry, X = map byte offset (marks the row); X kept
PutTile:
 .a16
 .i16
 sta.w hudmap,x
 phx
 txa
 lsr
 lsr
 lsr
 lsr
 lsr
 lsr
 tax
 sep #$20
 .a8
 lda #1
 sta.w hudd,x
 rep #$20
 .a16
 plx
 rts

VIAL_ROW = 19
BELT_ROW = 23
HudRefresh:
 .a16
 .i16
 jsl $800000+X_SkillHud
 lda.w emaxhp               ; the vial: liquid from cut = top + (1 - life / max) * (bot - top) down
 sec
 sbc.w ehp
 sta tmp0
 asl
 asl
 asl
 sta tmp1
 lda tmp0
 asl
 asl
 asl
 asl
 asl
 clc
 adc tmp1
 sec
 sbc tmp0
 sta tmp1
 lda.w emaxhp
 sta tmp7
 lda tmp1
 jsr Div
 clc
 adc #VIAL_TOP
 sta tmpB
 stz tmpC
@vr:
 lda tmpC
 asl
 asl
 asl
 clc
 adc #8
 sec
 sbc tmpB                   ; full rows in this tile: 0..8
 bpl @s0
 lda #0
@s0:
 cmp #9
 bcc @s1
 lda #8
@s1:
 sta tmp2
 lda tmpC
 asl
 asl
 asl
 clc
 adc tmpC
 clc
 adc tmp2
 asl
 clc
 adc #VIAL_BASE
 ora #$0000|HUD_PRIO
 sta tmpD
 lda tmpC
 clc
 adc #VIAL_ROW
 asl
 asl
 asl
 asl
 asl
 inc a
 asl
 tax
 lda tmpD
 jsr PutTile
 inx
 inx
 lda tmpD
 inc a
 jsr PutTile
 inc tmpC
 lda tmpC
 cmp #6
 bne @vr
 lda #VIAL_ROW+6            ; the life numbers under it
 jsr ClearRow
 lda #$0000|HUD_PRIO
 sta attr
 ldx #((VIAL_ROW+6)*32+1)*2
 lda.w ehp
 jsr PrintNum
 lda #CH_SLASH|$0000|HUD_PRIO
 jsr PutTile
 inx
 inx
 lda.w emaxhp
 jsr PrintNum
 stz tmpC                   ; the belt: four slots, the chosen one framed in gold
@b:
 lda tmpC
 jsl $800000+X_BeltKind
 sta tmp0
 stz tmp1
 lda tmpC
 cmp beltsel
 bne @ns
 lda #5
 sta tmp1
@ns:
 lda tmp1
 clc
 adc tmp0
 asl
 asl
 clc
 adc #BELT_BASE
 ora #$0000|HUD_PRIO
 sta tmpD
 lda tmpC
 asl
 clc
 adc #BELT_ROW*32+12
 asl
 tax
 lda tmpD
 jsr PutTile
 inx
 inx
 lda tmpD
 inc a
 jsr PutTile
 txa
 clc
 adc #62
 tax
 lda tmpD
 inc a
 inc a
 jsr PutTile
 inx
 inx
 lda tmpD
 clc
 adc #3
 jsr PutTile
 inc tmpC
 lda tmpC
 cmp #4
 bne @b
 lda #22                    ; unspent stat points
 jsr ClearRow
 lda points
 beq @r
 lda mode
 bne @r
 lda #$0400|HUD_PRIO
 sta attr
 ldx #(22*32+6)*2
 lda points
 jsr PrintNum
 txa
 lsr
 inc a
 ldx #str_points
 ldy #$0400|HUD_PRIO
 jsr PrintAt
@r:
 rts
