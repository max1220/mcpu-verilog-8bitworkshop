`ifndef MCPU_IROM_H
`define MCPU_IROM_H

module mcpu_irom(irom_addr0, irom_out0, irom_addr1, irom_out1);
  parameter IROM_ADDR_BITS = 14;
  input [IROM_ADDR_BITS-1:0] irom_addr0, irom_addr1;
  output [7:0] irom_out0, irom_out1;
  assign irom_out0 = irom[irom_addr0];
  assign irom_out1 = irom[irom_addr1];
  
  // create ROM image from assembly
  reg [7:0] irom[0:(2**IROM_ADDR_BITS)-1];
  
  initial begin
    `ifdef EXT_INLINE_ASM
      `include "irom_8bitworkshop.v"
    `else
      $readmemh("irom.hex", irom);
      $display("IROM image from hex dump: 0x%2x 0x%2x 0x%2x (...)", irom[0], irom[1], irom[2]);
    `endif
  end
endmodule
`endif
