print("Lua Counter test start")
local max_instr = 100
local signals = list_signals()
for k,v in pairs(signals.inputs) do print("Lua input", k,v) end
for k,v in pairs(signals.outputs) do print("Lua output", k,v) end

function get(name)
	assert(signals.outputs[name], "get: signal " .. tostring(name) .. " not found!")
	return (assert(get_signal(signals.outputs[name]), "get: error: " .. tostring(name)))
end
function set(name, value)
	assert(signals.inputs[name], "set: signal " .. tostring(name) .. " not found!")
	return (assert(set_signal(signals.inputs[name], value), "set: error: " .. tostring(name)))
end

function clk()
	set("clk", 1)
	eval()
	set("clk", 0)
	eval()
end

function reset()
	print("Lua Reset")
	eval()
	set("reset", 1)
	set("clk", 0)
	eval()
	clk()
	clk()
	clk()
	set("reset", 0)
	eval()
	print("Lua Reset complete!")
end

local i = 0
print("Lua running model")
reset()
while not is_finished() do
	local vsync, hsync, rgb = get("vsync"), get("hsync"), get("rgb")
	if ((vsync~=0) or (hsync~=0)) then print((vsync and "vsync") or "hsync") end
	clk()
	if i == max_instr then break end
	i = i + 1
end
print("Lua end")
