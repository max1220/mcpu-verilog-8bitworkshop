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

// complete MCPU ALU module
module mcpu_alu(op, a, b, x, y, sense, d_out, f_out);
  parameter DATA_WIDTH = 32;
  
  input [DATA_WIDTH-1:0] a,b,x,y,op;
  input sense;
  output [DATA_WIDTH-1:0] d_out;
  output f_out;
  wire [DATA_WIDTH-1:0] b_out;
  assign f_out = op[`MCPU_ALU_OP_INV_BIT] ? ~mux_f() : mux_f();
  assign d_out = mux_d();

  // create B pre-ALU instance
  mcpu_alu_b #(DATA_WIDTH) alu_b(
    .op(op),
    .b_in(b),
    .b_out(b_out)
  );

  // ALU data output multiplexer
  function [DATA_WIDTH-1:0] mux_d;
    case (op[`MCPU_ALU_OP])
      `MCPU_ALU_OP_ADD: mux_d = op[`MCPU_ALU_OP_CIN_BIT] ? (a + b_out + 1) : (a + b_out);
      `MCPU_ALU_OP_AND: mux_d = a & b_out;
      `MCPU_ALU_OP_OR: mux_d = a | b_out;
      `MCPU_ALU_OP_XOR: mux_d = a ^ b_out;
      `MCPU_ALU_OP_A: mux_d = a;
      `MCPU_ALU_OP_B: mux_d = b_out;
      `MCPU_ALU_OP_X: mux_d = x;
      `MCPU_ALU_OP_Y: mux_d = y;
    endcase
  endfunction

  // ALU flag multiplexer
  function mux_f;
    case (op[`MCPU_ALU_TEST])
      `MCPU_ALU_TEST_A_EQ_Z: mux_f = a == 0;
      `MCPU_ALU_TEST_B_EQ_Z: mux_f = b == 0;
      `MCPU_ALU_TEST_A_GT_B: mux_f = a > b;
      `MCPU_ALU_TEST_A_EQ_B: mux_f = a == b;
      `MCPU_ALU_TEST_A_LT_B: mux_f = a < b;
      `MCPU_ALU_TEST_B_LO: mux_f = b[0];
      `MCPU_ALU_TEST_B_HI: mux_f = b[DATA_WIDTH-1];
      `MCPU_ALU_TEST_SENSE: mux_f = sense;
    endcase
  endfunction
endmodule

// MCPU ALU B pre-operation module
module mcpu_alu_b(op, b_in, b_out);
  parameter DATA_WIDTH = 32;
  
  input [DATA_WIDTH-1:0] op; // value from IMM register containing ALU op + IMM
  input [DATA_WIDTH-1:0] b_in;
  output [DATA_WIDTH-1:0] b_out;
  
  // output of multiplexer can be inverted by INV bit
  assign b_out = op[`MCPU_ALU_OP_INV_BIT] ? ~mux_b() : mux_b();
  
  // multiplexer for b operation
  function [DATA_WIDTH-1:0] mux_b;
    case (op[`MCPU_ALU_BOP])
      `MCPU_ALU_BOP_B: mux_b = b_in;
      `MCPU_ALU_BOP_IMM: mux_b = { 7'b0, op[DATA_WIDTH-1:7] };
      `MCPU_ALU_BOP_LSHIFT: mux_b = b_in<<1;
      `MCPU_ALU_BOP_RSHIFT: mux_b = b_in>>1;
    endcase
  endfunction
endmodule

`endif

