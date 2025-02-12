`ifndef MCPU_IROM_H
`define MCPU_IROM_H

module mcpu_irom(addr0, out0, addr1, out1);
  parameter IROM_ADDR_BITS = 14;
  input [IROM_ADDR_BITS-1:0] addr0, addr1;
  output [7:0] out0, out1;
  assign out0 = irom[addr0];
  assign out1 = irom[addr1];
  
  // create ROM image from assembly
  reg [7:0] irom[0:(2**IROM_ADDR_BITS)-1];
  
  initial begin
    `ifdef EXT_INLINE_ASM
      `include "mcpu_irom_8bitworkshop.v"
    `else
      $readmemh("irom.hex", irom);
    `endif
  end
endmodule
`endif
