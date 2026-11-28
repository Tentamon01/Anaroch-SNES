; ---------------------------------------------------------------- the places (main.c enter_area, the gates, the portal)
; A place's record lies in its megabyte of the data ROM (tools/build_world.py): a head of HEAD_WORDS words, copied to
; mapW.. , then what is copied to work RAM bank $7F: (source, address, bytes) seven bytes a part, three zeros at the end.
TRAVEL_FADE = 16             ; frames to black, and back
PORTAL_ARM = 60              ; a portal takes the hero a second after it opens
PORTAL_REACH = 10            ; 0.6 m

; EnterPlace: A = the place, goX / goY (px; goX $FFFF: its start, $FFFE: beside the town's portal), goDir.
; The screen goes blank; the main loop draws the place anew.
EnterPlace:
 .a16
 .i16
 sta placeId
 sep #$20
 .a8
 stz $420C
 lda #$80
 sta $2100
 rep #$20
 .a16
 jsr AreaLoad
 lda goX
 cmp #$FFFF
 bne @np
 lda startX
 sta goX
 lda startY
 sta goY
 bra @at
@np:
 cmp #$FFFE
 bne @at
 lda startX                 ; beside the town's portal
 clc
 adc #26
 sta goX
 lda startY
 sta goY
@at:
 lda goX
 asl4
 sta.w ex
 lda goY
 asl4
 sta.w ey
 lda goDir
 sta.w edir
 stz.w est
 stz.w etm
 stz.w eflash
 stz portalT
 stz talkT
 stz appraiseT
 lda #$FFFF
 sta nearshown
 ldx #0
@e:
 sta.w ecur,x
 inx
 inx
 cpx #NACT*2
 bne @e
 ldx #0
@d:
 stz.w dtyp,x
 inx
 inx
 cpx #NDROP*2
 bne @d
 ldx #0
@a:
 stz.w alife,x
 inx
 inx
 cpx #NARROW*2
 bne @a
 ldx #0
@f:
 stz.w fxl,x
 inx
 inx
 cpx #FX_N*2
 bne @f
 ldx #2
@g:
 lda #ST_GONE
 sta.w est,x
 stz.w etm,x
 stz.w ehp,x
 inx
 inx
 cpx #NACT*2
 bne @g
 lda safeArea
 bne @people
 ldx #2                     ; monsters: every third a skeleton archer
@m:
 stz.w ekind,x
 cpx #6
 beq @sk
 cpx #12
 bne @nsk
@sk:
 lda #1
 sta.w ekind,x
@nsk:
 phx
 jsr MonsterSpawn
 plx
 inx
 inx
 cpx #NACT*2
 bne @m
 bra @video
@people:
 jsr PeopleEnter
@video:
 lda placeId
 cmp #PLACE_TRADE
 bne @ns
 jsl $800000+X_ShopStock    ; his wares are new each time the hero comes
@ns:
 jsr PlaceVideo
 lda #MSG_ROW1
 jsr ClearRow
 lda #MSG_ROW2
 jsr ClearRow
 lda #21
 jsr ClearRow
 jsr TalkClear
 lda placeId
 asl
 tax
 lda.w place_names,x
 tax
 jsr Say
 lda #1
 sta rebuild
 sta hudflag
 rts

; the record of place `placeId` into work memory
AreaLoad:
 .a16
 .i16
 lda placeId
 asl
 tax
 sep #$20
 .a8
 lda.w place_page,x
 sta $4831                  ; its megabyte of the data ROM at $D00000
 rep #$20
 .a16
 lda.w place_head,x
 sta aptr
 lda.w place_bank,x
 sta aptr+2
 ldy #0
@h:
 lda [aptr],y
 sta.w mapW,y
 iny
 iny
 cpy #HEAD_WORDS*2
 bne @h
@rec:
 lda [aptr],y               ; source
 sta n0
 iny
 iny
 lda [aptr],y
 and #$00FF
 beq @done
 sta n1
 iny
 lda [aptr],y
 sta n2                     ; the address in bank $7F
 iny
 iny
 lda [aptr],y
 sta n3
 iny
 iny
 lda n2
 sta $2181
 sep #$20
 .a8
 lda #1
 sta $2183
 rep #$20
 .a16
 lda #$8000                 ; a byte at a time into the work memory port
 sta $4300
 lda n0
 sta $4302
 lda n3
 sta $4305
 sep #$20
 .a8
 lda n1
 sta $4304
 lda #1
 sta $420B
 rep #$20
 .a16
 bra @rec
@done:
 rts

; the place's glow tiles and colours (the screen is blank)
PlaceVideo:
 .a16
 .i16
 lda glowBytes
 beq @c                     ; (nowhere yet)
 sta n3
 lda glowSrc
 sta n0
 lda glowSrcBank
 sta n1
 lda #$4C00
 sta n2
 lda #$80
 sta n4
 jsr DmaV
@c:
 jmp InitColors

; ---------------------------------------------------------------- gates: walking in leaves for another place
CheckGates:
 .a16
 .i16
 lda.w ex
 lsr4
 sta tmp0
 lda.w ey
 lsr4
 sta tmp1
 ldy nGates
 beq @r
 ldx #0
@l:
 lda tmp0
 cmp.l $7F0000+W_GATES,x
 bcc @n
 cmp.l $7F0000+W_GATES+4,x
 bcs @n
 lda tmp1
 cmp.l $7F0000+W_GATES+2,x
 bcc @n
 cmp.l $7F0000+W_GATES+6,x
 bcs @n
 lda.l $7F0000+W_GATES+8,x
 sta goPlace
 lda.l $7F0000+W_GATES+10,x
 sta goX
 lda.l $7F0000+W_GATES+12,x
 sta goY
 lda.l $7F0000+W_GATES+14,x
 sta goDir
 jmp Travel
@n:
 txa
 clc
 adc #16
 tax
 dey
 bne @l
@r:
 rts

; fade out, enter goPlace, fade in
Travel:
 .a16
 .i16
 lda #M_TRAVEL
 sta mode
 stz modet
 rts

GameTravel:
 .a16
 .i16
 inc modet
 lda modet
 cmp #TRAVEL_FADE
 bcc @out
 beq @load
 sec                        ; coming back: 1 .. 15
 sbc #TRAVEL_FADE
 cmp #15
 bcc @set
 stz mode
 lda #15
 bra @set
@load:
 jsr SetBright0
 lda closePortal
 beq @nc
 stz portalOn
 stz closePortal
@nc:
 lda goPlace
 jmp EnterPlace
@out:
 lda #15
 sec
 sbc modet
 bpl @set
 lda #0
@set:
 jmp SetBright

SetBright0:
 .a16
 lda #0
SetBright:                   ; A = the picture's brightness, 0 .. 15
 .a16
 sep #$20
 .a8
 sta barsR+3                ; the two lit bands of the bars' table
 sta barsR+5
 rep #$20
 .a16
 rts

; ---------------------------------------------------------------- Town Portal (main.c portal_update)
; Read in the field, a scroll opens a portal there and its twin in the town. Walking into the town's one takes the hero
; back, and both close behind him.
PortalUpdate:
 .a16
 .i16
 lda portalOn
 bne @_far0
 jmp @r
@_far0:
 lda placeId
 cmp portalPlace
 bne @town
 lda portalX
 sta tmp0
 lda portalY
 sta tmp1
 bra @here
@town:
 cmp #PLACE_TOWN
 beq @_far1
 jmp @r
@_far1:
 lda startX
 clc
 adc #26
 sta tmp0
 lda startY
 sec
 sbc #16
 sta tmp1
@here:
 inc portalT
 lda frame
 and #3
 bne @nf
 lda tmp0
 sta px
 lda tmp1
 sta py
 jsl $800000+X_PortalFx
 lda.w ex                   ; (the sparks used the scratch words)
 lsr4
 sta tmp0
 jsr PortalAt
@nf:
 lda portalT
 cmp #PORTAL_ARM
 bcc @r
 jsr PortalAt
 lda.w ex
 lsr4
 sec
 sbc tmp0
 sta tmp0
 lda.w ey
 lsr4
 sec
 sbc tmp1
 sta tmp2
 jsr Dist
 cmp #PORTAL_REACH
 bcs @r
 lda placeId
 cmp #PLACE_TOWN
 beq @back
 lda #PLACE_TOWN
 sta goPlace
 lda #$FFFE
 sta goX
 stz goDir
 jmp Travel
@back:
 lda portalPlace
 sta goPlace
 lda portalX
 sta goX
 lda portalY
 clc
 adc #14
 sta goY
 stz goDir
 lda #1
 sta closePortal
 jmp Travel
@r:
 rts

; the portal seen from where the hero is -> tmp0, tmp1
PortalAt:
 .a16
 lda placeId
 cmp #PLACE_TOWN
 beq @t
 lda portalX
 sta tmp0
 lda portalY
 sta tmp1
 rts
@t:
 lda startX
 clc
 adc #26
 sta tmp0
 lda startY
 sec
 sbc #16
 sta tmp1
 rts

place_names: .word str_graveyard, str_town, str_trade, str_scrip, str_inn
str_graveyard: .byte "THE GRAVEYARD", 0
str_town:      .byte "STORMREACH KEEP", 0
str_trade:     .byte "GIDEON'S TRADING HOUSE", 0
str_scrip:     .byte "THE SCRIPTORIUM", 0
str_inn:       .byte "THE STORM LANTERN", 0
