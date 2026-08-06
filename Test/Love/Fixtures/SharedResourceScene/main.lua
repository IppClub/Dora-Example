assert(OWNER_ROLE == "first" or OWNER_ROLE == "second")

local graphics = require("love.graphics")
local imageModule = require("love.image")
local image
local imageData
local font
local frames = 0

function love.load()
	image = graphics.newImage("pig.png")
	imageData = imageModule.newImageData("pig.png")
	font = graphics.newFont(18)
	graphics.setFont(font)
	assert(image:getWidth() == 256 and image:getHeight() == 256)
	assert(imageData:getWidth() == 256 and imageData:getHeight() == 256)
	assert(imageData:getFormat() == "rgba8" and imageData:getSize() == 256 * 256 * 4)
	local red, green, blue, alpha = imageData:getPixel(0, 0)
	for _, component in ipairs({red, green, blue, alpha}) do
		assert(component >= 0 and component <= 1)
	end
	local clone = imageData:clone()
	clone:setPixel(0, 0, red < 0.5 and 1 or 0, green, blue, alpha)
	local cloneRed = clone:getPixel(0, 0)
	assert(cloneRed ~= red and imageData:getPixel(0, 0) == red)
	local raw = imageModule.newImageData(1, 1, "rgba8", string.char(255, 128, 0, 64))
	local rawRed, rawGreen, rawBlue, rawAlpha = raw:getPixel(0, 0)
	assert(rawRed == 1 and math.abs(rawGreen - 128 / 255) < 0.0001 and rawBlue == 0 and math.abs(rawAlpha - 64 / 255) < 0.0001)
	assert(font:getWidth("shared cache") > 0)
	print("LOVE_SHARED_RESOURCE_LOADED", OWNER_ROLE, image:getDimensions(), font:getHeight())
	print("LOVE_IMAGE_DATA_RGBA8_PASS", OWNER_ROLE, imageData:getDimensions(), imageData:getSize(), red, green, blue, alpha)
end

function love.update()
	frames = frames + 1
	if OWNER_ROLE == "first" and frames == 12 then
		assert(love.event.quit())
	elseif OWNER_ROLE == "second" and frames == 45 then
		assert(image:getWidth() == 256)
		assert(font:getWidth("survived") > 0)
		print("LOVE_SHARED_RESOURCE_SECOND_SURVIVED", image:getWidth(), font:getHeight())
	elseif OWNER_ROLE == "second" and frames == 70 then
		assert(love.event.quit())
	end
end

function love.draw()
	graphics.clear(OWNER_ROLE == "first" and 0.12 or 0.03, 0.04, OWNER_ROLE == "second" and 0.12 or 0.03, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.draw(image, 150, 86, 0, 0.45, 0.45, 128, 128)
	graphics.setFont(font)
	graphics.print(OWNER_ROLE .. " shared image/font", 28, 142)
end

function love.quit()
	print("LOVE_SHARED_RESOURCE_QUIT", OWNER_ROLE, image:getWidth(), font:getHeight())
	return false
end
