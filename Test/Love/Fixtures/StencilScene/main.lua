local shapeCanvas
local actionCanvas
local rendered = false
local drawFrames = 0
local screenshotRequested = false
local screenshotVerified = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.04
end

local function verifyPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s pixel %.3f %.3f %.3f %.3f"):format(label, r, g, b, a))
end

local function verifyScreenshot(data)
	assert(data:getWidth() == 192 and data:getHeight() == 96)
	verifyPixel(data, 18, 18, {1, 0, 0, 1}, "composited stencil equal rectangle")
	verifyPixel(data, 56, 40, {1, 1, 1, 1}, "composited stencil and scissor")
	verifyPixel(data, 170, 24, {0, 1, 0, 1}, "composited wrapping action")
end

function love.load()
	shapeCanvas = love.graphics.newCanvas(96, 64)
	actionCanvas = love.graphics.newCanvas(64, 32)
end

function love.update()
	if not rendered then
		return
	end

	local shape = shapeCanvas:newImageData()
	verifyPixel(shape, 10, 10, {1, 0, 0, 1}, "equal rectangle")
	verifyPixel(shape, 80, 10, {0, 0, 1, 1}, "color writes disabled")
	verifyPixel(shape, 48, 32, {1, 1, 1, 1}, "stencil and scissor")
	verifyPixel(shape, 48, 20, {0, 1, 0, 1}, "greater compare")

	local actions = actionCanvas:newImageData()
	verifyPixel(actions, 4, 4, {1, 1, 1, 1}, "invert")
	verifyPixel(actions, 20, 16, {1, 0, 0, 1}, "saturating increment/decrement")
	verifyPixel(actions, 50, 16, {0, 1, 0, 1}, "wrapping increment/decrement")

	if not screenshotVerified or not love.filesystem.getInfo("stencil.png", "file") then
		return
	end
	print("LOVE_STENCIL_PASS", shape:getDimensions(), actions:getDimensions())
	assert(love.event.quit())
end

function love.draw()
	if screenshotRequested then
		return
	end

	love.graphics.setCanvas(shapeCanvas)
	assert(not pcall(love.graphics.stencil, function() end))
	love.graphics.setCanvas({shapeCanvas, stencil = true})
	love.graphics.clear(0, 0, 1, 1)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 0, 0, 48, 64)
	end, "replace", 1)
	love.graphics.setStencilTest("equal", 1)
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 96, 64)

	love.graphics.stencil(function()
		love.graphics.circle("fill", 48, 32, 16)
	end, "replace", 2, true)
	love.graphics.setStencilTest("greater", 1)
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 96, 64)

	love.graphics.push("all")
	love.graphics.setStencilTest("never", 0)
	love.graphics.pop()
	love.graphics.setScissor(40, 24, 16, 16)
	love.graphics.setStencilTest("equal", 2)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", 0, 0, 96, 64)
	love.graphics.setScissor()
	love.graphics.setStencilTest()

	love.graphics.setCanvas({actionCanvas, stencil = true})
	love.graphics.clear(0, 0, 1, 1)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 0, 0, 64, 32)
	end, "replace", 255)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 0, 0, 32, 32)
	end, "increment", 0, true)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 32, 0, 32, 32)
	end, "incrementwrap", 0, true)
	love.graphics.setStencilTest("equal", 255)
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 64, 32)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 0, 0, 32, 32)
	end, "decrement", 0, true)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 32, 0, 32, 32)
	end, "decrementwrap", 0, true)
	love.graphics.setStencilTest("equal", 255)
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 64, 32)
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", 0, 0, 8, 8)
	end, "invert", 0, true)
	love.graphics.setStencilTest("equal", 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", 0, 0, 64, 32)
	love.graphics.setStencilTest()

	love.graphics.setCanvas()
	love.graphics.clear(0.05, 0.05, 0.05, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(shapeCanvas, 8, 8)
	love.graphics.draw(actionCanvas, 120, 8)
	drawFrames = drawFrames + 1
	rendered = true
	-- Match the Canvas visual-evidence fixture: let a newly-created render target
	-- complete one host frame before capturing its composition on Metal.
	if drawFrames >= 2 and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("stencil.png")
		love.graphics.captureScreenshot(function(data)
			verifyScreenshot(data)
			screenshotVerified = true
			print("LOVE_STENCIL_VISUAL_EVIDENCE_PASS", data:getDimensions())
		end)
	end
end
