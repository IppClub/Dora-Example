local love = require("love")
local filesystem = love.filesystem
local graphics = love.graphics

filesystem.setIdentity("love-async-lifecycle-target")

local generation = (tonumber(filesystem.read("generation.txt") or "0") or 0) + 1
assert(filesystem.write("generation.txt", tostring(generation)))

local frames = 0
local currentCaptured = false
local oldQueued = false

function love.update()
	frames = frames + 1
	if generation == 2 then
		if filesystem.getInfo("current-callback.txt") then currentCaptured = true end
		if frames == 180 then
			assert(currentCaptured, "second-generation screenshot callback did not complete")
			assert(not filesystem.getInfo("old-callback.txt"),
				"first-generation screenshot callback entered the restarted state")
			assert(not filesystem.getInfo("old.png"),
				"first-generation screenshot filename completed after restart")
			assert(love.event.quit())
		end
	end
end
function love.draw()
	graphics.clear(generation == 1 and 0.8 or 0.1, generation == 2 and 0.8 or 0.1, 0.2, 1)
	if generation == 1 and not oldQueued then
		oldQueued = true
		graphics.captureScreenshot(function(image)
			assert(filesystem.write("old-callback.txt", tostring(image:getSize())))
		end)
		graphics.captureScreenshot("old.png")
		assert(love.event.quit("restart"))
	elseif generation == 2 and not currentCaptured and frames == 1 then
		graphics.captureScreenshot(function(image)
			local width, height = image:getDimensions()
			assert(width == 96 and height == 64)
			assert(filesystem.write("current-callback.txt",
				("%dx%d:%d"):format(width, height, image:getSize())))
		end)
		graphics.captureScreenshot("current.png")
	end
end
