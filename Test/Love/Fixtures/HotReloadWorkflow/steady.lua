local love = require("love")

love.filesystem.setIdentity("p6-hot-reload-steady")

function love.load()
	local previous = tonumber(love.filesystem.read("loads.txt") or "0") or 0
	assert(love.filesystem.write("loads.txt", tostring(previous + 1)))
	print("LOVE_HOT_RELOAD_STEADY_LOAD", previous + 1)
end

function love.update(_) end

