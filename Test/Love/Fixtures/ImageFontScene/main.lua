local graphics = require("love.graphics")
local image = require("love.image")
local fontModule = require("love.font")

local canvas
local imageFont
local vertexIDShader
local rendered = false
local verified = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.04
end

local function assertPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s at %d,%d: %.3f %.3f %.3f %.3f"):format(label, x, y, r, g, b, a))
end

function love.load()
	graphics.setDefaultFilter("nearest")
	local atlas = image.newImageData(8, 4)
	for y = 0, 3 do
		for x = 0, 7 do atlas:setPixel(x, y, 1, 0, 1, 1) end
		for x = 1, 2 do atlas:setPixel(x, y, 1, 0, 0, 1) end
		for x = 4, 6 do atlas:setPixel(x, y, 0, 1, 0, 1) end
	end
	imageFont = graphics.newImageFont(atlas, "A猫", 1, 1)
	assert(imageFont:type() == "Font" and imageFont:typeOf("Object"))
	assert(imageFont:getWidth("A猫") == 7 and imageFont:getHeight() == 4)
	assert(imageFont:getBaseline() == 0 and imageFont:getAscent() == 0
		and imageFont:getDescent() == 0 and imageFont:getKerning("A", "猫") == 0)
	assert(imageFont:hasGlyphs("A猫") and not imageFont:hasGlyphs("B"))
	local fallbackAtlas = image.newImageData(3, 4)
	for y = 0, 3 do
		for x = 0, 2 do fallbackAtlas:setPixel(x, y, 1, 0, 1, 1) end
		for x = 1, 2 do fallbackAtlas:setPixel(x, y, 0, 0, 1, 1) end
	end
	local imageFallback = graphics.newImageFont(fallbackAtlas, "B", 1, 1)
	imageFont:setFallbacks(imageFallback)
	assert(imageFont:hasGlyphs("A猫B") and imageFont:getWidth("A猫B") == 10)

	local rasterizer = fontModule.newImageRasterizer(atlas, "A猫", 1, 2)
	local dpiFont = graphics.newImageFont(rasterizer)
	assert(dpiFont:getWidth("A猫") == 4 and dpiFont:getHeight() == 2)
	assert(pcall(imageFont.setFallbacks, imageFont, dpiFont))
	imageFont:setFallbacks(imageFallback)
	assert(not pcall(imageFont.setFallbacks, imageFont, graphics.newFont(12)))

	vertexIDShader = graphics.newShader([[
	#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += float(love_VertexID) * 0.0;
			return transform * vertex;
		}
	]])
	canvas = graphics.newCanvas(16, 12)
end

function love.draw()
	if not rendered then
		graphics.setCanvas(canvas)
		graphics.clear(0, 0, 0, 1)
		graphics.setFont(imageFont)
		graphics.setColor(1, 1, 1, 1)
		graphics.print("A猫B", 1, 1)
		graphics.setShader(vertexIDShader)
		graphics.print("A猫B", 1, 7)
		graphics.setShader()
		graphics.setCanvas()
		rendered = true
	end
	graphics.clear(0.05, 0.05, 0.08, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.draw(canvas)
end

function love.update()
	if rendered and not verified then
		local data = canvas:newImageData()
		assertPixel(data, 1, 1, {1, 0, 0, 1}, "direct A")
		assertPixel(data, 2, 4, {1, 0, 0, 1}, "direct A lower edge")
		assertPixel(data, 3, 2, {0, 0, 0, 1}, "transparent separator spacing")
		assertPixel(data, 4, 1, {0, 1, 0, 1}, "direct cat")
		assertPixel(data, 6, 4, {0, 1, 0, 1}, "direct cat lower edge")
		assertPixel(data, 8, 1, {0, 0, 1, 1}, "fallback B")
		assertPixel(data, 9, 4, {0, 0, 1, 1}, "fallback B lower edge")
		assertPixel(data, 1, 7, {1, 0, 0, 1}, "VertexID A")
		assertPixel(data, 4, 7, {0, 1, 0, 1}, "VertexID cat")
		assertPixel(data, 8, 7, {0, 0, 1, 1}, "VertexID fallback B")
		assertPixel(data, 3, 8, {0, 0, 0, 1}, "VertexID separator spacing")
		verified = true
		love.event.quit()
	end
end
