local canvas
local hdrCanvas
local r8Canvas
local rg16Canvas
local rgba32fCanvas
local writeOnlyCanvas
local mipCanvas
local arrayCanvas
local cubeCanvas
local volumeCanvas
local canvasFormats
local optionalCanvases = {}
local rendered = false
local readbackDone = false
local drawRejectionChecked = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.04
end

local function verifyPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s pixel %.3f %.3f %.3f %.3f"):format(label, r, g, b, a))
end

function love.load()
	canvasFormats = love.graphics.getCanvasFormats(true)
	assert(canvasFormats.rgba8, "readable rgba8 Canvas support is required")
	canvas = love.graphics.newCanvas(32, 24, {format = "rgba8", msaa = 4})
	if canvasFormats.hdr then
		hdrCanvas = love.graphics.newCanvas(16, 12, {format = "hdr"})
	end
	local optionalFormats = {"r8", "rg16", "rgba32f"}
	for _, format in ipairs(optionalFormats) do
		if canvasFormats[format] then
			optionalCanvases[format] = love.graphics.newCanvas(8, 4, {format = format})
		else
			local ok, message = pcall(love.graphics.newCanvas, 8, 4, {format = format})
			assert(not ok and tostring(message):find("does not support Love Canvas format", 1, true),
				format .. " capability rejection mismatch")
		end
	end
	r8Canvas = optionalCanvases.r8
	rg16Canvas = optionalCanvases.rg16
	rgba32fCanvas = optionalCanvases.rgba32f
	writeOnlyCanvas = love.graphics.newCanvas(8, 8, {readable = false})
	local textureTypes = love.graphics.getTextureTypes()
	assert(textureTypes.array and textureTypes.cube and textureTypes.volume,
		"Metal layered Canvas texture types are required")
	mipCanvas = love.graphics.newCanvas(16, 16, {mipmaps = "manual"})
	arrayCanvas = love.graphics.newCanvas(16, 16, 3, {type = "array", mipmaps = "auto"})
	cubeCanvas = love.graphics.newCanvas(16, 16, {type = "cube", mipmaps = "manual"})
	volumeCanvas = love.graphics.newCanvas(16, 16, 4, {type = "volume", mipmaps = "manual"})
	assert(not pcall(writeOnlyCanvas.newImageData, writeOnlyCanvas))
	assert(not pcall(canvas.newImageData, canvas, 2))
	assert(not pcall(canvas.newImageData, canvas, 1, 2))
	assert(not pcall(canvas.newImageData, canvas, 1, 1, -1, 0, 1, 1))
end

function love.update()
	if rendered and not readbackDone then
		local full = canvas:newImageData()
		assert(full:getWidth() == 32 and full:getHeight() == 24 and full:getFormat() == "rgba8")
		verifyPixel(full, 2, 2, {1, 1, 0, 1}, "MSAA full yellow")
		verifyPixel(full, 20, 15, {0, 0, 1, 1}, "MSAA full blue")

		local crop = canvas:newImageData(1, 1, 4, 3, 8, 6)
		assert(crop:getWidth() == 8 and crop:getHeight() == 6)
		verifyPixel(crop, 0, 0, {1, 1, 0, 1}, "crop top-left")
		verifyPixel(crop, 7, 5, {0, 0, 1, 1}, "crop bottom-right")

		local hdr
		if hdrCanvas then
			hdr = hdrCanvas:newImageData()
			assert(hdr:getWidth() == 16 and hdr:getHeight() == 12 and hdr:getFormat() == "rgba16f")
			assert(hdr:getSize() == 16 * 12 * 8 and #hdr:getString() == 16 * 12 * 8)
			verifyPixel(hdr, 8, 6, {1, 0, 1, 1}, "HDR native")
		end

		if r8Canvas then
			local r8 = r8Canvas:newImageData()
			assert(r8:getFormat() == "r8" and r8:getSize() == 8 * 4)
			verifyPixel(r8, 4, 2, {0.25, 0, 0, 1}, "R8 native")
		end
		if rg16Canvas then
			local rg16 = rg16Canvas:newImageData()
			assert(rg16:getFormat() == "rg16" and rg16:getSize() == 8 * 4 * 4)
			verifyPixel(rg16, 4, 2, {0.25, 0.5, 0, 1}, "RG16 native")
		end
		if rgba32fCanvas then
			local rgba32f = rgba32fCanvas:newImageData()
			assert(rgba32f:getFormat() == "rgba32f" and rgba32f:getSize() == 8 * 4 * 16)
			verifyPixel(rgba32f, 4, 2, {0.25, 0.5, 0.75, 1}, "RGBA32F native")
		end

		local mip = mipCanvas:newImageData(1, 3)
		assert(mip:getWidth() == 4 and mip:getHeight() == 4)
		verifyPixel(mip, 2, 2, {1, 0, 0, 1}, "manual 2D mip")
		local arrayMip = arrayCanvas:newImageData(3, 3)
		assert(arrayMip:getWidth() == 4 and arrayMip:getHeight() == 4)
		verifyPixel(arrayMip, 2, 2, {0, 1, 0, 1}, "auto Array layer mip")
		local cubeMip = cubeCanvas:newImageData(6, 3)
		verifyPixel(cubeMip, 2, 2, {0, 0, 1, 1}, "manual Cube face mip")
		local volumeMip = volumeCanvas:newImageData(1, 3)
		assert(volumeCanvas:getDepth(3) == 1)
		verifyPixel(volumeMip, 2, 2, {1, 1, 0, 1}, "manual Volume slice mip")

		readbackDone = true
		print("LOVE_CANVAS_READBACK_PASS", full:getDimensions(), crop:getDimensions(),
			"hdr=" .. tostring(hdrCanvas ~= nil), "r8=" .. tostring(r8Canvas ~= nil),
			"rg16=" .. tostring(rg16Canvas ~= nil), "rgba32f=" .. tostring(rgba32fCanvas ~= nil))
		love.event.quit()
	end
end

function love.draw()
	if not rendered then
		love.graphics.setCanvas(canvas)
		love.graphics.clear(0, 0, 1, 1)
		love.graphics.setColor(1, 1, 0, 1)
		love.graphics.rectangle("fill", 0, 0, 8, 6)

		if hdrCanvas then
			love.graphics.setCanvas(hdrCanvas)
			love.graphics.clear(1, 0, 1, 1)
		end
		for _, optionalCanvas in pairs(optionalCanvases) do
			love.graphics.setCanvas(optionalCanvas)
			love.graphics.clear(0.25, 0.5, 0.75, 1)
		end

		love.graphics.setCanvas(mipCanvas)
		love.graphics.clear(1, 0, 0, 1)
		love.graphics.setCanvas()
		mipCanvas:generateMipmaps()

		for layer = 1, 3 do
			love.graphics.setCanvas(arrayCanvas, layer, 1)
			love.graphics.clear(0, 1, 0, 1)
		end
		love.graphics.setCanvas()

		for face = 1, 6 do
			love.graphics.setCanvas(cubeCanvas, face, 1)
			love.graphics.clear(0, 0, 1, 1)
		end
		love.graphics.setCanvas()
		cubeCanvas:generateMipmaps()

		for slice = 1, 4 do
			love.graphics.setCanvas(volumeCanvas, slice, 1)
			love.graphics.clear(1, 1, 0, 1)
		end
		love.graphics.setCanvas()
		volumeCanvas:generateMipmaps()
		love.graphics.setCanvas()
		rendered = true
	end

	if not drawRejectionChecked then
		local ok, message = pcall(canvas.newImageData, canvas)
		assert(not ok and tostring(message):find("outside love.draw", 1, true))
		drawRejectionChecked = true
	end

	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(canvas, 8, 8)
	if hdrCanvas then
		love.graphics.draw(hdrCanvas, 64, 8, 0, 2, 2)
	end
end
