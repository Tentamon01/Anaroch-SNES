; ---------------------------------------------------------------- main loop
MainLoop:
 .a16
 .i16
 inc frame
 lda padraw
 sta pad
 eor padold
 and pad
 sta padnew
 lda pad
 sta padold
 lda mode
 asl
 tax
 lda mode_jt,x
 sta jmpv
 jsr @go
 lda mode
 cmp #M_BAG
 bne @world
 jsr SfxSend                ; the bag screen: only its buttons and sounds
 lda #1
 sta ready
 jsr WaitVbl
 jmp MainLoop
@world:
 jsr UpdateCam
 lda rebuild
 beq @stream
 stz rebuild
 jsr FullMap
 stz lagc
 bra @oam
@stream:
 jsr UpdateStream
@oam:
 lda hudflag
 beq @nh
 stz hudflag
 jsr HudRefresh
@nh:
 jsr QueueUploads
 jsr BuildOam
 jsr SfxSend
 lda #1
 sta ready
 jsr WaitVbl
 jmp MainLoop
@go:
 jmp (jmpv)

mode_jt: .word GamePlay, GameDead, GamePause, GameStats, GameBag

GamePlay:
 .a16
 .i16
 lda padnew
 and #PAD_START
 beq @np
 lda #M_PAUSE
 sta mode
 lda #MSG_ROW1
 ldx #str_paused
 ldy #$0000|HUD_PRIO
 jmp PrintCenter
@np:
 lda padnew
 and #PAD_SELECT
 beq @ns
 jsl $800000+X_BagOpen
 rts
@ns:
 lda hitstop
 beq @run
 dec hitstop
 rts
@run:
 jsr UpdateHero
 lda mode
 cmp #M_BAG
 beq @bag
 jmp UpdateWorld
@bag:
 rts

GameBag:
 .a16
 .i16
 jsl $800000+X_BagInput
 rts

UpdateWorld:
 .a16
 .i16
 ldx #2
@m:
 phx
 jsr UpdateMonster
 plx
 inx
 inx
 cpx #NACT*2
 bne @m
 jsr UpdateArrows
 jsr UpdateDrops
 lda sayt
 beq @r
 dec sayt
 bne @r
 lda #20
 jsr ClearRow
@r:
 rts

GameDead:
 .a16
 .i16
 inc.w etm
 stz.w eflash
 jsr UpdateWorld
 inc modet
 lda modet
 cmp #150
 bne @w
 lda #MSG_ROW1
 ldx #str_died
 ldy #$0400|HUD_PRIO
 jsr PrintCenter
 lda #MSG_ROW2
 ldx #str_rise
 ldy #$0000|HUD_PRIO
 jsr PrintCenter
@w:
 lda modet
 cmp #150
 bcc @r
 lda padnew
 and #PAD_START
 beq @r
 lda #MSG_ROW1
 jsr ClearRow
 lda #MSG_ROW2
 jsr ClearRow
 jsr RiseAgain
@r:
 rts

GamePause:
 .a16
 lda padnew
 and #PAD_START
 beq @r
 lda #MSG_ROW1
 jsr ClearRow
 stz mode
@r:
 rts
