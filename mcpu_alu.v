`ifndef MCPU_ALU_H
`define MCPU_ALU_H

// ALU main operations
`define MCPU_ALU_OP 2:0
`define MCPU_ALU_OP_ADD 3'b000
`define MCPU_ALU_OP_AND 3'b001
`define MCPU_ALU_OP_OR 3'b010
`define MCPU_ALU_OP_XOR 3'b011
`define MCPU_ALU_OP_A 3'b100
`define MCPU_ALU_OP_B 3'b101
`define MCPU_ALU_OP_X 3'b110
`define MCPU_ALU_OP_Y 3'b111

// ALU test operations
`define MCPU_ALU_TEST 2:0
`define MCPU_ALU_TEST_A_EQ_Z 3'b000
`define MCPU_ALU_TEST_B_EQ_Z 3'b001
`define MCPU_ALU_TEST_A_GT_B 3'b010
`define MCPU_ALU_TEST_A_EQ_B 3'b011
`define MCPU_ALU_TEST_A_LT_B 3'b100
`define MCPU_ALU_TEST_B_LO 3'b101
`define MCPU_ALU_TEST_B_HI 3'b110
`define MCPU_ALU_TEST_SENSE 3'b111

// ALU operation flags
`define MCPU_ALU_OP_INV_BIT 3
`define MCPU_ALU_OP_CIN_BIT 4

// ALU B pre-operation
`define MCPU_ALU_BOP 6:5
`define MCPU_ALU_BOP_B 2'b00
`define MCPU_ALU_BOP_IMM 2'b01
`define MCPU_ALU_BOP_RSHIFT 2'b10
`define MCPU_ALU_BOP_LSHIFT 2'b11

// MCPU ALU B pre-operation module
module MCPU_ALU_B(op, b_in, b_out);
  parameter DATA_WIDTH = 32;
  
  input [DATA_WIDTH-1:0] op; // value from IMM register containing ALU op + IMM
  input [DATA_WIDTH-1:0] b_in;
  output [DATA_WIDTH-1:0] b_out;
  
  
  // output of multiplexer can be inverted by INV bit
  assign b_out = op[`MCPU_ALU_OP_INV_BIT] ? ~b_muxed : b_muxed;
  
  // multiplexer for b operation
  wire [DATA_WIDTH-1:0] b_muxed;
  always @(*) begin
    case (op[`MCPU_ALU_BOP])
      `MCPU_ALU_BOP_B: assign b_muxed = b_in;
      `MCPU_ALU_BOP_IMM: assign b_muxed = { 7'b0, op[DATA_WIDTH-1:7] };
      `MCPU_ALU_BOP_LSHIFT: assign b_muxed = b_in<<1;
      `MCPU_ALU_BOP_RSHIFT: assign b_muxed = b_in>>1;
    endcase
  end
endmodule

// complete MCPU ALU module
module MCPU_ALU(op, a, b, x, y, sense, d_out, f_out);
  parameter DATA_WIDTH = 32;
  
  input [DATA_WIDTH-1:0] a,b,x,y,op;
  input sense;
  output [DATA_WIDTH-1:0] d_out;
  output f_out;
  wire [DATA_WIDTH-1:0] b_out;
  wire f;
  assign f_out = op[`MCPU_ALU_OP_INV_BIT] ? ~f : f;

  // create B pre-ALU instance
  MCPU_ALU_B #(DATA_WIDTH) alu_b(
    .op(op),
    .b_in(b),
    .b_out(b_out)
  );

  always @(*) begin
    // ALU data output multiplexer
    case (op[`MCPU_ALU_OP])
      `MCPU_ALU_OP_ADD: assign d_out = op[`MCPU_ALU_OP_CIN_BIT] ? (a + b_out + 1) : (a + b_out);
      `MCPU_ALU_OP_AND: assign d_out = a & b_out;
      `MCPU_ALU_OP_OR: assign d_out = a | b_out;
      `MCPU_ALU_OP_XOR: assign d_out = a ^ b_out;
      `MCPU_ALU_OP_A: assign d_out = a;
      `MCPU_ALU_OP_B: assign d_out = b_out;
      `MCPU_ALU_OP_X: assign d_out = x;
      `MCPU_ALU_OP_Y: assign d_out = y;
    endcase
    // ALU flag output multiplexer
    case (op[`MCPU_ALU_TEST])
      `MCPU_ALU_TEST_A_EQ_Z: assign f = a == 0;
      `MCPU_ALU_TEST_B_EQ_Z: assign f = b == 0;
      `MCPU_ALU_TEST_A_GT_B: assign f = a > b;
      `MCPU_ALU_TEST_A_EQ_B: assign f = a == b;
      `MCPU_ALU_TEST_A_LT_B: assign f = a < b;
      `MCPU_ALU_TEST_B_LO: assign f = b[0];
      `MCPU_ALU_TEST_B_HI: assign f = b[DATA_WIDTH-1];
      `MCPU_ALU_TEST_SENSE: assign f = sense;
    endcase
  end
endmodule

`endif

