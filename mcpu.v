`include "hvsync_generator.v"

`ifndef MCPU_ALU_H
`define MCPU_ALU_H

`define MCPU_ALU_BOP_B 2'b00
`define MCPU_ALU_BOP_IMM 2'b01
`define MCPU_ALU_BOP_RSHIFT 2'b10
`define MCPU_ALU_BOP_LSHIFT 2'b11
module MCPU_ALU_B(op, b_in, b_out);
  input [31:0] op;
  input [31:0] b_in;
  output [31:0] b_out;

  wire [31:0] b_res;
  wire op_inv = op[3];
  wire [1:0] op_bsel = { op[6:5] };
  wire [24:0] op_imm = { op[31:7] };
  wire [31:0] imm_ext = { 7'b0, op_imm };
  
  always @(*)
    begin
      case (op_bsel)
        `MCPU_ALU_BOP_B: assign b_res = b_in;
        `MCPU_ALU_BOP_IMM: assign b_res = imm_ext;
        `MCPU_ALU_BOP_LSHIFT: assign b_res = b_in<<1;
        `MCPU_ALU_BOP_RSHIFT: assign b_res = b_in>>1;
      endcase
      assign b_out = op_inv ? ~b_res : b_res;
    end
endmodule

`define MCPU_ALU_OP_ADD 3'b000
`define MCPU_ALU_OP_AND 3'b001
`define MCPU_ALU_OP_OR 3'b010
`define MCPU_ALU_OP_XOR 3'b011
`define MCPU_ALU_OP_A 3'b100
`define MCPU_ALU_OP_B 3'b101
`define MCPU_ALU_OP_X 3'b110
`define MCPU_ALU_OP_Y 3'b111
module MCPU_ALU(a, b, x, y, op, sense, d_out, f_out);
  input [31:0] a;
  input [31:0] b;
  input [31:0] x;
  input [31:0] y;
  input [31:0] op;
  input sense;
  output [31:0] d_out;
  wire f;
  output f_out;

  wire [2:0] op_sel = op[2:0];
  wire op_inv = op[3];
  wire op_cin = op[4];

  wire [31:0] b_out;

  MCPU_ALU_B alu_b(
    .op(op),
    .b_in(b),
    .b_out(b_out)
  );

  always @(*)
    begin
      case (op_sel)
        `MCPU_ALU_OP_ADD: begin
          if (op_cin)
            assign d_out[31:0] = a + b_out + 32'b1;
          else
            assign d_out[31:0] = a + b_out;
          assign f = a == 0;
        end
        `MCPU_ALU_OP_AND: begin
          assign d_out = a & b_out;
          assign f = b == 0;
        end
        `MCPU_ALU_OP_OR: begin
          assign d_out = a | b_out;
          assign f = a > b;
        end
        `MCPU_ALU_OP_XOR: begin
          assign d_out = a ^ b_out;
          assign f = a == b;
        end
        `MCPU_ALU_OP_A: begin
          assign d_out = a;
          assign f = a < b;
        end
        `MCPU_ALU_OP_B: begin
          assign d_out = b_out;
          assign f = b[0];
        end
        `MCPU_ALU_OP_X: begin
          assign d_out = x;
          assign f = b[31];
        end
        `MCPU_ALU_OP_Y: begin
          assign d_out = y;
          assign f = sense;
        end
      endcase
      if (op_inv)
        assign f_out = ~f;
      else
        assign f_out = f;
    end
endmodule

`endif




`ifndef MCPU_CORE_H
`define MCPU_CORE_H

`define MCPU_SRC_PC 3'b000
`define MCPU_SRC_ADDR 3'b001
`define MCPU_SRC_RAM 3'b010
`define MCPU_SRC_IMM 3'b011
`define MCPU_SRC_ALU 3'b100
`define MCPU_SRC_I 3'b101
`define MCPU_SRC_J 3'b110
`define MCPU_SRC_K 3'b111

`define MCPU_DST_PC 3'b000
`define MCPU_DST_ADDR 3'b001
`define MCPU_DST_RAM 3'b010
`define MCPU_DST_ALU_A 3'b011
`define MCPU_DST_ALU_B 3'b100
`define MCPU_DST_I 3'b101
`define MCPU_DST_J 3'b110
`define MCPU_DST_K 3'b111

// sense pin works like an interrupt pin
// rom value is the input instruction
// addr is RAM address register
// dbus_in is the value to be read from RAM
// dbus_out is the value to be written to RAM
// write_ram is set if current value should be written to ram
module MCPU_CORE(clk, reset, sense, pc, rom_value, addr, dbus_in, dbus_out, write_ram, x, y, i, j, k);
  input clk;
  input reset;
  input sense;
  input [7:0] rom_value;
  input [31:0] dbus_in;
  input [31:0] x;
  input [31:0] y;
  output [31:0] dbus_out = data_bus;
  output reg write_ram;
  output reg [31:0] pc;
  output reg [31:0] addr;
  reg [31:0] imm;
  reg [31:0] alu_a;
  reg [31:0] alu_b;
  output reg [31:0] i;
  output reg [31:0] j;
  output reg [31:0] k;
  reg last_imm;

  // instruction decoding
  
  // immediate bit and value
  wire op_is_imm = rom_value[7];
  wire [6:0] op_imm = rom_value[6:0];
  
  // MOV/CMOV operation
  wire op_is_cond = rom_value[6];
  wire [2:0] op_src = rom_value[2:0];
  wire [2:0] op_dst = rom_value[5:3];
  
  // CMOV
  wire should_execute = op_is_cond ? alu_f_out : 1;
  
  wire [31:0] data_bus;
  wire alu_f_out;
  wire [31:0] alu_d_out;
  wire alu_sense = 0;
  
  
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
  
  always @(*)
    begin
      case (op_src)
          `MCPU_SRC_PC: begin
            data_bus = pc;
          end
          `MCPU_SRC_ADDR: begin
            data_bus = addr;
          end
          `MCPU_SRC_RAM: begin
            data_bus = dbus_in;
          end
          `MCPU_SRC_IMM: begin
            data_bus = imm;
          end
          `MCPU_SRC_ALU: begin
            data_bus = alu_d_out;
          end
          `MCPU_SRC_I: begin
            data_bus = i;
          end
          `MCPU_SRC_J: begin
            data_bus = j;
          end
          `MCPU_SRC_K: begin
            data_bus = k;
          end
        endcase
    end
  
  always @(posedge clk)
    begin
      if (reset) begin
        pc <= 32'b0;
        addr <= 32'b0;
        imm <= 32'b0;
        alu_a <= 32'b0;
        alu_b <= 32'b0;
        i <= 32'b0;
        j <= 32'b0;
        k <= 32'b0;
        last_imm <= 0;
        write_ram <= 0;
      end else begin
        pc <= pc + 1;
        if (op_is_imm) begin
          if (last_imm) begin
            imm <= {imm[24:0], op_imm};
          end else begin
            imm <= {25'b0, op_imm};
          end
          last_imm <= 1;
          write_ram <= 0;
        end else begin
          last_imm <= 0;
          write_ram <= 0;
          if (rom_value == 8'b0)
          	$stop();
          if (should_execute) begin
            case (op_dst)
              `MCPU_DST_PC: begin
                pc <= data_bus;
              end
              `MCPU_DST_ADDR: begin
                addr <= data_bus;
              end
              `MCPU_DST_RAM: begin
                write_ram <= 1;
              end
              `MCPU_DST_ALU_A: begin
                alu_a <= data_bus;
              end
              `MCPU_DST_ALU_B: begin
                alu_b <= data_bus;
              end
              `MCPU_DST_I: begin
                i <= data_bus;
              end
              `MCPU_DST_J: begin
                j <= data_bus;
              end
              `MCPU_DST_K: begin
                k <= data_bus;
              end
            endcase
          end
        end
      end
    end
endmodule

`endif



module top(clk, reset, hsync, vsync, rgb, hpaddle, vpaddle, spkr, keycode);
  // special input/output
  input clk, reset;
  output hsync, vsync;
  output [3:0] rgb;
  input [7:0] hpaddle;
  input [7:0] vpaddle;
  output spkr;
  input [7:0] keycode;

  // create video generator
  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  wire sense = hsync;
  wire [7:0] rom_value = rom[rom_addr];
  reg [31:0] ram_addr;
  wire [31:0] ram_value = ram[ram_addr];
  wire [31:0] rom_addr;
  wire write_ram;
  wire [31:0] dbus_out;
  wire [31:0] x = {8'b0, vpaddle, hpaddle, keycode};
  wire [31:0] y = {32'b0};
  wire [31:0] i;
  wire [31:0] j;
  wire [31:0] k;
  
  MCPU_CORE mcpu(
    .clk(clk),
    .reset(reset),
    .sense(sense),
    .rom_value(rom_value),
    .addr(ram_addr),
    .pc(rom_addr),
    .dbus_in(ram_value),
    .dbus_out(dbus_out),
    .write_ram(write_ram),
    .x(x),
    .y(y),
    .i(i),
    .j(j),
    .k(k)
  );
  
  //wire r = display_on && alu_d_out[6];
  //wire r = display_on && alu_f_out;
  //wire r = display_on && rom_addr[0];
  //wire g = display_on && dbus_out[4];
  //wire b = display_on && hpos[3] ^ vpos[3];
  //wire b = 0;
  
  //assign rgb = display_on ? ram[{vpos[7:0], hpos[7:0]}] : (hpos[0]^vpos[0] ? 32'h7f : 32'h0 );
  //assign rgb = ram[{vpos[7:0], hpos[7:0]}];

  wire [3:0] px;
  wire [31:0] ram_v = ram[{i[2:0], vpos[7:0], hpos[7:3]}];
  always @(*)
    begin
      spkr = j[0];
      if (vpos>=240 || hpos[8])
        // outside of range, use border pattern
        rgb = vpos[0]^hpos[0] ? 4'h8 : 4'h0; // gray/black checkerboard
      else
        // multiplex 32-bit ram value into a single 4-bit pixel based on hpos bits
        case (hpos[2:0])
          3'b000: rgb = ram_v[3:0];
          3'b001: rgb = ram_v[7:4];
          3'b010: rgb = ram_v[11:8];
          3'b011: rgb = ram_v[15:12];
          3'b100: rgb = ram_v[19:16];
          3'b101: rgb = ram_v[23:20];
          3'b110: rgb = ram_v[27:24];
          3'b111: rgb = ram_v[31:28];
        endcase
    end
  
  always @(posedge clk)
    begin
      if (write_ram) begin
        ram[ram_addr] <= dbus_out;
      end
    end
  
  
  // create RAM/ROM
  reg [7:0] rom[0:(2**8)-1];
  reg [31:0] ram[0:(2**16)-1];

  // create ROM image by assembling 
  initial begin
    rom = '{
      __asm
      
.arch mcpu_asm
.org 0x0000
.len 0x100

start:
	imov 0x0 K ; start value
        imm 0x100
	mov imm ALU_B ; end value
loop:
	; conditional branch to end if k == b
	MOV K ALU_A
	imov loop_end addr
	test a_eq_b
	CMOV ADDR PC
	; set k = k+1

	ALU IMM C ADD
	MOV ALU K
	; set ram[k] = k
	MOV K ADDR
	MOV K RAM
	MOV K K
	; continue loop
	IMOV loop PC 
loop_end:
	IMOV start PC

      __endasm
    };

  end
  
endmodule
