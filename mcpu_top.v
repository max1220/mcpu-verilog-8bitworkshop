`include "hvsync_generator.v"
`include "mcpu_irom.v"
`include "mcpu_dram.v"
`include "mcpu_alu.v"
`include "mcpu_core.v"
`include "font_cp437_8x8.v"
`include "mcpu_gpu.v"

module mcpu_top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, keycode);
  parameter DATA_WIDTH = 16;
  
  // data bus that connects memory and external register to the MCPU core
  wire [DATA_WIDTH-1:0] data_bus;
  // RAM address output from CPU(REG_ADDR)
  wire [DATA_WIDTH-1:0] data_bus_addr;
  
  // special top-level inputs/outputs
  input clk, reset;
  input [7:0] hpaddle, vpaddle;
  input [7:0] keycode;
  output hsync, vsync;
  output [3:0] rgb;
  
  // create memory for CPU core(IROM/DRAM)
  // 14-bit IROM address(16384 bytes)
  // 14-bit DRAM address(16384 words)
  // addresses are padded by the MCPU_MEMORY module to DATA_WIDTH
  wire [15:0] cnt_pc; // ROM address output from CPU(CNT_PC)
  wire [7:0] irom_out0, irom_out1; // value provided to CPU from ROM
  
  wire dram_we, dram_re; // read/write enables for access using the DRAM interface
  mcpu_dram #(DATA_WIDTH, 14) mcpu_dram(
    .clk(clk),
    .reset(reset),
    .dram_addr(data_bus_addr[13:0]),
    .data_bus(data_bus),
    .dram_we(dram_we),
    .dram_re(dram_re)
  );
  
  mcpu_irom #(14) mcpu_irom(
    .irom_addr0(cnt_pc[13:0]),
    .irom_out0(irom_out0),
    .irom_addr1(data_bus_addr[13:0]),
    .irom_out1(irom_out1)
  );
  
  // create CPU core
  wire sense; // SENSE special ALU input(can "wait for" signal level on this input)
  wire [DATA_WIDTH-1:0] alu_x, alu_y; // ALU X,Y extra inputs
  assign sense = vsync; // sense input is connected to vsync
  assign alu_x = {{DATA_WIDTH-8{1'0}}, vpaddle[3:0], hpaddle[3:0]}; // X input is gampad input 
  assign alu_y = {{DATA_WIDTH-8{1'0}}, keycode}; // Y input is keyboard input keycode 
  wire regs_ext = 0; // set to 1 to read value for reg_i, reg_j, reg_k, from data_bus
  wire [2:0] regs_ext_we; // 3 write-enable signals for external I,J,K
  wire [2:0] regs_ext_re; // 3 read-enable signals for external I,J,K
  mcpu_core #(DATA_WIDTH) core(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .data_bus(data_bus),
    .cnt_pc(cnt_pc),
    .irom_in(irom_out0),
    .reg_addr(data_bus_addr),
    .dram_re(dram_re),
    .dram_we(dram_we),
    .alu_x(alu_x),
    .alu_y(alu_y),
    .regs_ext(regs_ext),
    .regs_ext_we(regs_ext_we),
    .regs_ext_re(regs_ext_re)
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
  wire vram_re, vram_we;
  assign vram_re = 0;
  assign vram_we = 0;
  mcpu_gpu gpu(
    .clk(clk),
    .hpos(hpos),
    .vpos(vpos),
    .display_on(display_on),
    .rgb(rgb),
    .data_bus(data_bus[7:0]),
    .vram_addr(data_bus_addr[12:0]),
    .vram_we(vram_we),
    .vram_re(vram_re)
  );

  initial begin
    $display("Verilog MCPU started!");
  end
  
endmodule
