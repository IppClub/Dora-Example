local formatCanvases = {}
local msaaCanvas
local hdrCanvas
local writeOnlyCanvas
local requested = false
local callbackDone = false

local formatNames = {
	"normal", "hdr", "r8", "rg8", "rgba8", "srgba8",
	"r16", "rg16", "rgba16", "r16f", "rg16f", "rgba16f",
	"r32f", "rg32f", "rgba32f", "rgba4", "rgb5a1", "rgb565",
	"rgb10a2", "rg11b10f",
}

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
	local readableFormats = love.graphics.getCanvasFormats(true)
	local supplied = {sentinel = "kept"}
	assert(love.graphics.getCanvasFormats(false, supplied) == supplied)
	assert(supplied.sentinel == "kept")
	assert(readableFormats.normal == readableFormats.rgba8)
	assert(readableFormats.hdr == readableFormats.rgba16f)
	assert(not readableFormats.la8 and not readableFormats.depth24stencil8)

	local created = 0
	for _, format in ipairs(formatNames) do
		if readableFormats[format] then
			local ok, canvas = pcall(love.graphics.newCanvas, 16, 16, {
				format = format,
				readable = true,
			})
			assert(ok, ("getCanvasFormats(true).%s reported true but creation failed: %s")
				:format(format, tostring(canvas)))
			assert(canvas:isReadable() and canvas:getMSAA() == 0)
			formatCanvases[#formatCanvases + 1] = canvas
			created = created + 1
		end
	end
	assert(created > 0 and readableFormats.rgba8)

	msaaCanvas = love.graphics.newCanvas(64, 48, {
		format = "rgba8",
		msaa = 4,
		readable = true,
	})
	assert(msaaCanvas:getFormat() == "rgba8" and msaaCanvas:getMSAA() == 4
		and msaaCanvas:isReadable())
	msaaCanvas:setFilter("nearest")
	for _, samples in ipairs({8, 16}) do
		local ok, message = pcall(love.graphics.newCanvas, 16, 16, {msaa = samples})
		assert(not ok and tostring(message):find("at most 4x MSAA", 1, true))
	end

	if readableFormats.hdr then
		hdrCanvas = love.graphics.newCanvas(64, 48, {format = "hdr"})
		assert(hdrCanvas:getFormat() == "rgba16f" and hdrCanvas:isReadable())
		hdrCanvas:setFilter("nearest")
	end

	writeOnlyCanvas = love.graphics.newCanvas(16, 16, {
		format = "rgba8",
		readable = false,
	})
	assert(not writeOnlyCanvas:isReadable())
	local drawOK, drawError = pcall(love.graphics.draw, writeOnlyCanvas)
	assert(not drawOK and tostring(drawError):find("non-readable", 1, true))

	local normalCanvas = love.graphics.newCanvas(64, 48)
	local switchOK, switchError = pcall(love.graphics.setCanvas, {normalCanvas, msaaCanvas})
	assert(not switchOK and tostring(switchError):find("MSAA", 1, true))
	assert(love.graphics.getCanvas() == nil)

	print("LOVE_CANVAS_FORMAT_CAPS", created,
		readableFormats.rgba8, readableFormats.rgba16f, supplied.rgba8)
end

function love.update()
	if callbackDone then
		love.event.quit()
	end
end

function love.draw()
	love.graphics.setCanvas(msaaCanvas)
	love.graphics.clear(0, 1, 0, 1)
	love.graphics.setColor(1, 1, 0, 1)
	love.graphics.rectangle("fill", 16, 12, 32, 24)

	if hdrCanvas then
		love.graphics.setCanvas(hdrCanvas)
		love.graphics.clear(0, 0, 1, 1)
	end

	-- A write-only Canvas remains a valid render target; only sampling/readback is forbidden.
	love.graphics.setCanvas(writeOnlyCanvas)
	love.graphics.clear(1, 0, 1, 1)

	love.graphics.setCanvas()
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(msaaCanvas, 16, 16)
	if hdrCanvas then
		love.graphics.draw(hdrCanvas, 112, 16)
	end

	if not requested then
		requested = true
		love.graphics.captureScreenshot(function(data)
			assert(data:getWidth() == 256 and data:getHeight() == 96)
			verifyPixel(data, 20, 20, {0, 1, 0, 1}, "MSAA resolved background")
			verifyPixel(data, 48, 40, {1, 1, 0, 1}, "MSAA resolved rectangle")
			if hdrCanvas then
				verifyPixel(data, 120, 20, {0, 0, 1, 1}, "HDR sampled surface")
			end
			callbackDone = true
			print("LOVE_CANVAS_FORMAT_PASS", msaaCanvas:getMSAA(),
				hdrCanvas and hdrCanvas:getFormat() or "unsupported",
				writeOnlyCanvas:isReadable())
		end)
	end
end
