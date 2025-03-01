`ifndef MCPU_GPU_H
`define MCPU_GPU_H

// addresses of control registers in VRAM
`define CTL_CONFIG_ADDR 8191
`define CTL_COLOR0_ADDR 8190
`define CTL_COLOR1_ADDR 8189
`define CTL_BORDER_ADDR 8188
`define CTL_PAGE_ADDR 8187


// bit indices in the ctl_config register:
// if set bitmapped graphics mode, text mode if unset
`define CTL_CONFIG_MODE 0 

// graphics mode: 2 bit framebuffer format: 00: 128x128_4bpp, 01: 256x256_1bpp, 10: 128x128_1bpp, 11: 128x64_4bpp
`define CTL_CONFIG_FB_MODE 2:1

// text mode: if set uses highest bit in character byte to select between color0 and color1("2-color text mode")
`define CTL_CONFIG_TEXT_COLOR 1 

// text mode: this bit replaces the already used highest character byte bit when in TEXT_COLOR mode
`define CTL_CONFIG_TEXT_EXTEND 2

// remaining bits are used as address extension(page) in some graphics modes and all text modes,
// and can be used to implement double-buffering
//`define CTL_CONFIG_PAGE_TEXT 5:3
//`define CTL_CONFIG_PAGE_FB_128x128_1BPP 4:3
//`define CTL_CONFIG_PAGE_FB_128x64_4BPP 3

// This module implements a simple 8-bit video adapter, supporting multiple text and graphics modes.
module mcpu_gpu(clk, hpos, vpos, display_on, rgb, data_in, data_out, vram_addr, vram_we);
  input clk;
  input display_on;
  input [8:0] hpos, vpos;
  input [12:0] vram_addr;
  input vram_we;
  input [7:0] data_in;
  output [7:0] data_out;
  output [3:0] rgb;
  
  // 8KB VRAM
  reg [7:0] vram[0:8191];
  
  // VRAM read on the data bus
  assign data_out = vram[vram_addr];

  // VRAM write on the data_bus
  always @(posedge clk) begin
    if (vram_we)
      vram[vram_addr] <= data_in;
  end
  
  // special purpose registers in VRAM
  wire [7:0] ctl_config, ctl_color0, ctl_color1, ctl_border, ctl_page;
  wire ctl_config_mode;
  assign ctl_config = vram[`CTL_CONFIG_ADDR];
  assign ctl_config_mode = ctl_config[`CTL_CONFIG_MODE];
  assign ctl_color0 = vram[`CTL_COLOR0_ADDR];
  assign ctl_color1 = vram[`CTL_COLOR1_ADDR];
  assign ctl_border = vram[`CTL_BORDER_ADDR];
  assign ctl_page = vram[`CTL_PAGE_ADDR];
  
  // create character ROM instance
  // 2KB character ROM, 1bit/pixel, 8x8 chars, 256 characters(codepage 437)
  wire [10:0] char_rom_addr;
  wire [7:0] char_data; // byte = 1 row of 8 pixels
  font_cp437_8x8 char_rom(
    .addr(char_rom_addr),
    .data(char_data)
  );

  // GPU-side VRAM scanout
  wire [12:0] vram_scan_addr;
  wire [7:0] vram_scan_value;
  assign vram_scan_value = vram[vram_scan_addr];
  assign vram_scan_addr = (ctl_config_mode ? fb_ram_addr : char_ram_addr) + {ctl_page, 5'b0};
  
  // character ROM display
  wire [12:0] char_ram_addr;
  wire [7:0] char_id;
  wire char_px;
  wire [3:0] char_rgb, char_mono_rgb, char_color_rgb;
  assign char_ram_addr = {3'b0, vpos[7:3], hpos[7:3]}; // 1KB/page
  assign char_id = ctl_config[`CTL_CONFIG_TEXT_COLOR] ? {ctl_config[`CTL_CONFIG_TEXT_EXTEND], vram_scan_value[6:0]} : vram_scan_value;
  assign char_rom_addr = {char_id, vpos[2:0]};
  assign char_px = char_data[~hpos[2:0]];
  assign char_mono_rgb = char_px ? ctl_color0[3:0] : ctl_color0[7:4];
  assign char_color_rgb = vram_scan_value[7] ? (char_px ? ctl_color1[3:0] : ctl_color1[7:4]) : (char_px ? ctl_color0[3:0] : ctl_color0[7:4]);
  assign char_rgb = ctl_config[`CTL_CONFIG_TEXT_COLOR] ? char_color_rgb : char_mono_rgb;
  
  // RAM framebuffer display
  wire [12:0] fb_ram_addr, fb_128x128_4bpp_addr, fb_256x256_1bpp_addr, fb_128x128_1bpp_addr, fb_128x64_4bpp_addr;
  wire [3:0] fb_rgb, fb_128x128_4bpp_rgb, fb_256x256_1bpp_rgb, fb_128x128_1bpp_rgb, fb_128x64_4bpp_rgb;
  assign fb_128x128_4bpp_rgb = (hpos[1] ? vram_scan_value[7:4] : vram_scan_value[3:0]);
  assign fb_128x128_4bpp_addr = {vpos[7:1], hpos[7:2]}; // 8KB/plane
  assign fb_256x256_1bpp_rgb = vram_scan_value[hpos[2:0]] ? ctl_color0[7:4] : ctl_color0[3:0];
  assign fb_256x256_1bpp_addr = {vpos[7:0], hpos[7:3]}; // 8KB/plane
  assign fb_128x128_1bpp_rgb = vram_scan_value[hpos[3:1]] ? ctl_color0[7:4] : ctl_color0[3:0];
  assign fb_128x128_1bpp_addr = {2'b0, vpos[7:1], hpos[7:4]}; // 2KB/plane
  assign fb_128x64_4bpp_rgb = (hpos[2] ? vram_scan_value[7:4] : vram_scan_value[3:0]);
  assign fb_128x64_4bpp_addr = {1'b0, vpos[7:1], hpos[7:3]}; // 4KB/page
  assign fb_ram_addr = mux_fb_ram_addr();
  assign fb_rgb = mux_fb_rgb();

  // select rgb source based on display_on, ctl_config_mode, between border, fb_rgb, fb_char
  wire [3:0] border;
  assign border = vpos[0]^hpos[0] ? ctl_border[3:0] : ctl_border[7:4];
  assign rgb = display_on ? (ctl_config_mode ? fb_rgb : char_rgb) : border;
  
  // multiplexer for fb_ram_addr
  function [12:0] mux_fb_ram_addr;
    case (ctl_config[`CTL_CONFIG_FB_MODE])
      2'b00: mux_fb_ram_addr = fb_128x128_4bpp_addr;
      2'b01: mux_fb_ram_addr = fb_256x256_1bpp_addr;
      2'b10: mux_fb_ram_addr = fb_128x128_1bpp_addr;
      2'b11: mux_fb_ram_addr = fb_128x64_4bpp_addr;
    endcase
  endfunction

  // multiplexer for fb_rgb
  function [3:0] mux_fb_rgb;
    case (ctl_config[`CTL_CONFIG_FB_MODE])
      2'b00: mux_fb_rgb = fb_128x128_4bpp_rgb;
      2'b01: mux_fb_rgb = fb_256x256_1bpp_rgb;
      2'b10: mux_fb_rgb = fb_128x128_1bpp_rgb;
      2'b11: mux_fb_rgb = fb_128x64_4bpp_rgb;
    endcase
  endfunction

endmodule
`endif
