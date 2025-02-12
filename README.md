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

| Address |           Usage |
| ------- | --------------- |
|  0x9fff | CTL_CONFIG_ADDR |
|  0x9ffe | CTL_COLOR0_ADDR |
|  0x9ffd | CTL_COLOR1_ADDR |
|  0x9ffc | CTL_BORDER_ADDR |

## Misc commands

```
# remove old build artifacts
rm -rf obj_dir irom.hex

# run nanoasm on the program for the instruction ROM
node ~/stuff/mcpu/mcpu_nanoasm/src/asmmain.js ~/stuff/mcpu/mcpu_nanoasm/examples/mcpu_asm.json irom.asm > irom.hex

# build the Lua interpreter-wrapped module
./build_and_run.sh mcpu_top.v

# run the module with the test script
./obj_dir/Vmcpu_top test_mcpu_top.lua +verilator+rand+reset+2

```