
module MCPU_GPU(clk, reset, hsync, vsync, rgb, addr_in, write_ena, d_in, d_out);
  input clk, reset;
  input [12:0] addr_in;
  input write_ena;
  input [7:0] d_in;
  output [7:0] d_out;
  output vsync,hsync;
  output [3:0] rgb;
  
  // 8KB VRAM
  reg [7:0] vram[0:8191];
  
  // CPU-side VRAM write/read
  assign d_out = vram[addr_in];
  always @(posedge clk) begin
      if (write_ena) begin
        vram[addr_in] <= d_in;
      end
  end
  
  // GPU-side VRAM read
  wire [12:0] vram_addr;
  wire [7:0] vram_read_value;
  assign vram_read_value = vram[vram_addr];
  assign vram_addr = ctl_config[0] ? fb_ram_addr : char_ram_addr;
  
  // special purpose registers in VRAM
  wire [7:0] ctl_config, ctl_color, ctl_border;
  assign ctl_config = vram[8191];
  assign ctl_color = vram[8190];
  assign ctl_border = vram[8189];
  
  // create video signal generator instance
  wire display_on;
  wire [8:0] hpos, vpos;
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );
  
  // create character ROM instance
  wire [10:0] char_rom_addr;
  wire [7:0] char_data;
  font_cp437_8x8 char_rom(
    .addr(char_rom_addr),
    .data(char_data)
  );
  
  // character ROM display
  wire [12:0] char_ram_addr;
  wire [7:0] char_id;
  wire char_px;
  wire [3:0] rgb_text;
  assign char_ram_addr = {ctl_config[7:5], vpos[7:3], hpos[7:3]};
  assign char_id = vram_read_value;
  assign char_rom_addr = {char_id, vpos[2:0]};
  assign char_px = char_data[~hpos[2:0]];
  assign rgb_text = char_px ? ctl_color[3:0] : ctl_color[7:4];
  
  // RAM framebuffer display
  wire [6:0] px_x, px_y;
  wire [12:0] fb_ram_addr;
  wire [3:0] rgb_fb;
  wire [3:0] rgb_fb_128x128_4bpp = (hpos[1] ? vram_read_value[7:4] : vram_read_value[3:0]);
  wire [3:0] rgb_fb_256x256_1bpp = vram_read_value[hpos[2:0]] ? ctl_color[7:4] : ctl_color[3:0];
  always @(*) begin
    case (ctl_config[2:1])
      2'b00: fb_ram_addr = {vpos[7:1], hpos[7:2]};
      2'b01: fb_ram_addr = {vpos[7:0], hpos[7:3]};
      2'b10: fb_ram_addr = {vpos[7:1], hpos[7:2]};
      2'b11: fb_ram_addr = {vpos[7:1], hpos[7:2]};
    endcase
    case (ctl_config[2:1])
      2'b00: rgb_fb = rgb_fb_128x128_4bpp;
      2'b01: rgb_fb = rgb_fb_256x256_1bpp;
      2'b10: rgb_fb = 4'b0101;
      2'b11: rgb_fb = 4'b0110;
    endcase
  end
  
  localparam foo = 128;
  localparam bar = 256;
  initial begin
    vram[0] = 8'b10000001;
    vram[32] = 8'b10000001;
    vram[64] = 8'b10000001;
    vram[96] = 8'b10000001;
    
    vram[bar+0] = 0;
    vram[bar+1] = 0;
    vram[bar+64] = 0;
    vram[bar+65] = 0;
    vram[bar+128] = 0;
    vram[bar+129] = 0;
    vram[bar+192] = 0;
    vram[bar+193] = 0;
    
    vram[foo+0] = 72;
    vram[foo+1] = 69;
    vram[foo+2] = 76;
    vram[foo+3] = 76;
    vram[foo+4] = 79;
    vram[foo+5] = 1;
    vram[foo+6] = 87;
    vram[foo+7] = 79;
    vram[foo+8] = 82;
    vram[foo+9] = 76;
    vram[foo+10] = 68;
    vram[foo+11] = 33;
    vram[foo+12] = 2;
    vram[foo+13] = 0;
    
    vram[(2**13)-3] = 8'b11001111; // border
    vram[(2**13)-2] = 8'b01001110; // color
    vram[(2**13)-1] = 8'b00000101; // control register
  end
  
  always @(*) begin
    if (!display_on)
      // outside of range, use border pattern
      rgb = vpos[0]^hpos[0] ? ctl_border[3:0] : ctl_border[7:4]; // grey/black checkerboard
    else
      // in range, fill using framebuffer or text function
      rgb = ctl_config[0] ? rgb_fb : rgb_text;
    
  end
  
endmodule
