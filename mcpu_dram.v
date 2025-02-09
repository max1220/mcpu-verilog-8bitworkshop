`ifndef MCPU_DRAM_H
`define MCPU_DRAM_H

// Simple RAM implementation for MCPU
module MCPU_DRAM(clk, reset, dram_addr, data_bus, dram_we, dram_re);
  parameter DRAM_DATA_BITS = 16;
  parameter DRAM_ADDR_BITS = 14;

  input clk, reset;
  input [DRAM_ADDR_BITS-1:0] dram_addr;
  inout [DRAM_DATA_BITS-1:0] data_bus;
  input dram_we, dram_re;
  
  // create DRAM
  reg [DRAM_DATA_BITS-1:0] dram[0:(2**DRAM_ADDR_BITS)-1];
  
  assign data_bus = dram_re ? dram[dram_addr] : {DRAM_DATA_BITS{1'bz}};
  always @(posedge clk) begin
    if (dram_we)
      dram[dram_addr[DRAM_ADDR_BITS-1:0]] <= data_bus;
  end
endmodule
`endif