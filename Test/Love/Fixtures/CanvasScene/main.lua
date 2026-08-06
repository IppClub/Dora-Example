local canvas
local ready = false
local frames = 0
local screenshotRequested = false
local screenshotVerified = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.03
end

local function verifyScreenshot(data)
	local width, height = data:getDimensions()
	assert(width == 320 and height == 180, ("unexpected Canvas screenshot %dx%d"):format(width, height))
	local r, g, b, a = data:getPixel(45, 35)
	assert(near(r, 0) and near(g, 0) and near(b, 1) and near(a, 1), "Canvas blue pass pixel mismatch")
	r, g, b, a = data:getPixel(65, 55)
	assert(near(r, 0) and near(g, 1) and near(b, 0) and near(a, 1), "Canvas green post-pass pixel mismatch")
end

function love.load()
	canvas = love.graphics.newCanvas(80, 60, {
		dpiscale = 1,
		msaa = 0,
		format = "rgba8",
		type = "2d",
		readable = true,
		mipmaps = "none",
	})
	canvas:setFilter("nearest")
	assert(canvas:getWidth() == 80 and canvas:getHeight() == 60)
	assert(canvas:getPixelWidth() == 80 and canvas:getPixelHeight() == 60)
	assert(canvas:getDPIScale() == 1 and canvas:getFormat() == "rgba8")
	assert(canvas:getMSAA() == 0 and canvas:isReadable())
end

function love.draw()
	love.graphics.clear(0, 0, 0, 1)

	love.graphics.setCanvas(canvas)
	assert(love.graphics.getCanvas() == canvas)
	-- Love graphics dimensions always describe the virtual window, even while a
	-- Canvas is the current render target. Canvas dimensions are queried on it.
	assert(love.graphics.getWidth() == 320 and love.graphics.getHeight() == 180)
	love.graphics.clear(1, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", 0, 0, 80, 60)

	-- The second clear must discard the earlier white pass on the same Canvas.
	love.graphics.clear(0, 0, 1, 1)
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.rectangle("fill", 10, 10, 20, 20)

	love.graphics.push("all")
	love.graphics.setCanvas()
	assert(love.graphics.getCanvas() == nil)
	love.graphics.pop()
	assert(love.graphics.getCanvas() == canvas)

	love.graphics.setCanvas()
	assert(love.graphics.getCanvas() == nil)
	assert(love.graphics.getWidth() == 320 and love.graphics.getHeight() == 180)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(canvas, 40, 30, 0, 2, 2)

	if not ready then
		ready = true
		print("LOVE_CANVAS_SCENE_READY", canvas:getDimensions())
	end
	if frames >= 2 and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("canvas-postprocess.png")
		love.graphics.captureScreenshot(function(data)
			verifyScreenshot(data)
			screenshotVerified = true
			print("LOVE_CANVAS_VISUAL_EVIDENCE_PASS", data:getDimensions())
		end)
	end
end

function love.update()
	frames = frames + 1
	if frames > 240 and not screenshotVerified then
		error("Canvas visual evidence screenshot timed out")
	end
	if screenshotVerified and love.filesystem.getInfo("canvas-postprocess.png", "file") then
		assert(love.event.quit())
	end
end
