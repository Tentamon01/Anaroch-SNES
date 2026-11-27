; ---------------------------------------------------------------- sprites
; FrameId: X = actor -> A = direction * 15 + pose (0-1 idle, 2-5 walk, 6-9 attack, 10 hit, 11-14 death)
FrameId:
 .a16
 .i16
 lda.w est,x
 asl
 tay
 lda fid_jt,y
 sta jmpv
 jmp (jmpv)
fid_jt: .word FidIdle, FidWalk, FidAtk, FidHit, FidDead, FidIdle
FidIdle:
 lda.w etm,x
 lsr4
 lsr2
 and #1
 jmp FidGo
FidWalk:
 lda.w eanimt,x
 xba
 and #3
 clc
 adc #2
 jmp FidGo
FidHit:
 lda #10
 jmp FidGo
FidDead:
 lda.w etm,x                ; 2.4 s over the 4 pictures, then the body
 sta tmp0
 asl
 asl
 asl
 sec
 sbc tmp0
 xba
 and #$00FF
 cmp #3
 bcc @d
 lda #3
@d:
 clc
 adc #11
 jmp FidGo
FidAtk:
 lda.w ekind,x
 beq @g
 cmp #1
 beq @k
 lda.w etm,x                ; the hero: 45 frames (etm * 23 / 256)
 sta tmp0
 asl4
 sta tmp1
 lda tmp0
 asl
 asl
 asl
 clc
 adc tmp1
 sec
 sbc tmp0
 xba
 and #$00FF
 bra @c
@g:
 lda.w etm,x                ; the ghoul: 60 frames
 lsr4
 bra @c
@k:
 lda.w etm,x                ; the skeleton: 42 frames
 sta tmp0
 asl
 clc
 adc tmp0
 lsr4
 lsr
@c:
 cmp #3
 bcc @o
 lda #3
@o:
 clc
 adc #6
FidGo:
 sta tmp0
 lda #8
 sec
 sbc.w edir,x
 and #7
 sta tmp1
 asl4
 sec
 sbc tmp1
 clc
 adc tmp0
 rts

; MetaAt: X = actor -> X = its picture's place in fmeta (the actor is left on the stack)
MetaAt:
 .a16
 .i16
 lda.w ekind,x
 asl
 tay
 lda.w ecur,x
 asl
 asl
 clc
 adc.w meta_base,y
 ply                        ; (the return address)
 phx
 phy
 tax
 rts

; a byte (low half of A) with its sign
Signed:
 .a16
 and #$00FF
 cmp #$0080
 bcc @r
 ora #$FF00
@r:
 rts

QueueUploads:
 .a16
 .i16
 stz nq
 stz oq_n
 ldx #0
@l:
 lda nq
 cmp uplim
 bcs @done
 lda.w est,x
 cmp #ST_GONE
 beq @n
 jsr FrameId
 cmp.w ecur,x
 beq @n
 jsr Enqueue
@n:
 inx
 inx
 cpx #NACT*2
 bne @l
@done:
 rts

; Enqueue: X = actor, A = frame id
Enqueue:
 .a16
 .i16
 sta tmp2
 sta.w ecur,x
 asl
 clc
 adc tmp2
 tay
 stz tmp4
 lda.w ekind,x
 beq @g
 cmp #1
 beq @k
 lda.w hero_ptrs,y
 sta tmp3
 lda.w hero_ptrs+2,y
 bra @q
@g:
 lda.w ghoul_ptrs,y
 sta tmp3
 lda.w ghoul_ptrs+2,y
 bra @q
@k:
 lda.w skel_ptrs,y
 sta tmp3
 lda.w skel_ptrs+2,y
@q:
 and #$00FF
 sta tmp4
 lda nq
 asl
 sta tmp5
 asl
 clc
 adc tmp5
 tay
 lda tmp3
 sta.w qbuf,y
 lda tmp4
 sta.w qbuf+2,y
 lda.w slot_vram,x
 sta.w qbuf+4,y
 inc nq
 jsr MetaAt                 ; the extra piece follows the square's 512 bytes
 lda.l fmeta+2,x
 plx
 and #$00FF
 cmp #$0080
 beq @none
 lda oq_n
 asl
 sta tmp5
 asl
 clc
 adc tmp5
 tay
 lda tmp3
 clc
 adc #512
 sta.w oq,y
 lda tmp4
 sta.w oq+2,y
 lda.w ex_vram,x
 sta.w oq+4,y
 inc oq_n
@none:
 rts

BuildOam:
 .a16
 .i16
 ldx #0
 lda #$E000
@c:
 sta.w oam,x
 inx
 inx
 inx
 inx
 cpx oamprev
 bcc @c
 ldx #0
 lda #0
@h:
 sta.w oam+512,x
 inx
 inx
 cpx #32
 bne @h
 stz oamn
 lda camx                   ; the middle of the screen in picture space less the projection's offset
 clc
 adc #128-PIC_KX
 sta flx
 lda camy
 clc
 adc #112-PIC_KY
 sta fly
 stz ol_n
 stz ndyn                   ; the things that move, sorted by depth
 ldx #0
@ac:
 lda.w est,x
 cmp #ST_GONE
 beq @an
 cpx #0
 beq @vis
 lda.w eflash,x             ; a monster struck blinks
 beq @vis
 lda frame
 and #2
 bne @an
@vis:
 lda.w ex,x
 lsr4
 sta tmp0
 lda.w ey,x
 lsr4
 sta tmp2
 txa
 jsr AddDyn
 jsr Occlude
@an:
 inx
 inx
 cpx #NACT*2
 bne @ac
 ldx #0
@ar:
 lda.w alife,x
 beq @arn
 lda.w ax,x
 lsr4
 sta tmp0
 lda.w ay,x
 lsr4
 sta tmp2
 txa
 ora #$0100
 jsr AddDyn
@arn:
 inx
 inx
 cpx #NARROW*2
 bne @ar
 ldx #0
@dr:
 lda.w dtyp,x
 beq @drn
 lda.w dpx,x
 sta tmp0
 lda.w dpy,x
 sta tmp2
 txa
 ora #$0200
 jsr AddDyn
@drn:
 inx
 inx
 cpx #NDROP*2
 bne @dr
 stz dpos
 jsr EmitProps
 lda #0                     ; what is left of the moving things
 jsr FlushDyn
 lda oamn
 sta oamprev
 rts

; AddDyn: tmp0 / tmp2 = world px, A = what (0 actor, 1 arrow, 2 loot | its offset); inserted by depth, nearest first
AddDyn:
 .a16
 .i16
 sta tmp9
 jsr Rot
 lda tmp0
 sec
 sbc flx
 sta tmp0
 lda tmp2
 sec
 sbc fly
 clc
 adc #$4000                 ; (the key: depth + $4000, compared unsigned)
 sta tmp2
AddDynRaw:                  ; (tmp0 = x, tmp2 = key, tmp9 = what)
 ldy ndyn
@ins:
 cpy #0
 beq @put
 lda.w dyn_key-2,y
 cmp tmp2
 bcs @put
 sta.w dyn_key,y
 lda.w dyn_rx-2,y
 sta.w dyn_rx,y
 lda.w dyn_ref-2,y
 sta.w dyn_ref,y
 dey
 dey
 bra @ins
@put:
 lda tmp2
 sta.w dyn_key,y
 lda tmp0
 sta.w dyn_rx,y
 lda tmp9
 sta.w dyn_ref,y
 lda ndyn
 clc
 adc #2
 sta ndyn
 rts

; FlushDyn: A = a depth key; emits the moving things at least that near. X kept
FlushDyn:
 .a16
 .i16
 sta tmpA
 phx
@l:
 ldy dpos
 cpy ndyn
 bcc @more
 jmp @r
@more:
 lda.w dyn_key,y
 cmp tmpA
 bcs @take
 jmp @r
@take:
 sec
 sbc #$4000
 sta tmpD
 lda.w dyn_rx,y
 sta tmpC
 lda.w dyn_ref,y
 sta tmpB
 iny
 iny
 sty dpos
 jsr Project
 bcc @vis
 jmp @l
@vis:
 lda tmpB
 xba
 and #$00FF
 beq @actor
 cmp #1
 beq @arrow
 cmp #3
 bne @loot
 lda tmpB                   ; a walk-behind block
 and #$00FF
 tax
 lda.w ol_y,x
 sta tmp1
 lda.w ol_t,x
 sta tmp3
 lda ps
 sta tmp0
 stz tmp4
 jsr EmitOne
 jmp @l
@loot:
 lda tmpB                   ; loot
 and #$00FF
 tax
 lda.w dtyp,x
 cmp #2
 bne @plainloot
 txa
 jsl $800000+X_DropTile
 bra @loottile
@plainloot:
 asl
 tay
 lda.w drop_tile-2,y
@loottile:
 sta tmp3
 lda pl
 sec
 sbc #9
 sta tmp1
 bra @small
@arrow:
 lda tmpB
 and #$00FF
 tax
 lda.w adir,x
 asl
 tay
 lda.w arrow_tile,y
 sta tmp3
 lda pl
 sec
 sbc #23
 sta tmp1
@small:
 lda ps
 sec
 sbc #8
 sta tmp0
 lda #$2E00                 ; palette 7, priority 2
 ora tmp3
 sta tmp3
 stz tmp4
 jsr EmitOne
 jmp @l
@actor:
 lda tmpB
 and #$00FF
 tax
 jsr EmitActor
 jmp @l
@r:
 plx
 rts

; Project: tmpC = x, tmpD = depth from the focus (camera px) -> ps = screen x, pl = screen line; carry set when out of view
Project:
 .a16
 .i16
 lda tmpD
 clc
 adc #112
 sta pl
 lda tmpC
 clc
 adc #128
 sta ps
 clc
 rts

; (the scenery is part of the world picture now)
EmitProps:
 rts

; EmitActor: X = actor, ps / pl = its feet on screen
EmitActor:
 .a16
 .i16
 lda.w ecur,x
 cmp #FRAMES*8
 bcc @have
 rts                        ; no picture of it in video memory yet
@have:
 jsr MetaAt
 lda.l fmeta,x
 sta tmp5                   ; the square's shift
 lda.l fmeta+2,x
 sta tmp6                   ; the extra piece's
 plx
 lda tmp5
 jsr Signed
 clc
 adc ps
 sec
 sbc #16
 sta tmp0
 lda tmp5
 xba
 jsr Signed
 clc
 adc pl
 sec
 sbc #31
 sta tmp1
 lda.w eflash,x             ; palette: the hero 0 (5 struck), ghoul 1 / skeleton 2 (champions 3 / 4)
 beq @nf
 cpx #0
 bne @nf
 lda #5
 bra @pal
@nf:
 lda #0
 cpx #0
 beq @pal
 lda.w ekind,x
 inc a
 ldy.w echamp,x
 beq @pal
 inc a
 inc a
@pal:
 asl
 ora #$20                   ; priority 2
 xba
 ora slot_tile,x
 sta tmp3
 lda #2
 sta tmp4                   ; large
 jsr EmitOne
 lda tmp6
 and #$00FF
 cmp #$0080
 bne @extra
 rts
@extra:
 lda tmp3
 and #$FF00
 ora.w ex_tile,x
 sta tmp3
 lda tmp6
 jsr Signed
 clc
 adc ps
 sec
 sbc #16
 sta tmp0
 lda tmp6
 xba
 jsr Signed
 clc
 adc pl
 sec
 sbc #31
 sta tmp1
 stz tmp4                   ; small
EmitOne:
 lda tmp0
 clc
 adc #32
 cmp #288
 bcs @out
 lda tmp1
 clc
 adc #32
 cmp #256
 bcs @out
 ldy oamn
 cpy #512
 bcs @out
 lda tmp1
 and #$00FF
 xba
 sta tmp2
 lda tmp0
 and #$00FF
 ora tmp2
 sta.w oam,y
 lda tmp3
 sta.w oam+2,y
 lda oamn                   ; the high table: x bit 8 and the size, 2 bits a sprite
 and #$000C
 lsr
 tay
 lda tmp4
 beq @sm
 lda.w hi_large,y
@sm:
 sta tmp4
 lda tmp0
 and #$0100
 beq @x8
 lda.w hi_x8,y
 ora tmp4
 sta tmp4
@x8:
 lda tmp4
 beq @s
 lda oamn
 lsr4
 tay
 lda.w oam+512,y
 ora tmp4
 sta.w oam+512,y
@s:
 lda oamn
 clc
 adc #4
 sta oamn
@out:
 rts
