; ---------------------------------------------------------------- tables and words
bit_tab:    .word 1, 2, 4, 8, 16, 32, 64, 128
hi_large:   .word 2, 8, 32, 128
hi_x8:      .word 1, 4, 16, 64
ex_tile:    .word $84, $86, $88, $8A, $8C, $8E, $A4, $A6, $A8
ex_vram:    .word $6840, $6860, $6880, $68A0, $68C0, $68E0, $6A40, $6A60, $6A80
slot_tile:  .word $00, $04, $08, $0C, $40, $44, $48, $4C, $80
slot_vram:  .word $6000, $6040, $6080, $60C0, $6400, $6440, $6480, $64C0, $6800
dir_of:     .word $FFFF, 6, 2, $FFFF, 0, 7, 1, $FFFF, 4, 5, 3, $FFFF, $FFFF, $FFFF, $FFFF, $FFFF
arrow_tile: .word $C6, $C8, $CA, $CC, $CE, $E0, $E2, $E4
drop_tile:  .word $C2, $C0, $C4          ; by type: gold, (a piece: DropTile), a tome

str_paused:      .byte "PAUSED", 0
str_died:        .byte "YOU HAVE DIED", 0
str_rise:        .byte "PRESS START TO RISE AGAIN", 0
str_empty:       .byte "EMPTY SLOT", 0
str_full:        .byte "FULL LIFE", 0
str_beltfull:    .byte "BELT FULL", 0
str_tome_read:   .byte "+1 STAT POINT", 0
str_pick_potion: .byte "A  PICK UP HEALING POTION", 0
str_pick_tome:   .byte "A  PICK UP TOME OF INSIGHT", 0
str_points:      .byte "STAT POINTS (SELECT)", 0
str_level:       .byte "LEVEL", 0
str_exp:         .byte "EXPERIENCE", 0
str_life:        .byte "LIFE", 0
str_strength:    .byte "STRENGTH", 0
str_defense:     .byte "DEFENSE", 0
str_damage:      .byte "DAMAGE", 0
str_gold:        .byte "GOLD", 0
str_kills:       .byte "KILLS", 0
str_lag:         .byte "SLOWDOWNS", 0
str_busy:        .byte "BUSY", 0
str_points_left: .byte "STAT POINTS", 0
