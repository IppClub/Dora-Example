local canvas
local scopedCanvas
local mrtA
local mrtB
local depthStencilCanvas
local depthStencilAttachment
local subtractCanvas
local frames = 0
local rendered = false

local function close(actual, expected)
	return math.abs(actual - expected) < 0.02
end

local function assertPixel(data, x, y, red, green, blue, alpha)
	local actualRed, actualGreen, actualBlue, actualAlpha = data:getPixel(x, y)
	assert(close(actualRed, red), ("red mismatch at %d,%d: %.4f"):format(x, y, actualRed))
	assert(close(actualGreen, green), ("green mismatch at %d,%d: %.4f"):format(x, y, actualGreen))
	assert(close(actualBlue, blue), ("blue mismatch at %d,%d: %.4f"):format(x, y, actualBlue))
	assert(close(actualAlpha, alpha), ("alpha mismatch at %d,%d: %.4f"):format(x, y, actualAlpha))
end

function love.load()
	canvas = love.graphics.newCanvas(32, 16)
	scopedCanvas = love.graphics.newCanvas(32, 16)
	mrtA = love.graphics.newCanvas(32, 16)
	mrtB = love.graphics.newCanvas(32, 16)
	depthStencilCanvas = love.graphics.newCanvas(32, 16)
	subtractCanvas = love.graphics.newCanvas(32, 16)
	local formats = love.graphics.getCanvasFormats(false)
	assert(formats.depth24stencil8,
		"active renderer must expose a writable depth24stencil8 Canvas")
	depthStencilAttachment = love.graphics.newCanvas(32, 16, {
		format = "depth24stencil8",
		readable = false,
	})
	assert(depthStencilAttachment:getFormat() == "depth24stencil8")
	assert(not depthStencilAttachment:isReadable())
	assert(not pcall(depthStencilAttachment.newImageData, depthStencilAttachment))
	local red, green, blue, alpha = love.graphics.getColorMask()
	assert(red and green and blue and alpha)
	love.graphics.setColorMask(true, false, true, false)
	red, green, blue, alpha = love.graphics.getColorMask()
	assert(red and not green and blue and not alpha)
	love.graphics.setColorMask()
end

function love.update()
	frames = frames + 1
	if rendered and frames >= 2 then
		local pixels = canvas:newImageData()
		assertPixel(pixels, 8, 8, 0.2, 1.0, 0.4, 0.25)
		assertPixel(pixels, 24, 8, 0.9, 0.3, 0.7, 0.25)

		local scoped = scopedCanvas:newImageData()
		assertPixel(scoped, 12, 8, 0.9, 0.3, 0.4, 0.0)
		assertPixel(scoped, 2, 2, 0.2, 0.3, 0.4, 0.8)
		assertPixel(scoped, 30, 14, 0.2, 0.3, 0.4, 0.8)

		local first = mrtA:newImageData()
		local second = mrtB:newImageData()
		assertPixel(first, 8, 8, 0.1, 0.8, 0.3, 0.6)
		assertPixel(second, 8, 8, 0.2, 0.3, 0.7, 0.1)

		local depthStencil = depthStencilCanvas:newImageData()
		assertPixel(depthStencil, 4, 8, 0.0, 0.0, 1.0, 1.0)
		assertPixel(depthStencil, 28, 8, 0.0, 1.0, 0.0, 1.0)

		local subtract = subtractCanvas:newImageData()
		assertPixel(subtract, 16, 8, 0.6, 0.6, 0.55, 0.75)
	print("LOVE_COLOR_MASK_PASS scoped mrt custom-depth-stencil subtract")
		assert(love.event.quit())
	end
end

function love.draw()
	if rendered then
		love.graphics.clear(0, 0, 0, 1)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(canvas, 16, 8)
		return
	end

	-- Independent channel writes and an unscissored masked clear.
	love.graphics.setCanvas({canvas, depthstencil = true})
	love.graphics.clear(0.2, 0.3, 0.4, 0.8)
	love.graphics.setBlendMode("replace", "alphamultiply")
	love.graphics.setColorMask(false, false, false, true)
	love.graphics.push("all")
	love.graphics.translate(100, 100)
	love.graphics.setBlendMode("add", "alphamultiply")
	love.graphics.setDepthMode("never", true)
	love.graphics.setMeshCullMode("front")
	love.graphics.setStencilTest("never", 3)
	love.graphics.clear(1, 0, 0, 0.25)
	love.graphics.pop()
	love.graphics.push("all")
	love.graphics.setColorMask(false, true, false, false)
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 16, 16)
	love.graphics.setColorMask(true, false, true, false)
	love.graphics.setColor(0.9, 0.1, 0.7, 1)
	love.graphics.rectangle("fill", 16, 0, 16, 16)
	love.graphics.pop()
	love.graphics.setColorMask()
	love.graphics.setBlendMode("alpha", "alphamultiply")

	-- A table color plus false/false requests color-only clear. The scissor and
	-- R/A mask must preserve every pixel and channel outside their exact scope,
	-- including an alpha value of zero.
	love.graphics.setCanvas(scopedCanvas)
	love.graphics.clear(0.2, 0.3, 0.4, 0.8)
	love.graphics.setColorMask(true, false, false, true)
	love.graphics.setScissor(8, 4, 16, 8)
	love.graphics.clear({0.9, 0.1, 0.2, 0.0}, false, false)
	love.graphics.setScissor()
	love.graphics.setColorMask()

	-- Love's table overload assigns one color per active Canvas. An empty table
	-- intentionally skips attachment zero in the second clear.
	love.graphics.setCanvas(mrtA)
	love.graphics.clear(0.1, 0.2, 0.3, 0.4)
	love.graphics.setCanvas(mrtB)
	love.graphics.clear(0.5, 0.6, 0.7, 0.8)
	love.graphics.setCanvas({mrtA, mrtB})
	love.graphics.setColorMask(false, true, false, true)
	love.graphics.clear({0.9, 0.8, 0.7, 0.6}, {0.4, 0.3, 0.2, 0.1}, false, false)
	love.graphics.setColorMask(true, false, false, false)
	love.graphics.clear({}, {0.2, 0.0, 0.0, 0.0}, false, false)
	love.graphics.setColorMask()

	-- Scissored stencil/depth clears are geometry-backed too. Stencil 5 is
	-- written only on the right half, which first receives green. Depth 0.2 on
	-- the same half then rejects a z=0 blue draw, while the left half accepts it.
	-- A custom depth/stencil Canvas is also a complete render target by itself.
	-- Clear it first, then reuse the same attachment with a color Canvas.
	love.graphics.setCanvas({depthstencil = depthStencilAttachment})
	love.graphics.clear(false, 0, 1.0)
	love.graphics.setCanvas({depthStencilCanvas, depthstencil = depthStencilAttachment})
	local targets = love.graphics.getCanvas()
	assert(type(targets) == "table")
	-- Love 11.5 returns the table-of-render-targets form whenever an explicit
	-- depth/stencil attachment is active. Each target is {canvas, mipmap=1}.
	assert(type(targets[1]) == "table" and targets[1][1] == depthStencilCanvas
		and targets[1].mipmap == 1)
	assert(type(targets.depthstencil) == "table"
		and targets.depthstencil[1] == depthStencilAttachment
		and targets.depthstencil.mipmap == 1)
	love.graphics.clear({0.25, 0.0, 0.0, 1.0}, 0, 1.0)
	love.graphics.setScissor(16, 0, 16, 16)
	love.graphics.clear(false, 5, false)
	love.graphics.setScissor()
	love.graphics.setStencilTest("equal", 5)
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.rectangle("fill", 0, 0, 32, 16)
	love.graphics.setStencilTest()
	love.graphics.setScissor(16, 0, 16, 16)
	love.graphics.clear(false, false, 0.2)
	love.graphics.setScissor()
	love.graphics.setDepthMode("less", false)
	love.graphics.setColor(0, 0, 1, 1)
	love.graphics.rectangle("fill", 0, 0, 32, 16)
	love.graphics.setDepthMode()

	-- Love subtract uses reverse subtraction: destination minus source. Alpha
	-- factors preserve the existing destination alpha in premultiplied mode.
	love.graphics.setCanvas(subtractCanvas)
	love.graphics.clear(0.8, 0.7, 0.6, 0.75)
	love.graphics.setBlendMode("subtract", "premultiplied")
	love.graphics.setColor(0.2, 0.1, 0.05, 0.4)
	love.graphics.rectangle("fill", 0, 0, 32, 16)
	love.graphics.setBlendMode("alpha", "alphamultiply")

	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
	rendered = true
end
