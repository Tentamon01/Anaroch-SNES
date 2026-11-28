; ---------------------------------------------------------------- loot on the ground (main.c drop_spawn, hero_update)
; DropAt: A = type (1 gold, 2 potion, 3 tome), tmpB = amount, X = the monster it falls from
DropAt:
 .a16
 .i16
 sta tmp0
 ldy #0
@f:
 lda.w dtyp,y
 beq @got
 iny
 iny
 cpy #NDROP*2
 bne @f
 clc
 rts
@got:
 lda tmp0
 sta.w dtyp,y
 lda tmpB
 sta.w damt,y
 lda #0
 sta.w dage,y
 phy
 lda #15
 jsr RandRange
 sec
 sbc #7
 sta tmp1
 lda #15
 jsr RandRange
 sec
 sbc #7
 sta tmp2
 ply
 lda.w ex,x
 lsr4
 clc
 adc tmp1
 sta.w dpx,y
 lda.w ey,x
 lsr4
 clc
 adc tmp2
 sta.w dpy,y
 sec
 rts

PICKUP_REACH = 22            ; 1.4 m
UpdateDrops:
 .a16
 .i16
 lda #$FFFF
 sta tmpB                   ; the nearest potion / tome
 lda #PICKUP_REACH
 sta tmpC
 ldx #0
@l:
 lda.w dtyp,x
 bne @on
 jmp @n
@on:
 lda.w dage,x
 cmp #24                    ; 0.4 s before it can be picked up
 bcs @ready
 inc a
 sta.w dage,x
 jmp @n
@ready:
 lda.w ex
 lsr4
 sec
 sbc.w dpx,x
 sta tmp0
 lda.w ey
 lsr4
 sec
 sbc.w dpy,x
 sta tmp2
 jsr Dist
 sta tmp4
 lda.w dtyp,x
 cmp #1
 bne @item
 lda tmp4                   ; gold: walked over
 cmp #11
 bcs @n
 lda #SFX_COIN
 jsr Sfx
 lda gold
 clc
 adc.w damt,x
 bcc @g
 lda #$FFFF
@g:
 sta gold
 stz.w dtyp,x
 bra @n
@item:
 lda tmp4
 cmp tmpC
 bcs @n
 sta tmpC
 stx tmpB
@n:
 inx
 inx
 cpx #NDROP*2
 beq @end
 jmp @l
@end:
 lda mode
 bne @r
 lda tmpB
 cmp #$FFFF
 bne @thing
 jsr NearPerson             ; nothing on the ground: someone to talk to?
@thing:
 lda tmpB
 cmp nearshown
 beq @same
 sta nearshown
 jsr ShowPrompt
@same:
 lda tmpB
 cmp #$FFFF
 beq @r
 lda padnew
 and #PAD_A
 beq @r
 lda tmpB
 bpl @drop
 and #$7FFF
 tax
 jmp Talk
@drop:
 ldx tmpB
 lda.w dtyp,x
 cmp #3
 beq @tome
 txa                        ; a piece: into the bag
 jsl $800000+X_PickUp
 bcc @r
 ldx tmpB
 stz.w dtyp,x
 rts
@tome:
 lda #SFX_PICK
 jsr Sfx
 ldx tmpB
 stz.w dtyp,x
 inc points
 lda #1
 sta hudflag
 ldx #str_tome_read
 jmp Say
@r:
 rts

ShowPrompt:
 .a16
 .i16
 lda nearshown
 cmp #$FFFF
 bne @show
 lda #21
 jmp ClearRow
@show:
 bpl @thing
 jmp PersonPrompt
@thing:
 tax
 lda.w dtyp,x
 cmp #3
 beq @t
 txa
 jsl $800000+X_Prompt
 ldy #$0000|HUD_PRIO
 cmp #1
 beq @gold
 cmp #3
 beq @gold
 cmp #4
 bne @p
@gold:
 ldy #$0400|HUD_PRIO
@p:
 lda #21
 ldx #namebuf
 jmp PrintCenter
@t:
 lda #21
 ldx #str_pick_tome
 ldy #$0400|HUD_PRIO
 jmp PrintCenter
