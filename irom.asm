; This program fills memory from 0x800 to 0xf7f with the address of th memory.
; The screen is memory-mapped there(128x120 pixels, scaled 2x to screen).
.arch mcpu_asm
.org 0x0000
.len 0x4000
start:
  ; setup CTL_CONFIG
  imov 0x9fff addr
  imov 0x00 ram
  ; setup CTL_COLOR0
  imov 0x9ffe addr
  imov 0x01 ram
  ; setup CTL_COLOR1
  imov 0x9ffd addr
  imov 0x02 ram
  ; setup CTL_BORDER
  imov 0x9ffc addr
  imov 0x04 ram

  ; write hello in ascii text
  imov 0x8000 addr
  imov 72 ram
  imov 0x8001 addr
  imov 69 ram
  imov 0x8002 addr
  imov 76 ram
  imov 0x8003 addr
  imov 76 ram
  imov 0x8004 addr
  imov 79 ram
  imov 0x8005 addr
  imov 0 ram
  imov 0x8006 addr
  imov 1 ram
  imov 0x8007 addr
  imov 0 ram

  imov 0x8010 ALU_A ; start value
  imov 0x9ff0 ALU_B ; stop value
  imov loop_start I ; loop start
  imov loop_end J ; loop exit
loop_start:
  ; set k = alu_a
  ALU A
  MOV ALU K
  ; set ram[k] = 0x71247
  mov K ADDR
  imov 0x0 RAM
  ;mov k ram
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
  ; halt
  imov start PC