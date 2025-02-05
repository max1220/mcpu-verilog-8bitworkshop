`include "hvsync_generator.v"
`include "mcpu_alu.v"
`include "mcpu_core.v"

module top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, keycode);
  // special input/output
  input clk, reset;
  output hsync, vsync;
  output [3:0] rgb;
  input [7:0] hpaddle;
  input [7:0] vpaddle;
  input [7:0] keycode;
  
  // create CPU core
  wire sense = hsync;
  wire [31:0] ram_addr;
  wire [31:0] rom_addr;
  wire write_ram;
  wire [31:0] dbus_out;
  wire [31:0] x = {8'b0, vpaddle, hpaddle, keycode};
  wire [31:0] y = {32'b0};
  wire [31:0] i;
  wire [31:0] j;
  wire [31:0] k;
  MCPU_CORE mcpu(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .rom_value(rom_value),
    .ram_addr(ram_addr),
    .rom_addr(rom_addr),
    .ram_in(ram_value),
    .ram_out(dbus_out),
    .ram_we(write_ram),
    .x(x),
    .y(y),
    .i(i),
    .j(j),
    .k(k)
  );
  
  // create video generator
  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );
  
  // update video output from RAM
  wire [6:0] px_x = hpos[7:1]; // scaled 2x, so ignore lowest bit
  wire [6:0] px_y = vpos[7:1];
  wire [ram_addr_bits-1:0] ram_px_addr = {1'b1, px_y, px_x[6:3]};
  wire [31:0] ram_px = ram[ram_px_addr];
  always @(*) begin
    if (ram_addr >= 2**ram_addr_bits)
      // ram address above RAM size, map to ROM
      ram_value = {24'b0, rom[ram_addr]};
    else
      // map 
      ram_value = ram[ram_addr];

    if (!display_on)
      // outside of range, use border pattern
      rgb = vpos[0]^hpos[0] ? 4'hf : 4'h0; // grey/black checkerboard
    else
      // multiplex 32-bit ram value into a single 4-bit pixel based on hpos bits
      case (px_x[2:0])
        3'b000: rgb = ram_px[3:0];
        3'b001: rgb = ram_px[7:4];
        3'b010: rgb = ram_px[11:8];
        3'b011: rgb = ram_px[15:12];
        3'b100: rgb = ram_px[19:16];
        3'b101: rgb = ram_px[23:20];
        3'b110: rgb = ram_px[27:24];
        3'b111: rgb = ram_px[31:28];
      endcase
  end
    
  // create RAM/ROM
  localparam ram_addr_bits = 12;
  localparam rom_addr_bits = 8;
  reg [7:0] rom[0:(2**rom_addr_bits)-1];
  reg [31:0] ram[0:(2**ram_addr_bits)-1];
  wire [7:0] rom_value;
  assign rom_value = rom[rom_addr];
  wire [31:0] ram_value;
  assign ram_value = ram[ram_addr];
  
  // write RAM on write signal from core
  always @(posedge clk) begin
    if (write_ram) begin
      ram[ram_addr] <= dbus_out;
    end
  end
  
  // create ROM image from assembly
  initial begin
    rom = '{
      __asm
      ; This program fills memory from 0x800 to 0xf7f with the address of th memory.
      ; The screen is memory-mapped there(128x120 pixels, scaled 2x to screen).
      .arch mcpu_asm
      .org 0x0000
      .len 0x100
      start:
        imov 0x800 ALU_A ; start value
        imov 0xf7f ALU_B ; end value
        imov loop_start I ; loop start
        imov loop_end J ; loop exit
      loop_start:
        ; conditional branch to end if a == b
        test A_EQ_B
        cmov J PC
        ; set k,alu_a = a+1
        alu IMM C ADD
        mov ALU K
        mov K ALU_A
        ; set ram[k] = k
        mov K ADDR
        mov K RAM
        ; continue loop
        mov i PC
      loop_end:
        halt
      __endasm
    };

  end
  
endmodule
