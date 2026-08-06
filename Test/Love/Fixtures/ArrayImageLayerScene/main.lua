local graphics = require("love.graphics")
local image = require("love.image")

local canvas
local arrayImage
local twoDImage
local quad
local shader
local rendered = false
local verified = false

local function assertPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	local function near(left, right) return math.abs(left - right) < 0.04 end
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s at %d,%d: %.3f %.3f %.3f %.3f"):format(label, x, y, r, g, b, a))
end

function love.load()
	graphics.setDefaultFilter("nearest")
	local red = image.newImageData(4, 4)
	local green = image.newImageData(4, 4)
	red:mapPixel(function() return 1, 0, 0, 1 end)
	green:mapPixel(function() return 0, 1, 0, 1 end)
	local blue = image.newImageData(2, 2)
	blue:mapPixel(function() return 0, 0, 1, 1 end)
	twoDImage = graphics.newImage(red)
	twoDImage:replacePixels(blue, 99, 1, 1, 1)
	arrayImage = graphics.newArrayImage({red, green}, {mipmaps = false})
	arrayImage:replacePixels(blue, 2, 1, 1, 1)
	assert(arrayImage:getTextureType() == "array" and arrayImage:getLayerCount() == 2)
	quad = graphics.newQuad(1, 1, 2, 2, 4, 4)
	quad:setLayer(2)
	assert(not pcall(graphics.drawLayer, arrayImage, 0))
	assert(not pcall(graphics.drawLayer, arrayImage, 3))
	assert(not pcall(graphics.drawLayer, graphics.newImage(red), 1))
	shader = graphics.newShader([[
		extern ArrayImage MainTex;
		void effect() {
			love_PixelColor = Texel(MainTex, VaryingTexCoord.xyz)
				* VaryingColor * vec4(0.5, 1.0, 1.0, 1.0);
		}
	]])
	assert(shader:hasUniform("MainTex"))
	shader:send("MainTex", arrayImage)
	assert(not pcall(shader.send, shader, "MainTex", graphics.newImage(red)))
	canvas = graphics.newCanvas(34, 12)
end

function love.draw()
	if not rendered then
		graphics.setCanvas(canvas)
		graphics.clear(0, 0, 0, 1)
		graphics.setColor(1, 1, 1, 1)
		graphics.draw(arrayImage, 1, 1)
		graphics.drawLayer(arrayImage, 2, 7, 1)
		graphics.draw(arrayImage, quad, 1, 7)
		graphics.drawLayer(arrayImage, 1, quad, 7, 7)
		graphics.setShader(shader)
		graphics.drawLayer(arrayImage, 1, 15, 1)
		graphics.drawLayer(arrayImage, 2, 21, 1)
		graphics.draw(arrayImage, quad, 15, 7)
		assert(not pcall(graphics.draw, graphics.newImage(image.newImageData(1, 1)), 0, 0))
		assert(not pcall(graphics.rectangle, "fill", 0, 0, 1, 1))
		assert(not pcall(graphics.print, "2D font atlas", 0, 0))
		graphics.setShader()
		graphics.draw(twoDImage, 29, 1)
		graphics.setCanvas()
		rendered = true
	end
	graphics.clear(0.05, 0.05, 0.08, 1)
	graphics.draw(canvas)
end

function love.update()
	if rendered and not verified then
		local data = canvas:newImageData()
		assertPixel(data, 2, 2, {1, 0, 0, 1}, "explicit layer 1")
		assertPixel(data, 7, 1, {0, 1, 0, 1}, "layer 2 unchanged border")
		assertPixel(data, 8, 2, {0, 0, 1, 1}, "explicit layer 2 replacement")
		assertPixel(data, 1, 7, {0, 0, 1, 1}, "Quad-selected replaced layer 2")
		assertPixel(data, 7, 7, {1, 0, 0, 1}, "explicit layer overrides Quad layer")
		assertPixel(data, 4, 8, {0, 0, 0, 1}, "Quad crop boundary")
		assertPixel(data, 16, 2, {0.5, 0, 0, 1}, "custom Shader array layer 1")
		assertPixel(data, 22, 2, {0, 0, 1, 1}, "custom Shader replaced array layer 2")
		assertPixel(data, 15, 7, {0, 0, 1, 1}, "custom Shader Quad-selected replaced layer 2")
		assertPixel(data, 29, 1, {1, 0, 0, 1}, "2D replacement unchanged border")
		assertPixel(data, 30, 2, {0, 0, 1, 1}, "2D replacement region")
		verified = true
		love.event.quit()
	end
end
