`ifndef MCPU_DRAM_H
`define MCPU_DRAM_H

// Simple RAM implementation for MCPU
module mcpu_dram(clk, reset, addr, data_in, data_out, write_ena);
  // configure RAM layout
  parameter DRAM_DATA_BITS = 16;
  parameter DRAM_ADDR_BITS = 14;

  // inputs/outputs
  input clk, reset;
  input [DRAM_ADDR_BITS-1:0] addr;
  input [DRAM_DATA_BITS-1:0] data_in;
  output [DRAM_DATA_BITS-1:0] data_out;
  input write_ena;
  
  // create RAM
  reg [DRAM_DATA_BITS-1:0] dram[0:(2**DRAM_ADDR_BITS)-1];
  
  assign data_out = dram[addr];
  always @(posedge clk) begin
    if (write_ena)
      dram[addr[DRAM_ADDR_BITS-1:0]] <= data_in;
  end
endmodule
`endif
