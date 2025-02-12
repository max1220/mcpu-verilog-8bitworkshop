; This program fills memory from 0x800 to 0xf7f with the address of th memory.
; The screen is memory-mapped there(128x120 pixels, scaled 2x to screen).
.arch mcpu_asm
.org 0x0000
.len 0x4000
start:
  imov 0x800 ALU_A ; start value
  imov 0xf7f ALU_B ; stop value
  imov loop_start I ; loop start
  imov loop_end J ; loop exit
loop_start:
  ; set k = alu_a
  ALU A
  MOV ALU K
  ; set ram[k] = 0x71247
  mov K ADDR
  ;imov 0x71247 RAM
  mov k ram
  ; set k,alu_a = a+1
  alu IMM C ADD
  mov ALU K
  mov K ALU_A
  ; conditional branch to loop_end if a == b
  test A_EQ_B
  cmov J PC
  ; continue loop
  mov i PC
loop_end:
  halt