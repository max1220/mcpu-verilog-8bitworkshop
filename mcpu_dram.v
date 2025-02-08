`ifndef MCPU_MEMORY_H
`define MCPU_MEMORY_H

// implementation of the memory interface for the MCPU.
// The GPU has it's own RAM/ROM
module MCPU_MEMORY(clk, reset, irom_addr, irom_out, dram_addr, data_bus, dram_we, dram_re);
  parameter IROM_ADDR_BITS = 12;
  parameter IROM_ADDR_IN_BITS = 16;
  parameter DRAM_DATA_BITS = 16;
  parameter DRAM_ADDR_BITS = 14;
  parameter DRAM_ADDR_IN_BITS = 16;

  input clk, reset;
  
  // create IROM
  reg [7:0] irom[0:(2**IROM_ADDR_BITS)-1];
  
  // create DRAM
  reg [DRAM_DATA_BITS-1:0] dram[0:(2**DRAM_ADDR_BITS)-1];

  // IROM interface
  input [IROM_ADDR_IN_BITS-1:0] irom_addr;
  output [7:0] irom_out;
  // DRAM interface
  input dram_we, dram_re;
  input [DRAM_ADDR_IN_BITS-1:0] dram_addr;
  inout [DRAM_DATA_BITS-1:0] data_bus;
  
  wire [DRAM_DATA_BITS-1:0] dram_read_dram, dram_read_irom;
  // handle IROM
  assign irom_out = irom[irom_addr[IROM_ADDR_BITS-1:0]];
  // handle DRAM(bits above 
  assign dram_read_dram = dram[dram_addr[DRAM_ADDR_BITS-1:0]];
  assign dram_read_irom = {{DRAM_DATA_BITS-8{1'0}}, irom[dram_addr[IROM_ADDR_BITS-1:0]]};
  assign data_bus = dram_re ? ((dram_addr >= 2**DRAM_ADDR_BITS) ? dram_read_irom : dram_read_dram) : {DRAM_DATA_BITS{1'bz}};

  // handle ram_we from core: write core datat bus output to RAM if requested
  always @(posedge clk) begin
    if (dram_we)
      dram[dram_addr[DRAM_ADDR_BITS-1:0]] <= data_bus;
  end
  
  // create ROM image from assembly
  initial begin
    irom[0] = 0;
    /*
    `ifdef EXT_INLINE_ASM
    irom = '{
      __asm
      ; This program fills memory from 0x800 to 0xf7f with the address of th memory.
      ; The screen is memory-mapped there(128x120 pixels, scaled 2x to screen).
      .arch mcpu_asm
      .org 0x0000
      .len 0x1000
      start:
        imov 0x800 ALU_A ; start value
        imov 0xf7f ALU_B ; end value
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
        ; conditional branch to end if a == b
        test A_EQ_B
        cmov J PC
        ; continue loop
        mov i PC
      loop_end:
        halt
      __endasm
    };
    `endif
    */
  end
endmodule
`endif