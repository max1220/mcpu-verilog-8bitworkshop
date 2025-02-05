`ifndef MCPU_CORE_H
`define MCPU_CORE_H

`define MCPU_OP_SRC 2:0
`define MCPU_OP_DST 5:3
`define MCPU_OP_IMM 6:0
`define MCPU_OP_IS_COND_BIT 6
`define MCPU_OP_IS_IMM_BIT 7

`define MCPU_OP_SRC_PC 3'b000
`define MCPU_OP_SRC_ADDR 3'b001
`define MCPU_OP_SRC_RAM 3'b010
`define MCPU_OP_SRC_IMM 3'b011
`define MCPU_OP_SRC_ALU 3'b100
`define MCPU_OP_SRC_I 3'b101
`define MCPU_OP_SRC_J 3'b110
`define MCPU_OP_SRC_K 3'b111

`define MCPU_OP_DST_PC 3'b000
`define MCPU_OP_DST_ADDR 3'b001
`define MCPU_OP_DST_RAM 3'b010
`define MCPU_OP_DST_ALU_A 3'b011
`define MCPU_OP_DST_ALU_B 3'b100
`define MCPU_OP_DST_I 3'b101
`define MCPU_OP_DST_J 3'b110
`define MCPU_OP_DST_K 3'b111



module MCPU_CORE(clk, reset, sense, rom_addr, rom_value, ram_addr, ram_in, ram_out, ram_we, x, y, i, j, k);
  input clk;
  input reset;
  
  // CPU state
  reg [31:0] pc;
  reg [31:0] addr;
  reg [31:0] imm;
  reg [31:0] alu_a;
  reg [31:0] alu_b;
  output reg [31:0] i;
  output reg [31:0] j;
  output reg [31:0] k;
  reg last_imm;

  // RAM logic
  input [31:0] ram_in;
  output [31:0] ram_out;
  output [31:0] ram_addr;
  output ram_we;
  assign ram_out = data_bus;
  assign ram_addr = addr;
  assign ram_we = ((op_dst == `MCPU_OP_DST_RAM) && should_execute) ? 1 : 0;
  
  // ROM logic
  input [7:0] rom_value;
  output [31:0] rom_addr;
  assign rom_addr = pc;
  
  // instruction decoding
  wire op_is_imm = rom_value[`MCPU_OP_IS_IMM_BIT];
  wire [6:0] op_imm = rom_value[`MCPU_OP_IMM];
  wire op_is_cond = rom_value[`MCPU_OP_IS_COND_BIT];
  wire [2:0] op_src = rom_value[`MCPU_OP_SRC];
  wire [2:0] op_dst = rom_value[`MCPU_OP_DST];
  
  // if the MOV operation should be executed
  wire should_execute = op_is_imm ? 0 : (op_is_cond ? alu_f_out : 1);
  
  // core-internal main data bus
  wire [31:0] data_bus;
  
  // ALU
  input sense;
  input [31:0] x;
  input [31:0] y;
  wire alu_f_out;
  wire [31:0] alu_d_out;
  MCPU_ALU alu(
    .a(alu_a),
    .b(alu_b),
    .x(x),
    .y(y),
    .op(imm),
    .sense(sense),
    .d_out(alu_d_out),
    .f_out(alu_f_out)
  );
  
  // operation source value multiplexer
  always @(*) begin
    case (op_src)
      `MCPU_OP_SRC_PC: assign data_bus = pc;
      `MCPU_OP_SRC_ADDR: assign data_bus = addr;
      `MCPU_OP_SRC_RAM: assign data_bus = ram_in;
      `MCPU_OP_SRC_IMM: assign data_bus = imm;
      `MCPU_OP_SRC_ALU: assign data_bus = alu_d_out;
      `MCPU_OP_SRC_I: assign data_bus = i;
      `MCPU_OP_SRC_J: assign data_bus = j;
      `MCPU_OP_SRC_K: assign data_bus = k;
    endcase
  end
  
  // clocked CPU step
  always @(posedge clk) begin
    if (reset) begin
      // reset CPU state
      pc <= 32'b0;
      addr <= 32'b0;
      imm <= 32'b0;
      alu_a <= 32'b0;
      alu_b <= 32'b0;
      i <= 32'b0;
      j <= 32'b0;
      k <= 32'b0;
      last_imm <= 0;
    end else begin
      // normal CPU operation
      pc <= pc + 1;
      if (op_is_imm) begin
        // is immediate value instruction
        if (last_imm) begin
          imm <= {imm[24:0], op_imm};
        end else begin
          imm <= {25'b0, op_imm};
        end
        last_imm <= 1;
      end else begin
        // is mov/cmov instruction
        last_imm <= 0;
        if (should_execute) begin
          case (op_dst)
            `MCPU_OP_DST_PC: pc <= data_bus;
            `MCPU_OP_DST_ADDR: addr <= data_bus;
            `MCPU_OP_DST_RAM: ;
            `MCPU_OP_DST_ALU_A:alu_a <= data_bus;
            `MCPU_OP_DST_ALU_B: alu_b <= data_bus;
            `MCPU_OP_DST_I: i <= data_bus;
            `MCPU_OP_DST_J: j <= data_bus;
            `MCPU_OP_DST_K: k <= data_bus;
          endcase
        end
      end
    end
  end
endmodule

`endif

