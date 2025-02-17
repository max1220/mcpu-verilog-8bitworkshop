local signals = list_signals()

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
	eval()
	set("reset", 1)
	set("clk", 0)
	eval()
	clk()
	clk()
	clk()
	set("reset", 0)
	eval()
end
function handle_frame(rows)
	for y=1, #rows, 2 do
		local row = rows[y]
		local nrow = rows[y+1] or row
		local row_str = {}
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
			table.insert(row_str, col_a..col_b.."▀")
		end
		io.write(table.concat(row_str, "") .. "\027[0m\n")
	end
	io.flush()
end

local i = 0
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
		print("video frame at:", i, "----------------")
		handle_frame(rows)
		rows = {}
	end
	if not hsync then
		table.insert(row, get("rgb"))
	end
	last_hsync, last_vsync = hsync, vsync
	clk()
	i = i + 1
end
