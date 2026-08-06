local love = require("love")
local filesystem = love.filesystem

filesystem.setIdentity("love-event-restart-steady")
local loads = (tonumber(filesystem.read("loads.txt") or "0") or 0) + 1
assert(filesystem.write("loads.txt", tostring(loads)))
print("LOVE_EVENT_RESTART_STEADY_LOAD", loads)

function love.draw()
	love.graphics.clear(0.1, 0.2, 0.7, 1)
end
