`include "hvsync_generator.v"
`include "mcpu_alu.v"
`include "mcpu_core.v"
`include "font_cp437_8x8.v"
`include "mcpu_gpu.v"


module top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, keycode);
  parameter DATA_WIDTH = 16;
  parameter ROM_ADDR_BITS = 12;
  parameter RAM_ADDR_BITS = 14;
  
  // special top-level inputs/outputs
  input clk, reset;
  input [7:0] hpaddle, vpaddle;
  input [7:0] keycode;
  output hsync, vsync;
  output [3:0] rgb;
  
  // create RAM/ROM
  reg [7:0] rom[0:(2**ROM_ADDR_BITS)-1];
  reg [DATA_WIDTH-1:0] ram[0:(2**RAM_ADDR_BITS)-1];
  
  // create CPU core
  wire sense; // SENSE special ALU input(can "wait for" signal level on this input)
  wire [DATA_WIDTH-1:0] ram_addr; // RAM address output from CPU(REG_ADDR)
  wire [DATA_WIDTH-1:0] ram_value; // value provided from RAM to CPU
  wire [DATA_WIDTH-1:0] rom_addr; // ROM address output from CPU(CNT_PC)
  wire [7:0] rom_value; // value provided to CPU from ROM
  wire [DATA_WIDTH-1:0] ram_out; // RAM write value output from CPU
  wire ram_we; // if RAM should be written this clock
  wire [DATA_WIDTH-1:0] x,y; // ALU X,Y extra inputs
  wire [DATA_WIDTH-1:0] i,j,k; // outputs of CPU registers I,J,K
  
  assign rom_value = rom[rom_addr[ROM_ADDR_BITS-1:0]];
  assign ram_value = (ram_addr >= 2**RAM_ADDR_BITS) ? {{DATA_WIDTH-8{1'0}}, rom[ram_addr[ROM_ADDR_BITS-1:0]]} : ram[ram_addr[RAM_ADDR_BITS-1:0]];
  assign sense = vsync; // sense input is connected to vsync
  //assign x = {{DATA_WIDTH-16{1'0}}, vpaddle, hpaddle}; // X is connected to gamepad input
  assign x = {{DATA_WIDTH-8{1'0}}, hpaddle};
  assign y = {{DATA_WIDTH-8{1'0}}, keycode}; // Y input is keyboard input keycode
  MCPU_CORE #(DATA_WIDTH) mcpu(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .rom_addr(rom_addr),
    .rom_value(rom_value),
    .ram_addr(ram_addr),
    .ram_in(ram_value),
    .ram_out(ram_out),
    .ram_we(ram_we),
    .x(x),
    .y(y),
    .i(i),
    .j(j),
    .k(k)
  );
  
  // create GPU instance
  wire [7:0] gpu_d_in = 0;
  wire [7:0] gpu_d_out;
  wire [12:0] gpu_addr_in = 0;
  wire gpu_write_ena = 0;
  MCPU_GPU mcpu_gpu(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .d_out(gpu_d_out),
    .d_in(gpu_d_in),
    .addr_in(gpu_addr_in),
    .write_ena(gpu_write_ena),
    .rgb(rgb)
  );
  
  always @(*) begin
    // assign RAM based on addr
    if (ram_addr >= 2**RAM_ADDR_BITS)
      // ram address above RAM size, map to ROM
      ram_value = {{DATA_WIDTH-8{1'0}}, rom[ram_addr[ROM_ADDR_BITS-1:0]]};
    else
      // value from RAM
      ram_value = ram[ram_addr[RAM_ADDR_BITS-1:0]];
        
  end

  // write RAM on write signal from core
  always @(posedge clk) begin
    if (ram_we) begin
      ram[ram_addr[RAM_ADDR_BITS-1:0]] <= ram_out;
    end
  end
  
  // create ROM image from assembly
  initial begin
    
    `ifdef EXT_INLINE_ASM
    rom = '{
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

  end
  
endmodule
