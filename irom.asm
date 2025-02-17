; This program displays "Hello :)" on the display:
; * First, it sets up the GPU control registers,
; * then it clears a section of VRAM,
; * then it writes two text messages into VRAM.
.arch mcpu_asm
.org 0x0000
.len 0x4000



start:

; This configures the control registers for a simple text mode display
; and clears a section of VRAM(from 0x8000 to 0x83c0).
clear_vram:
  ; setup control register in VRAM
  imov 0x9fff ADDR ; CTL_CONFIG
  imov 0x00 RAM ; configures text mode, 8-bit characters, text page 0(0x8000-0x8400)
  imov 0x9ffe ADDR ; CTL_COLOR0
  imov 0x01 RAM ; Foreground color in low nibble(red), background color in high nibble(black)
  imov 0x9ffd ADDR ; CTL_COLOR1
  imov 0x02 RAM ; unused(secondary foreground/background color for 2-color mode with 7bits/character)
  imov 0x9ffc ADDR ; CTL_BORDER
  imov 0x04 RAM ; border pattern colors(blue/black)
  imov 0x9ffb ADDR ; CTL_PAGE
  imov 0x00 RAM ; offset in VRAM(used for scrolling/double-buffering)
  ; setup the main loop
  imov 0x8000 ALU_A ; start value in VRAM
  imov 0x83c0 ALU_B ; stop value in VRAM
  ; write loop entry/exit locations to registers(saves some IMM instruction in the "hotloop")
  imov clear_vram_loop_exit J ; loop exit location
clear_vram_loop_entry:
  ; set k = alu_a
  alu A
  mov ALU K
  ; set ram[k] = 0
  mov K ADDR
  imov 0x0 RAM
  ; set k,alu_a = a+1
  alu IMM C ADD
  mov ALU K
  mov K ALU_A
  ; conditional branch to clear_loop_end if a == b
  test A_EQ_B
  cmov J PC
  ; continue loop
  imov clear_vram_loop_entry PC
clear_vram_loop_exit:
  ; fall through



; Setup to write "Hello World!" to the screen in the first row
print_from_ram_hello:
  ; write starting value in RAM (hello_str + 0x4000) to ALU_A(TODO: This is const, but I don't know miniasm)
  imov hello_str ALU_A ; ROM string location on IROM bus
  imm 0x4000
  alu IMM ADD ; calculate ROM string location on DRAM bus
  mov ALU ALU_A
  ; write starting value in VRAM to ALU_B
  imov 0x8000 ALU_B
  ; write loop exit location to REG_J
  imov print_from_ram_test J ; loop exit location
  imov print_from_ram_loop_entry PC ; enter the loop

; Setup to write "This runs on the MCPU!" to the screen in the first row
print_from_ram_test:
  imm test_str
  mov imm ALU_A
  imm 0x4000
  alu IMM ADD
  mov ALU ALU_A
  imov 0x8020 ALU_B
  imov final_exit J ; loop exit location
  imov print_from_ram_loop_entry PC ; enter the loop

; Called after the last print to halt execution
final_exit:
  imov 0x8190 ADDR
  imov 1 RAM
  halt


; This writes a zero-terminated string from IROM to VRAM
print_from_ram_loop_entry:
  ; jump to exit if RAM[ALU_A] == 0
  alu A ; read RAM[ALU_A] into REG_K and ALU_A
  mov ALU ADDR
  mov RAM K
  mov K ALU_A
  test A_EQ_Z ; Test if a==0
  cmov J PC ; branch to reg_j if A==0
  ; no branch, write to VRAM
  mov ADDR ALU_A ; restore ALU_A to current RAM location
  ; write REG_K to RAM[ALU_B]
  alu B
  mov ALU ADDR
  mov K RAM
  ; increment A
  imm 1
  alu IMM ADD
  mov ALU ADDR ; temporary storage
  ; increment B
  alu B
  mov ALU ALU_A
  imm 1
  alu IMM ADD
  mov ALU ALU_B
  mov ADDR ALU_A ; restore ALU_A from temporary storage
  imov print_from_ram_loop_entry PC ; jump to loop entry
print_from_ram_loop_exit:
  halt



; ROM Data(to read on DRAM bus, add 0x4000 to address first!)
; TODO: Is there a way to tell miniasm this, or extend miniasm?
hello_str:
  .string Hello World!
  .data 0

test_str:
  .string This demo runs on the MCPU!
  .data 0
