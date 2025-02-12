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

`define MCPU_SILENT 1


// This is the MCPU core.
module mcpu_core(clk, reset, sense, cnt_pc, irom_in, data_in, data_out, reg_addr, dram_re, dram_we, alu_x, alu_y, reg_i, reg_j, reg_k);
  // The bit-width of the entire CPU is parametric
  parameter DATA_WIDTH = 32;
  
  // clock/reset inputs
  input clk, reset;
  
  // main data bus
  input [DATA_WIDTH-1:0] data_in;
  output [DATA_WIDTH-1:0] data_out;
  
  // CPU state
  output reg [DATA_WIDTH-1:0] cnt_pc;
  output reg [DATA_WIDTH-1:0] reg_addr;
  reg [DATA_WIDTH-1:0] srg_imm;
  reg [DATA_WIDTH-1:0] reg_alu_a, reg_alu_b;
  output reg [DATA_WIDTH-1:0] reg_i, reg_j, reg_k;
  reg last_imm;

  // RAM logic
  output dram_we, dram_re;
  assign dram_we = (op_dst == `MCPU_OP_DST_RAM) & should_execute;
  assign dram_re = (op_src == `MCPU_OP_SRC_RAM) & should_execute;
  
  // ROM logic
  input [7:0] irom_in;
  
  // instruction decoding
  wire op_is_imm = irom_in[`MCPU_OP_IS_IMM_BIT];
  wire [6:0] op_imm = irom_in[`MCPU_OP_IMM];
  wire op_is_cond = irom_in[`MCPU_OP_IS_COND_BIT];
  wire [2:0] op_src = irom_in[`MCPU_OP_SRC];
  wire [2:0] op_dst = irom_in[`MCPU_OP_DST];
  // if the MOV operation should be executed
  wire should_execute = op_is_imm ? 0 : (op_is_cond ? alu_f_out : 1);
  
  // ALU
  input sense;
  input [DATA_WIDTH-1:0] alu_x;
  input [DATA_WIDTH-1:0] alu_y;
  wire alu_f_out;
  wire [DATA_WIDTH-1:0] alu_d_out;
  mcpu_alu #(DATA_WIDTH) alu(
    .a(reg_alu_a),
    .b(reg_alu_b),
    .x(alu_x),
    .y(alu_y),
    .op(srg_imm),
    .sense(sense),
    .d_out(alu_d_out),
    .f_out(alu_f_out)
  );
  
  // operation source value multiplexer
  assign data_out = mux_src();
  function [DATA_WIDTH-1:0] mux_src;
    case (op_src)
      `MCPU_OP_SRC_PC: mux_src = cnt_pc;
      `MCPU_OP_SRC_ADDR: mux_src = reg_addr;
      `MCPU_OP_SRC_RAM: mux_src = data_in;
      `MCPU_OP_SRC_IMM: mux_src = srg_imm;
      `MCPU_OP_SRC_ALU: mux_src = alu_d_out;
      `MCPU_OP_SRC_I: mux_src = reg_i;
      `MCPU_OP_SRC_J: mux_src = reg_j;
      `MCPU_OP_SRC_K: mux_src = reg_k;
    endcase
  endfunction
  
  // clocked CPU step
  always @(posedge clk) begin
    if (reset) begin
      // reset CPU state
      cnt_pc <= 0;
      reg_addr <= 0;
      srg_imm <= 0;
      reg_alu_a <= 0;
      reg_alu_b <= 0;
      reg_i <= 0;
      reg_j <= 0;
      reg_k <= 0;
      last_imm <= 0;
    end else begin
      // normal CPU operation
      if (irom_in == 0)
        $finish();
      cnt_pc <= cnt_pc + 1;
      if (op_is_imm) begin
        `ifndef MCPU_SILENT $display("IMM instruction: 0x%h", op_imm); `endif
        // is immediate value instruction
        if (last_imm) begin
          srg_imm <= {srg_imm[DATA_WIDTH-8:0], op_imm};
        end else begin
          srg_imm <= {{DATA_WIDTH-7{1'0}},op_imm};
        end
        last_imm <= 1;
      end else begin
        // is mov/cmov instruction, write target register
        last_imm <= 0;
        `ifndef MCPU_SILENT 
        if (op_is_cond)
          $display("CMOV instruction: %d = %d(0x%h) Run: %b", op_dst, op_src, data_out, should_execute);
        else
          $display("MOV instruction: %d = %d(0x%h)", op_dst, op_src, data_out);
        `endif
        if (should_execute) begin
          case (op_dst)
            `MCPU_OP_DST_PC: cnt_pc <= data_out;
            `MCPU_OP_DST_ADDR: reg_addr <= data_out;
            `MCPU_OP_DST_RAM: ;
            `MCPU_OP_DST_ALU_A: reg_alu_a <= data_out;
            `MCPU_OP_DST_ALU_B: reg_alu_b <= data_out;
            `MCPU_OP_DST_I: reg_i <= data_out;
            `MCPU_OP_DST_J: reg_j <= data_out;
            `MCPU_OP_DST_K: reg_k <= data_out;
          endcase
        end
      end
    end
  end
endmodule

`endif

