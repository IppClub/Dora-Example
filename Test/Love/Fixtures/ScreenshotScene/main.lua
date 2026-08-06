local requested = false
local callbackDone = false
local fileDone = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.02
end

local function verifyPixels(data)
	local width, height = data:getDimensions()
	assert(width == 128 and height == 64, tostring(width) .. "x" .. tostring(height))
	local r, g, b, a = data:getPixel(4, 4)
	assert(near(r, 1) and near(g, 1) and near(b, 0) and near(a, 1),
		("top-left pixel %.3f %.3f %.3f %.3f"):format(r, g, b, a))
	r, g, b, a = data:getPixel(100, 40)
	assert(near(r, 1) and near(g, 0) and near(b, 0) and near(a, 1),
		("background pixel %.3f %.3f %.3f %.3f"):format(r, g, b, a))
end

function love.update()
	if callbackDone and not fileDone and love.filesystem.getInfo("capture.png", "file") then
		local saved = love.image.newImageData("capture.png")
		verifyPixels(saved)
		fileDone = true
		print("LOVE_SCREENSHOT_FILE_PASS", saved:getDimensions())
	end
	if callbackDone and fileDone then
		love.event.quit()
	end
end

function love.draw()
	love.graphics.clear(1, 0, 0, 1)
	love.graphics.setColor(1, 1, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 20, 16)
	if not requested then
		requested = true
		love.graphics.captureScreenshot(function(data)
			verifyPixels(data)
			callbackDone = true
			print("LOVE_SCREENSHOT_CALLBACK_PASS", data:getDimensions())
		end)
		love.graphics.captureScreenshot("capture.png")
	end
end
