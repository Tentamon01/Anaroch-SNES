; ---------------------------------------------------------------- the townspeople (main.c npcs_enter / update, npc_talk)
; They stand in the monsters' places with the state ST_NPC, which every blow, arrow and spell passes by.
; kind = KIND_PEOPLE + who; ehome = where they belong, estk = how far they wander, ecool = how long they still wait,
; ewx / ewy / ewt = where they walk and for how long, ealert = walking, elost = which of their words comes next
KIND_PEOPLE = 3
NPC_SEES = 42                ; 2.6 m: it stops and turns to the hero
NPC_REACH = 38               ; 2.4 m: near enough to talk
TALK_ROW = 3
TALK_TIME = 330
ROLE_TALK = 0
ROLE_SHOP = 1
ROLE_APPRAISE = 2

PeopleEnter:
 .a16
 .i16
 stz tmpC
@l:
 lda tmpC
 cmp nPeople
 bcc @go
 rts
@go:
 inc a                      ; the actor: 1 on
 asl
 tax
 lda tmpC
 asl
 asl
 asl
 tay
 phx
 tyx
 lda.l $7F0000+W_PEOPLE,x   ; who
 sta tmp0
 lda.l $7F0000+W_PEOPLE+2,x
 sta tmp1
 lda.l $7F0000+W_PEOPLE+4,x
 sta tmp2
 lda.l $7F0000+W_PEOPLE+6,x
 sta tmp3
 plx
 lda tmp0
 clc
 adc #KIND_PEOPLE
 sta.w ekind,x
 lda tmp1
 sta.w ehomex,x
 sta.w ewx,x
 asl4
 sta.w ex,x
 lda tmp2
 sta.w ehomey,x
 sta.w ewy,x
 asl4
 sta.w ey,x
 lda tmp3
 sta.w estk,x
 lda #ST_NPC
 sta.w est,x
 stz.w ealert,x
 stz.w elost,x
 stz.w echamp,x
 stz.w ewt,x
 stz.w estun,x
 stz.w echill,x
 lda #180
 jsr RandRange
 clc
 adc #30
 sta.w ecool,x
 lda #8
 jsr RandRange
 sta.w edir,x
 inc tmpC
 jmp @l

; their pictures' colours: sprite palettes 1.. (no monsters are about)
PeoplePals:
 .a16
 .i16
 lda safeArea
 beq @r
 stz tmpC
@l:
 lda tmpC
 cmp nPeople
 bcs @r
 asl
 asl
 asl
 tax
 lda.l $7F0000+W_PEOPLE,x
 asl                        ; 32 bytes a person
 asl
 asl
 asl
 asl
 clc
 adc #npc_pals
 sta n0
 stz n1
 lda tmpC
 inc a
 asl4
 clc
 adc #128
 sta n2
 lda #32
 sta n3
 jsr DmaC
 inc tmpC
 bra @l
@r:
 rts

; X = a person (twice its actor)
NpcUpdate:
 .a16
 .i16
 inc.w etm,x
 jsr RelHero
 cmp #NPC_SEES
 bcs @free
 jsr DirFrom
 cmp #$FFFF
 bne @_far3
 jmp @stand
@_far3:
 sta.w edir,x
 jmp @stand
@free:
 lda.w ecool,x
 beq @walk
 dec.w ecool,x
 beq @_far5
 jmp @stand
@_far5:
 lda.w estk,x               ; done waiting: somewhere near home
 asl
 inc a
 cmp #256
 bcc @s
 lda #255
@s:
 sta tmpC
 jsr RandRange
 sec
 sbc.w estk,x
 clc
 adc.w ehomex,x
 sta.w ewx,x
 lda tmpC
 jsr RandRange
 sec
 sbc.w estk,x
 clc
 adc.w ehomey,x
 sta.w ewy,x
 lda #300
 sta.w ewt,x
 jmp @stand
@walk:
 lda.w ewt,x
 beq @wait
 dec.w ewt,x
 lda.w ex,x
 lsr4
 sta tmp1
 lda.w ewx,x
 sec
 sbc tmp1
 sta tmp0
 lda.w ey,x
 lsr4
 sta tmp1
 lda.w ewy,x
 sec
 sbc tmp1
 sta tmp2
 jsr Dist
 cmp #3
 bcc @wait
 jsr Rot
 jsr DirFrom
 cmp #$FFFF
 beq @wait
 sta.w edir,x
 asl
 tay
 lda.w wspd_wx,y
 sta tmpC
 lda.w wspd_wy,y
 sta tmpD
 lda.w ex,x
 sta us0
 lda.w ey,x
 sta us1
 jsr MoveEnt
 lda.w ex,x
 cmp us0
 bne @moved
 lda.w ey,x
 cmp us1
 beq @wait                  ; in the way: think of somewhere else
@moved:
 lda #1
 sta.w ealert,x
 lda.w eanimt,x
 clc
 adc #8
 sta.w eanimt,x
 rts
@wait:
 lda #240
 jsr RandRange
 clc
 adc #120
 sta.w ecool,x
@stand:
 stz.w ealert,x
 rts

; -> A = the person near enough to talk to (twice its actor) with bit 15 set, or $FFFF
NearPerson:
 .a16
 .i16
 lda #NPC_REACH
 sta tmpC
 lda #$FFFF
 sta tmpB
 lda safeArea
 beq @r
 ldx #2
@l:
 lda.w est,x
 cmp #ST_NPC
 bne @n
 jsr RelHero
 cmp tmpC
 bcs @n
 sta tmpC
 txa
 ora #$8000
 sta tmpB
@n:
 inx
 inx
 cpx #NACT*2
 bne @l
@r:
 lda tmpB
 rts

; the prompt's words for the person in nearshown
PersonPrompt:
 .a16
 .i16
 lda nearshown
 and #$7FFF
 tax
 lda.w ekind,x
 sec
 sbc #KIND_PEOPLE
 asl
 tax
 lda.w person_prompt,x
 tax
 lda #21
 ldy #$0400|HUD_PRIO
 jmp PrintCenter

; X = the person (twice its actor): the A button by them
Talk:
 .a16
 .i16
 stx talkWith
 lda.w ekind,x
 sec
 sbc #KIND_PEOPLE
 sta talkWho
 asl
 tax
 lda.w person_role,x
 cmp #ROLE_SHOP
 bne @ns
 jsr TalkClear
 jsl $800000+X_ShopOpen
 rts
@ns:
 cmp #ROLE_APPRAISE
 beq @appraise
 jsr TalkName
 lda talkWho                ; their words, each in turn
 asl
 tax
 lda.w person_talkn,x
 sta tmpA
 ldx talkWith
 lda.w elost,x
 inc.w elost,x
 cmp tmpA
 bcc @in
 stz.w elost,x
 inc.w elost,x
 lda #0
@in:
 asl                        ; four lines each
 asl
 asl
 sta tmpB
 lda talkWho
 asl
 tax
 lda.w person_talk,x
 clc
 adc tmpB
 sta talkLine
 stz talkI
@l:
 lda talkI
 asl
 tay
 lda (talkLine),y
 beq @done
 tax
 lda talkI
 clc
 adc #TALK_ROW+1
 ldy #HUD_PRIO
 jsr PrintCenter
 inc talkI
 lda talkI
 cmp #4
 bcc @l
@done:
 lda #TALK_TIME
 sta talkT
 rts
@appraise:
 jsr TalkName
 jsl $800000+X_Appraise     ; its first line in namebuf -> A = what comes under it
 asl
 sta talkI
 lda #TALK_ROW+1
 ldx #namebuf
 ldy #HUD_PRIO
 jsr PrintCenter
 ldx talkI
 lda.w appraise_under,x
 beq @done
 tax
 lda #TALK_ROW+2
 ldy #HUD_PRIO
 jsr PrintCenter
 bra @done

TalkName:
 .a16
 .i16
 jsr TalkClear
 lda talkWho
 asl
 tax
 lda.w person_name,x
 tax
 lda #TALK_ROW
 ldy #$0400|HUD_PRIO
 jmp PrintCenter

TalkClear:
 .a16
 .i16
 stz talkT
 lda #TALK_ROW
 sta talkI
@l:
 lda talkI
 jsr ClearRow
 inc talkI
 lda talkI
 cmp #TALK_ROW+5
 bcc @l
 rts

; once a frame in a safe place: the words go when their time is up or the hero walks off
TalkUpdate:
 .a16
 .i16
 lda appraiseT
 beq @t
 dec appraiseT
@t:
 lda talkT
 beq @r
 dec talkT
 beq @clear
 ldx talkWith
 jsr RelHero
 cmp #80                    ; 5 m
 bcc @r
@clear:
 jmp TalkClear
@r:
 rts

appraise_under: .word 0, str_ask_again, 0, 0
str_ask_again: .byte "ASK AGAIN AND I WILL READ", 0
.include "../people.inc"                  ; names, trades and words (tools/build_rules.py, from the N64 version)
