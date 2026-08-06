local love = require("love")

love.filesystem.setIdentity("love-font-image-rasterizer")

local function assertPixel(data, x, y, red, green, blue, alpha)
	local width = data:getWidth()
	local offset = (y * width + x) * 4 + 1
	local r, g, b, a = data:getString():byte(offset, offset + 3)
	assert(r == red and g == green and b == blue and a == alpha,
		("unexpected pixel at %d,%d: %s,%s,%s,%s"):format(x, y, r, g, b, a))
end

function love.load()
	local atlas = love.image.newImageData(8, 2)
	for y = 0, 1 do
		for x = 0, 7 do atlas:setPixel(x, y, 1, 0, 0, 1) end
		for x = 1, 2 do atlas:setPixel(x, y, 1, 1, 1, 1) end
		for x = 4, 6 do atlas:setPixel(x, y, 0, 1, 0, 1) end
	end

	local rasterizer = love.font.newImageRasterizer(atlas, "A猫", 2, 1.5)
	assert(rasterizer:type() == "Rasterizer" and rasterizer:typeOf("Object"))
	assert(rasterizer:getHeight() == 2 and rasterizer:getGlyphCount() == 2)
	assert(rasterizer:hasGlyphs("A", 0x732b) and not rasterizer:hasGlyphs("Z"))

	local a = love.font.newGlyphData(rasterizer, "A")
	assert(a:type() == "GlyphData" and a:typeOf("Data") and a:typeOf("Object"))
	local width, height = a:getDimensions()
	assert(width == 2 and height == 2 and a:getAdvance() == 4)
	assert(a:getGlyph() == 65 and a:getGlyphString() == "A" and a:getFormat() == "rgba8")
	assert(a:getSize() == 16 and love.data.newByteData(a):getSize() == 16)
	local minX, minY, maxX, maxY = a:getBoundingBox()
	assert(minX == 0 and minY == 2 and maxX == 2 and maxY == -2)

	local cat = rasterizer:getGlyphData(0x732b)
	assert(cat:getWidth() == 3 and cat:getAdvance() == 5 and cat:getGlyphString() == "猫")
	assertPixel(cat, 0, 0, 0, 255, 0, 255)

	-- ImageRasterizer retains the source and reads its current pixels for each GlyphData.
	atlas:setPixel(1, 0, 1, 0, 0, 1)
	atlas = nil
	collectgarbage("collect")
	local changed = rasterizer:getGlyphData("A")
	assertPixel(changed, 0, 0, 0, 0, 0, 0)
	assertPixel(changed, 1, 0, 255, 255, 255, 255)

	local missing = rasterizer:getGlyphData("Z")
	assert(missing:getWidth() == 0 and missing:getHeight() == 2 and missing:getSize() == 0)

	local trueType = love.font.newTrueTypeRasterizer(18, "normal", 1)
	assert(trueType:getHeight() > 0 and trueType:getAscent() > 0 and trueType:getDescent() < 0)
	assert(trueType:hasGlyphs("A猫") and trueType:getGlyphCount() > 100)
	local trueGlyph = trueType:getGlyphData("猫")
	local tw, th = trueGlyph:getDimensions()
	assert(trueGlyph:getFormat() == "la8" and tw > 0 and th > 0)
	assert(trueGlyph:getSize() == tw * th * 2 and love.data.newByteData(trueGlyph):getSize() == trueGlyph:getSize())
	assert(love.font.newRasterizer(16, "none", 1):hasGlyphs("Love"))

	local bmAtlas = love.image.newImageData(4, 2)
	for y = 0, 1 do
		for x = 0, 1 do bmAtlas:setPixel(x, y, 1, 0, 0, 1) end
		for x = 2, 3 do bmAtlas:setPixel(x, y, 0, 1, 0, 1) end
	end
	assert(love.filesystem.createDirectory("bmfont"))
	bmAtlas:encode("png", "bmfont/page.png")
	local descriptor = table.concat({
		"info face=\"Fixture\" size=16 unicode=1",
		"common lineHeight=3 base=2 pages=1",
		"page id=0 file=\"page.png\"",
		"chars count=2",
		"char id=65 x=0 y=0 width=2 height=2 xoffset=1 yoffset=1 xadvance=3 page=0",
		"char id=29483 x=2 y=0 width=2 height=2 xoffset=0 yoffset=0 xadvance=3 page=0",
	}, "\n")
	local bmFile = love.filesystem.newFileData(descriptor, "bmfont/font.fnt")
	local bm = love.font.newBMFontRasterizer(bmFile)
	assert(bm:getGlyphCount() == 2 and bm:hasGlyphs("A猫"))
	local bmGlyph = bm:getGlyphData("A")
	assert(bmGlyph:getFormat() == "rgba8" and bmGlyph:getWidth() == 2 and bmGlyph:getAdvance() == 3)
	assert(love.font.newRasterizer(bmFile):getGlyphData("猫"):getSize() == 16)
	assert(love.filesystem.write("status.txt", "font=pass image=2 truetype=pass bmfont=pass retention=pass data=pass"))
end

local frames = 0
function love.update()
	frames = frames + 1
	if frames == 3 then assert(love.event.quit()) end
end
