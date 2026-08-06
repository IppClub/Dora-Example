local graphics = require("love.graphics")
local font
local frames = 0

function love.load()
	font = graphics.newFont(24)
	graphics.setFont(font)
	assert(graphics.getFont() == font)

	local width = font:getWidth("Love2D Font")
	local height = font:getHeight()
	local baseline = font:getBaseline()
	local ascent = font:getAscent()
	local descent = font:getDescent()
	local wrappedWidth, lines = font:getWrap("Dora Content backed fonts wrap cleanly", 180)
	assert(width > 0 and height > 0)
	assert(baseline >= 0 and baseline <= height)
	assert(ascent == baseline and descent <= 0)
	assert(font:hasGlyphs("Love2D", "中", 65))
	assert(type(font:getKerning("A", "V")) == "number")
	font:setLineHeight(1.2)
	assert(math.abs(font:getLineHeight() - 1.2) < 0.001)
	assert(wrappedWidth > 0 and #lines >= 2)
	print("LOVE_FONT_METRICS_PASS", width, height, baseline, ascent, descent,
		font:getLineHeight(), wrappedWidth, #lines)
end

function love.update()
	frames = frames + 1
	if frames == 30 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_FONT_VALID_RESOURCE_QUIT_PASS")
	return false
end

function love.draw()
	graphics.clear(0.025, 0.035, 0.065, 1)
	graphics.setFont(font)

	graphics.setColor(0.35, 0.85, 1.0, 1.0)
	graphics.print("Love2D Font / Dora Label", 24, 20)

	local baselineY = 84
	graphics.setColor(1.0, 0.95, 0.76, 1.0)
	graphics.print("Baseline  Aa 中", 24, baselineY - font:getBaseline())
	graphics.setColor(1.0, 0.35, 0.32, 1.0)
	graphics.setLineWidth(2)
	graphics.line(20, baselineY, 238, baselineY)

	graphics.setColor(0.8, 0.9, 1.0, 1.0)
	graphics.printf("left aligned wrapped text", 24, 108, 138, "left")
	graphics.setColor(0.75, 1.0, 0.72, 1.0)
	graphics.printf("center aligned wrapped text", 190, 108, 138, "center")
	graphics.setColor(1.0, 0.72, 0.88, 1.0)
	graphics.printf("right aligned wrapped text", 356, 108, 138, "right")

	graphics.setScissor(24, 218, 230, 46)
	graphics.setColor(1.0, 0.75, 0.2, 1.0)
	graphics.print("Scissored text stays inside this box", 30, 226)
	graphics.setScissor()
	graphics.setColor(1.0, 1.0, 1.0, 0.65)
	graphics.rectangle("line", 24, 218, 230, 46)

	graphics.setColor(0.7, 0.55, 1.0, 1.0)
	graphics.print("rotated", 405, 242, -0.28, 1.15, 1.15, 36, 12)
end
