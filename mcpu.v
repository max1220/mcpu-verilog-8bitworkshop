`include "hvsync_generator.v"
`include "mcpu_dram.v"
`include "mcpu_alu.v"
`include "mcpu_core.v"
`include "font_cp437_8x8.v"
`include "mcpu_gpu.v"

module top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, keycode);
  parameter DATA_WIDTH = 16;
  
  // data bus that connects memory and external register to the MCPU core
  wire [DATA_WIDTH-1:0] data_bus;
  
  // special top-level inputs/outputs
  input clk, reset;
  input [7:0] hpaddle, vpaddle;
  input [7:0] keycode;
  output hsync, vsync;
  output [3:0] rgb;
  
  // create memory for CPU core(IROM/DRAM)
  // 12-bit IROM address(4096 bytes)
  // 14-bit DRAM address(16384 words)
  // addresses are padded by the MCPU_MEMORY module to DATA_WIDTH
  wire [DATA_WIDTH-1:0] irom_addr; // ROM address output from CPU(CNT_PC)
  wire [7:0] irom_out; // value provided to CPU from ROM
  wire [DATA_WIDTH-1:0] data_bus_addr; // RAM address output from CPU(REG_ADDR)
  wire [DATA_WIDTH-1:0] dram_out; // value provided from RAM to CPU
  wire [DATA_WIDTH-1:0] dram_in; // RAM write value output from CPU
  wire dram_we; // if RAM should be written this clock
  wire dram_re; // if value from RAM should be driven to the data bus
  MCPU_MEMORY #(12, DATA_WIDTH, DATA_WIDTH, 14, DATA_WIDTH) mcpu_memory(
    .clk(clk),
    .reset(reset),
    .irom_addr(irom_addr),
    .irom_out(irom_out),
    .dram_addr(data_bus_addr),
    .data_bus(data_bus),
    .dram_we(dram_we),
    .dram_re(dram_re)
  );
  
  // create CPU core
  wire sense; // SENSE special ALU input(can "wait for" signal level on this input)
  wire [DATA_WIDTH-1:0] x,y; // ALU X,Y extra inputs
  assign sense = vsync; // sense input is connected to vsync
  assign x = {{DATA_WIDTH-8{1'0}}, hpaddle}; // X input is gampad horizontal input 
  assign y = {{DATA_WIDTH-8{1'0}}, keycode}; // Y input is keyboard input keycode 
  wire regs_ext = 0; // set to 1 to read value for reg_i, reg_j, reg_k, from data_bus
  wire [2:0] regs_ext_we; // 3 write-enable signals for external I,J,K
  wire [2:0] regs_ext_re; // 3 read-enable signals for external I,J,K
  MCPU_CORE #(DATA_WIDTH) mcpu(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .data_bus(data_bus),
    .irom_addr(irom_addr),
    .irom_in(irom_out),
    .reg_addr(data_bus_addr),
    .dram_re(dram_re),
    .dram_we(dram_we),
    .x(x),
    .y(y),
    .regs_ext(regs_ext),
    .regs_ext_we(regs_ext_we),
    .regs_ext_re(regs_ext_re)
  );
  
  // create video signal generator
  wire display_on;
  wire [8:0] vpos, hpos;
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );
  
  // create GPU instance
  wire [7:0] gpu_d_in = 0;
  wire [7:0] gpu_d_out;
  wire [12:0] gpu_addr_in = 0;
  wire vram_re, vram_we;
  assign vram_re = 0;
  assign vram_we = 0;
  MCPU_GPU mcpu_gpu(
    .clk(clk),
    .hpos(hpos),
    .vpos(vpos),
    .display_on(display_on),
    .rgb(rgb),
    .data_bus(data_bus[7:0]),
    .vram_addr(gpu_addr_in),
    .vram_we(vram_we),
    .vram_re(vram_re)
  );
  
endmodule
