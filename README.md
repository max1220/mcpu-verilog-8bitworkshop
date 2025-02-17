# mcpu-verilog-8bitworkshop

[Open this project in 8bitworkshop](http://8bitworkshop.com/redir.html?platform=verilog&githubURL=https%3A%2F%2Fgithub.com%2Fmax1220%2Fmcpu-verilog-8bitworkshop&file=mcpu_top.v).


This repository also contains some support files to run the CPU using verilator outside the browser.

## Memory map

|   From |     To |  Usage |
| ------ | ------ | ------ |
| 0x0000 | 0x3fff |   DRAM |
| 0x4000 | 0x7fff |   IROM |
| 0x8000 | 0x9fff |   VRAM |

## Special registers in VRAM

| Address |       Name | Usage |
| ------- | ---------- | ----- |
|  0x9fff | CTL_CONFIG | Main control/graphics mode select register
|  0x9ffe | CTL_COLOR0 | Primary fg/bg colors used in 1-bit text/framebuffer modes
|  0x9ffd | CTL_COLOR1 | Secondary fg/bg colors used in two-color text mode
|  0x9ffc | CTL_BORDER | Border pattern colors
|  0x9ffb |   CTL_PAGE | Offset in VRAM added to scanout address, to enable scrolling/double buffering. Value is left-shifted 5x before add.

### CTL_CONFIG bits

| Bits |                   Name | Usage |
| ---- | ---------------------- | ----- |
| 0    | CTL_CONFIG_MODE        | if set is fb graphics mode, text mode otherwise
| 2-1  | CTL_CONFIG_FB_MODE     | fb mode: 2 bit framebuffer format, see below
| 1    | CTL_CONFIG_TEXT_COLOR  | text mode: if set uses 2-color mode(highest bit in character byte selects between color0 and color1)
| 2    | CTL_CONFIG_TEXT_EXTEND | text mode: this bit replaces the already used highest character byte bit when the CTL_CONFIG_TEXT_COLOR bit is set.

#### Framebuffer formats:

| Bits |         Name | Page size |
| ---- | ------------ | --------- |
| 00   | 128x128_4bpp | 8KB/page
| 01   | 256x256_1bpp | 8KB/page
| 10   | 128x128_1bpp | 2KB/page
| 11   | 128x64_4bpp  | 4KB/page


## Misc commands

```
# remove old build artifacts
rm -rf obj_dir irom.hex

# run nanoasm on the program for the instruction ROM
node ~/stuff/mcpu/mcpu_nanoasm/src/asmmain.js ~/stuff/mcpu/mcpu_nanoasm/examples/mcpu_asm.json irom.asm | tee irom.hex

# build the Lua interpreter-wrapped module
./build_and_run.sh mcpu_top.v

# run the module with the test script
./obj_dir/Vmcpu_top test_mcpu_top.lua +verilator+rand+reset+2

# combined full rebuild & run:
clear && node ~/stuff/mcpu/mcpu_nanoasm/src/asmmain.js ~/stuff/mcpu/mcpu_nanoasm/examples/mcpu_asm.json irom.asm > irom.hex && ./build_and_run.sh mcpu_top.v test_mcpu_top.lua

# combined asm re-compile and run:
node ~/stuff/mcpu/mcpu_nanoasm/src/asmmain.js ~/stuff/mcpu/mcpu_nanoasm/examples/mcpu_asm.json irom.asm > irom.hex && ./obj_dir/Vmcpu_top test_mcpu_top.lua +verilator+rand+reset+2

```