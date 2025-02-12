`include "hvsync_generator.v"
`include "mcpu_irom.v"
`include "mcpu_dram.v"
`include "mcpu_alu.v"
`include "mcpu_core.v"
`include "font_cp437_8x8.v"
`include "mcpu_gpu.v"
/*
!!! THIS COMMENT IS IMPORTANT! !!!

These files are included in other places, but if you delete them, the 8bitworkshop IDE won't find the files.

`include "mcpu_irom_8bitworkshop.v"
`include "mcpu_asm.json"
*/

module mcpu_top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, keycode);
  parameter DATA_WIDTH = 16;
  
  // special top-level inputs/outputs
  input clk, reset;
  input [7:0] hpaddle, vpaddle;
  input [7:0] keycode;
  output hsync, vsync;
  output [3:0] rgb;

  // create IROM memory
  // 14-bit IROM address(16384 bytes)
  wire [7:0] irom_out0, irom_out1; // value provided to CPU from ROM
  mcpu_irom #(14) mcpu_irom(
    .addr0(cpu_pc[13:0]),
    .out0(irom_out0),
    .addr1(cpu_addr[13:0]),
    .out1(irom_out1)
  );

  // create DRAM memory
  // 14-bit DRAM address(16384 words)
  wire dram_we; // read/write enables for access using the DRAM interface
  wire [DATA_WIDTH-1:0] dram_in, dram_out; // data input/output for dram
  assign dram_in = cpu_data_out;
  
  mcpu_dram #(DATA_WIDTH, 14) mcpu_dram(
    .clk(clk),
    .reset(reset),
    .addr(cpu_addr[13:0]),
    .data_in(dram_in),
    .data_out(dram_out),
    .write_ena(dram_we & (~cpu_addr[14] | ~cpu_addr[15]))
  );

  // select what value will be read as DRAM input(select between DRAM, IROM, VRAM, zero)
  function [15:0] mux_data_bus;
    case (cpu_addr[15:14])
      2'b00: mux_data_bus = dram_out;
      2'b01: mux_data_bus = {8'b0, irom_out1};
      2'b10: mux_data_bus = {8'b0, vram_out};
      2'b11: mux_data_bus = 16'b0;
    endcase
  endfunction

  // create CPU core
  wire sense, dram_re; // SENSE special ALU input(can "wait for" signal level on this input)
  wire [DATA_WIDTH-1:0] cpu_pc, cpu_addr, cpu_data_in, cpu_data_out, alu_x, alu_y, reg_i, reg_j, reg_k;
  assign sense = vsync; // sense input is connected to vsync
  assign alu_x = {{DATA_WIDTH-8{1'0}}, vpaddle[3:0], hpaddle[3:0]}; // X input is gampad input 
  assign alu_y = {{DATA_WIDTH-8{1'0}}, keycode}; // Y input is keyboard input keycode
  assign cpu_data_in = mux_data_bus();
  mcpu_core #(DATA_WIDTH) core(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .data_in(cpu_data_in),
    .data_out(cpu_data_out),
    .cnt_pc(cpu_pc),
    .irom_in(irom_out0),
    .reg_addr(cpu_addr),
    .dram_re(dram_re),
    .dram_we(dram_we),
    .alu_x(alu_x),
    .alu_y(alu_y),
    .reg_i(reg_i),
    .reg_j(reg_j),
    .reg_k(reg_k)
  );
  
  // create video signal generator
  wire display_on;
  wire [8:0] vpos, hpos;
  hvsync_generator hvsync(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );
  
  // create GPU instance
  wire vram_we, vram_re;
  wire [7:0] vram_out;
  assign vram_we = dram_we & (~cpu_addr[14] | cpu_addr[15]); // write to VRAM instead of DRAM when address starts with 0b10
  assign vram_re = dram_re & (~cpu_addr[14] | cpu_addr[15]);
  mcpu_gpu gpu(
    .clk(clk),
    .hpos(hpos),
    .vpos(vpos),
    .display_on(display_on),
    .rgb(rgb),
    .data_in(cpu_data_out[7:0]),
    .data_out(vram_out),
    .vram_addr(cpu_addr[12:0]),
    .vram_we(vram_we)
  );
endmodule
