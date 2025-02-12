local bit = require("bit32")

print("Lua Counter test start")
--local max_instr = 100
local max_instr = math.huge
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
local function handle_frame(rows)
	local h = #rows
	local w = #rows[1]
	print("Video frame: ", w,h, "-------------------")
	for y=1, h, 2 do
		local row = rows[y]
		local nrow = rows[y+1] or row
		for x=1, #row do
			local px_a = row[x]
			local col_a = "\027[" .. 30+px_a .. "m"
			if px_a > 7 then
				col_a = "\027[" .. 90+px_a-8 .. "m"
			end
			local px_b = nrow[x] or 0
			local col_b = "\027[" .. 40+px_b .. "m"
			if px_b > 7 then
				col_b = "\027[" .. 100+px_b-8 .. "m"
			end
			io.write(col_a..col_b.."▀")
		end
		io.write("\027[0m\n")
	end
	io.flush()
end

local i = 0
print("Lua running model")
reset()
local rows, row = {}, {}
local last_hsync, last_vsync = false, false
while not is_finished() do
	local vsync, hsync = get("vsync")~=0, get("hsync")~=0
	if hsync and not last_hsync then
		table.insert(rows, row)
		row = {}
	end
	if vsync and not last_vsync then
		print("vsync at:", i)
		handle_frame(rows)
		rows = {}
	end
	if not hsync then
		table.insert(row, get("rgb"))
	end
	last_hsync, last_vsync = hsync, vsync
	clk()
	if i == max_instr then break end
	i = i + 1
end
print("Lua end")
