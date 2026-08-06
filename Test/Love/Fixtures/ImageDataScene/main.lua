local image = require("love.image")
local graphics = require("love.graphics")
local filesystem = require("love.filesystem")

local drawable
local surface
local frames = 0
local gpuChecked = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.005
end

function love.load()
	local pixels = image.newImageData(4, 4)
	pixels:mapPixel(function(x, y)
		return x / 3, y / 3, 0.25, 1
	end)

	local patch = image.newImageData(2, 2)
	patch:mapPixel(function(x, y)
		return 1, x, y, 0.5
	end)
	pixels:paste(patch, 1, 1)

	local encoded = pixels:encode("png", "roundtrip.png")
	assert(encoded:getFilename() == "roundtrip.png")
	assert(encoded:getExtension() == "png")
	assert(encoded:getSize() > pixels:getSize())

	local fromMemory = image.newImageData(encoded)
	local fromContent = image.newImageData("roundtrip.png")
	assert(fromMemory:getWidth() == 4 and fromMemory:getHeight() == 4)
	assert(fromContent:getWidth() == 4 and fromContent:getHeight() == 4)
	local red, green, blue, alpha = fromContent:getPixel(2, 2)
	assert(near(red, 1) and near(green, 1) and near(blue, 1) and near(alpha, 128 / 255))
	red, green, blue, alpha = fromMemory:getPixel(3, 0)
	assert(near(red, 1) and near(green, 0) and near(blue, 64 / 255) and near(alpha, 1))

	local encodedTga = pixels:encode("tga", "roundtrip.tga")
	assert(encodedTga:getFilename() == "roundtrip.tga")
	assert(encodedTga:getExtension() == "tga")
	assert(encodedTga:getSize() == 18 + pixels:getSize())
	local tga = encodedTga:getString()
	assert(string.byte(tga, 3) == 2)
	assert(string.byte(tga, 13) == 4 and string.byte(tga, 14) == 0)
	assert(string.byte(tga, 15) == 4 and string.byte(tga, 16) == 0)
	assert(string.byte(tga, 17) == 32 and string.byte(tga, 18) == 0x20)
	assert(string.byte(tga, 19) == 64 and string.byte(tga, 20) == 0)
	assert(string.byte(tga, 21) == 0 and string.byte(tga, 22) == 255)
	local tgaFromMemory = image.newImageData(encodedTga)
	local tgaFromContent = image.newImageData("roundtrip.tga")
	assert(tgaFromMemory:getWidth() == 4 and tgaFromMemory:getHeight() == 4)
	assert(tgaFromContent:getWidth() == 4 and tgaFromContent:getHeight() == 4)
	red, green, blue, alpha = tgaFromContent:getPixel(2, 2)
	assert(near(red, 1) and near(green, 1) and near(blue, 1) and near(alpha, 128 / 255))
	red, green, blue, alpha = tgaFromMemory:getPixel(3, 0)
	assert(near(red, 1) and near(green, 0) and near(blue, 64 / 255) and near(alpha, 1))

	drawable = graphics.newImage("roundtrip.tga")
	drawable:setFilter("nearest")
	surface = graphics.newCanvas(64, 64)
	assert(filesystem.remove("roundtrip.png"))
	assert(filesystem.remove("roundtrip.tga"))
	print("LOVE_IMAGEDATA_CONTENT_ROUNDTRIP_PASS", encoded:getSize(), encodedTga:getSize(), fromContent:getFormat())
end

function love.draw()
	graphics.setCanvas(surface)
	graphics.clear(0, 0, 0, 0)
	graphics.setColor(1, 1, 1, 1)
	graphics.draw(drawable, 0, 0, 0, 16, 16)
	graphics.setCanvas()
	graphics.clear(0.08, 0.08, 0.1, 1)
	graphics.draw(surface, 16, 16)
end

function love.update()
	frames = frames + 1
	if frames == 2 then
		local rendered = surface:newImageData()
		local red, green, blue, alpha = rendered:getPixel(8, 8)
		assert(near(red, 0) and near(green, 0) and near(blue, 64 / 255) and near(alpha, 1))
		red, green, blue, alpha = rendered:getPixel(56, 8)
		assert(near(red, 1) and near(green, 0) and near(blue, 64 / 255) and near(alpha, 1))
		gpuChecked = true
	end
	if frames == 4 then
		assert(gpuChecked)
		love.event.quit()
	end
end
