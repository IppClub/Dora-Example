local love = require("love")
local filesystem = love.filesystem
local graphics = love.graphics

filesystem.setIdentity("love-async-lifecycle-destroy")

local queued = false

function love.draw()
	graphics.clear(0.2, 0.2, 0.8, 1)
	if queued then return end
	queued = true
	graphics.captureScreenshot(function(image)
		assert(filesystem.write("destroyed-callback.txt", tostring(image:getSize())))
	end)
	graphics.captureScreenshot("destroyed.png")
	assert(filesystem.write("queued.txt", "1"))
end
