; ---------------------------------------------------------------- saved games (save.c of the N64 version)
; Three slots in the cartridge's battery memory (the board's save RAM, seen at $70:0000), $2000 bytes apart. Kept is
; only what the player made: level, experience, gold, stats, skills, the belt, worn pieces and the bag; everything else
; is worked out again. Loading puts the hero in Stormreach.
; A slot: 'AG', the version, the checksum of the data, then the data in the order of save_parts.
SRAM = $700000
SAVE_SLOTS = 3
SAVE_VERSION = 1
SAVE_MAGIC = $4741           ; 'AG'
SAVE_BYTES = 17 * 2 + 72 + 51 * ITEM_BYTES
VIEW_PAUSE = 0
VIEW_SAVE = 1
VIEW_LOAD = 2
VIEW_START = 3               ; at power on, when a game is saved: load one, or a new game
SAVE_ROW = 8

; what is kept: address in work memory, bytes
save_parts:
 .word level, 2, gold, 2, xp, 2, xph, 2, strb, 2, defb, 2, lifeb, 2, sDex, 2, sEne, 2, points, 2, skillPts, 2
 .word heroFlags, 2, kills, 2, beltsel, 2, skActive, 2, casting, 2, skCur, 2
 .word skRank, 72, ITEMS & $FFFF, 51 * ITEM_BYTES
 .word 0, 0

SlotBase:                    ; A = a slot -> X = where it lies
 .a16
 xba
 asl
 asl
 asl
 asl
 asl
 tax
 rts

; the checksum of the data of the slot at X (as save.c: s * 31 + each) -> A
SlotSum:
 .a16
 .i16
 phx
 lda #SAVE_BYTES / 2
 sta q2
 lda #$A5A5
 sta q3
@l:
 lda q3
 asl
 asl
 asl
 asl
 asl
 sec
 sbc q3
 clc
 adc.l SRAM+6,x
 sta q3
 inx
 inx
 dec q2
 bne @l
 plx
 lda q3
 rts

; A = a slot -> carry set when a good game lies in it
SlotValid:
 .a16
 .i16
 jsr SlotBase
 lda.l SRAM,x
 cmp #SAVE_MAGIC
 bne @no
 lda.l SRAM+2,x
 cmp #SAVE_VERSION
 bne @no
 jsr SlotSum
 cmp.l SRAM+4,x
 bne @no
 sec
 rts
@no:
 clc
 rts

; carry set when any slot holds a game
AnySave:
 .a16
 .i16
 lda #SAVE_SLOTS - 1
 sta q0
@l:
 lda q0
 jsr SlotValid
 bcs @r
 dec q0
 bpl @l
 clc
@r:
 rts

; A = a slot: the game into it -> carry set when it reads back good
SaveSlot:
 .a16
 .i16
 sta q0
 jsr SlotBase
 lda #0
 sta.l SRAM,x               ; (not a game until it is all there)
 stx q1                     ; the slot
 txy
 ldx #0                     ; the part
@p:
 lda.l save_parts+2,x
 beq @done
 lsr
 sta q2                     ; words
 lda.l save_parts,x
 phx
 tax
@w:
 lda.l $7E0000,x
 phx
 tyx
 sta.l SRAM+6,x
 plx
 inx
 inx
 iny
 iny
 dec q2
 bne @w
 plx
 inx
 inx
 inx
 inx
 bra @p
@done:
 ldx q1
 jsr SlotSum
 sta.l SRAM+4,x
 lda #SAVE_VERSION
 sta.l SRAM+2,x
 lda #SAVE_MAGIC
 sta.l SRAM,x
 lda q0
 jmp SlotValid

; A = a slot holding a good game: it becomes the hero's
LoadSlot:
 .a16
 .i16
 pha
 jsr NewKit                 ; (every piece and number cleared first)
 pla
 jsr SlotBase
 txy
 ldx #0
@p:
 lda.l save_parts+2,x
 beq @done
 lsr
 sta q2
 lda.l save_parts,x
 phx
 tax
@w:
 phx
 tyx
 lda.l SRAM+6,x
 plx
 sta.l $7E0000,x
 inx
 inx
 iny
 iny
 dec q2
 bne @w
 plx
 inx
 inx
 inx
 inx
 bra @p
@done:
 lda #$FFFF
 sta casting
 jsr BagRebuild
 jsr StatsRecalc
 lda maxStam
 sta stam
 lda.w emaxhp
 sta.w ehp
 rts

; ---------------------------------------------------------------- the screens (page 3 of the bag screen)
PauseOpen:                   ; Start, while playing
 .a16
 .i16
 lda #VIEW_PAUSE
 stz saveCur
 bra SaveOpen
StartScreen:                 ; at power on
 .a16
 .i16
 stz saveCur
 lda #SAVE_SLOTS - 1        ; the cursor on the first saved game
 sta q0
@l:
 lda q0
 jsr SlotValid
 bcc @n
 lda q0
 sta saveCur
@n:
 dec q0
 bpl @l
 lda #VIEW_START
SaveOpen:
 .a16
 .i16
 sta saveView
 stz saveArm
 stz msgp
 lda #M_BAG
 sta mode
 lda #3
 sta bagPage
 jsr MenuBegin
 jsr MenuColours
 jsr SaveDraw
 jmp MenuShow

; the bag screen's colours (the screen is blank)
MenuColours:
 .a16
 .i16
 ldx #0
 sep #$20
 .a8
 stz $2121
@col:
 lda.l menu_pal,x
 sta $2122
 inx
 cpx #256
 bne @col
 rep #$20
 .a16
 rts

; the lines the cursor goes over
SaveLines:
 .a16
 lda saveView
 cmp #VIEW_START
 bne @r
 lda #SAVE_SLOTS + 1        ; the slots and "new game"
 rts
@r:
 lda #SAVE_SLOTS            ; (three here too: resume, save, load / the slots)
 rts

SaveDraw:
 .a16
 .i16
 ldx #2046
 lda #0
@b:
 sta.l MENUMAP,x
 dex
 dex
 bpl @b
 jsl FarClearText
 lda saveView
 asl
 tax
 lda.l view_title,x
 jsr Note0
 lda #4 * 32 + 8
 ldy #$0400 | HUD_PRIO
 jsr Show
 stz s7                     ; the line
@row:
 lda s7
 asl
 clc
 adc s7                     ; three rows apart
 clc
 adc #SAVE_ROW
 asl4
 asl
 sta s9
 lda saveView
 bne @slots
 lda s7                     ; the pause menu
 asl
 tax
 lda.l pause_item,x
 jsr Note0
 bra @show
@slots:
 lda s7
 cmp #SAVE_SLOTS
 bcc @slot
 lda #str_newgame
 jsr Note0
 bra @show
@slot:
 lda #str_slot
 jsr Note0
 lda s7
 inc a
 jsr AppendNum
 lda s7
 jsr SlotValid
 bcs @used
 lda #str_empty_slot
 jsr Append
 bra @show
@used:
 phx
 lda #str_level_s
 jsr Append
 plx
 lda.l SRAM+6,x             ; the level, the gold
 phx
 jsr AppendNum
 lda #str_gold_s
 jsr Append
 plx
 lda.l SRAM+8,x
 jsr AppendNum
@show:
 ldy #HUD_PRIO
 lda s7
 cmp saveCur
 bne @plain
 ldy #$0400 | HUD_PRIO
@plain:
 lda s9
 clc
 adc #3
 jsr Show
 lda s7
 cmp saveCur
 bne @next
 jsr NameStart
 lda #62                    ; '>'
 jsr AppendChar
 lda s9
 clc
 adc #1
 ldy #$0400 | HUD_PRIO
 jsr Show
@next:
 inc s7
 jsr SaveLines
 cmp s7
 beq @listed
 jmp @row
@listed:
 lda msgp
 beq @h
 jsr Note0
 ldy #HUD_PRIO | $0400
 bra @s
@h:
 lda saveView
 asl
 tax
 lda.l view_hint,x
 jsr Note0
 ldy #HUD_PRIO | $1400
@s:
 lda #HINT_Y * 32 + 1
 jsr Show
 lda #1
 sta menuDirty
 rts

SaveInput:
 .a16
 .i16
 lda padnew
 and #PAD_UP
 beq @nu
 lda saveCur
 beq @r
 dec saveCur
 bra @moved
@nu:
 lda padnew
 and #PAD_DOWN
 beq @nd
 jsr SaveLines
 dec a
 cmp saveCur
 beq @r
 inc saveCur
@moved:
 stz msgp
 stz saveArm
 jmp SaveDraw
@nd:
 lda padnew
 and #PAD_B | PAD_START
 beq @nb
 lda saveView
 cmp #VIEW_START
 beq @r                     ; (at power on one must choose)
 cmp #VIEW_PAUSE
 beq @close
 lda saveView               ; back to the pause menu, on the line it came from
 sta saveCur
 stz saveView
 stz msgp
 stz saveArm
 jmp SaveDraw
@close:
 jmp BagClose
@nb:
 lda padnew
 and #PAD_A
 bne @a
@r:
 rts
@a:
 lda saveView
 beq @pause
 cmp #VIEW_SAVE
 beq @save
 lda saveCur                ; load, or at power on
 cmp #SAVE_SLOTS
 bcs @close                 ; a new game: it is already begun
 jsr SlotValid
 bcc @r
 lda saveCur
 jsr LoadSlot
 jsr BagClose
 jsl FarRise                ; into Stormreach
 rts
@pause:
 lda saveCur
 beq @close
 sta saveView               ; 1 save, 2 load: the views of the same numbers
 stz saveCur
 stz msgp
 stz saveArm
 jmp SaveDraw
@save:
 lda saveCur                ; a game already there is replaced at the second press
 jsr SlotValid
 bcc @write
 lda saveCur
 inc a
 cmp saveArm
 beq @write
 sta saveArm
 lda #str_replace
 sta msgp
 jmp SaveDraw
@write:
 stz saveArm
 lda saveCur
 jsr SaveSlot
 lda #str_saved
 bcs @said
 lda #str_cannot
@said:
 sta msgp
 lda #SFX_PICK
 jsl FarSfx
 jmp SaveDraw

view_title: .word str_paused_t, str_save_t, str_load_t, str_start_t
view_hint:  .word str_h_pause, str_h_save, str_h_load, str_h_start
pause_item: .word str_resume, str_save_i, str_load_i
str_paused_t:   .byte "PAUSED", 0
str_save_t:     .byte "SAVE THE GAME", 0
str_load_t:     .byte "LOAD A GAME", 0
str_start_t:    .byte "ANAROCH", 0
str_resume:     .byte "RESUME", 0
str_save_i:     .byte "SAVE GAME", 0
str_load_i:     .byte "LOAD GAME", 0
str_newgame:    .byte "NEW GAME", 0
str_slot:       .byte "SLOT ", 0
str_empty_slot: .byte "  EMPTY", 0
str_level_s:    .byte "  LEVEL ", 0
str_gold_s:     .byte "  GOLD ", 0
str_h_pause:    .byte "A CHOOSE  B RESUME", 0
str_h_save:     .byte "A SAVE HERE  B BACK", 0
str_h_load:     .byte "A LOAD  B BACK", 0
str_h_start:    .byte "A CHOOSE", 0
str_replace:    .byte "A AGAIN TO REPLACE IT", 0
str_saved:      .byte "SAVED", 0
str_cannot:     .byte "THE CARTRIDGE COULD NOT SAVE", 0
