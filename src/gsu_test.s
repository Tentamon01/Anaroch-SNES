; SuperFX 2 test: clears the left 128 x 128 of the screen bitmap (4bpp, column tiles) and draws 6 pictures from ROM,
; each scaled to its own size. Parameters in the GSU's RAM, per picture: x, y, size, step (8.8), texture address.
PARAMS = $E000
WIDTH  = $E100
COUNT  = 6

start:
  cache
  ibt r0, #0
  ramb
  ibt r0, #TEXBANK
  romb
  ibt r0, #0
  cmode                     ; colour 0 is not plotted
  iwt r1, #0                ; clear 8 KB
  iwt r12, #4096
  iwt r13, clear
  ibt r0, #0
clear:
  stw (r1)
  inc r1
  loop
  inc r1                    ; (delay slot)

  iwt r9, #PARAMS
  ibt r8, #COUNT
picture:
  to r4
  ldw (r9)                  ; x
  inc r9
  inc r9
  to r2
  ldw (r9)                  ; y
  inc r9
  inc r9
  to r10
  ldw (r9)                  ; size: the rows left
  inc r9
  inc r9
  sm (WIDTH), r10
  to r5
  ldw (r9)                  ; step
  inc r9
  inc r9
  to r7
  ldw (r9)                  ; texture
  inc r9
  inc r9
  ibt r11, #0               ; v (8.8)
row:
  from r11
  hib                       ; r0 = v >> 8
  add r0
  add r0
  add r0
  add r0
  add r0                    ; * 32
  to r6
  add r7                    ; the row's address
  move r1, r4
  ibt r3, #0                ; u (8.8)
  lm r12, (WIDTH)
  iwt r13, pixel
pixel:
  from r3
  hib
  to r14
  add r6                    ; r14 changes: the ROM byte is fetched
  with r3
  add r5
  getc
  loop
  plot                      ; (delay slot) plot, x + 1
  with r11
  add r5
  inc r2
  dec r10
  bne row
  nop
  dec r8
  bne picture
  nop
  rpix                      ; flush the last pixels
  stop
  nop
