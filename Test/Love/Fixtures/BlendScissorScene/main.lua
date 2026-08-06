local graphics = require("love.graphics")

function love.load()
	local mode, alphaMode = graphics.getBlendMode()
	assert(mode == "alpha" and alphaMode == "alphamultiply")
	print("LOVE_BLEND_SCISSOR_PASS")
end

function love.draw()
	graphics.clear(0.025, 0.035, 0.065, 1)

	-- Alpha overlap: the intersection must mix red and blue.
	graphics.setBlendMode("alpha", "alphamultiply")
	graphics.setColor(0.1, 0.35, 1.0, 1.0)
	graphics.rectangle("fill", 22, 28, 112, 72)
	graphics.setColor(1.0, 0.12, 0.18, 0.58)
	graphics.rectangle("fill", 70, 58, 112, 72)

	-- Additive overlap: the common area must become bright yellow.
	graphics.setBlendMode("add", "alphamultiply")
	graphics.setColor(1.0, 0.08, 0.02, 0.8)
	graphics.circle("fill", 72, 175, 34)
	graphics.setColor(0.05, 0.95, 0.12, 0.8)
	graphics.circle("fill", 105, 175, 34)

	-- Scissor is defined in logical pixels and is unaffected by transform.
	graphics.setBlendMode("alpha", "alphamultiply")
	graphics.setScissor(205, 30, 120, 72)
	local x, y, width, height = graphics.getScissor()
	assert(x == 205 and y == 30 and width == 120 and height == 72)
	graphics.push()
	graphics.translate(250, 65)
	graphics.rotate(0.35)
	graphics.setColor(0.15, 1.0, 0.45, 1.0)
	graphics.rectangle("fill", -90, -55, 180, 110)
	graphics.pop()
	graphics.setScissor()
	assert(graphics.getScissor() == nil)

	graphics.setColor(1.0, 0.85, 0.12, 1.0)
	graphics.setLineWidth(3)
	graphics.rectangle("line", 205, 30, 120, 72)

	-- Multiply is valid only with premultiplied alpha, matching Love 11.5.
	graphics.setBlendMode("multiply", "premultiplied")
	graphics.setColor(0.65, 0.75, 1.0, 1.0)
	graphics.rectangle("fill", 215, 145, 105, 52)
	graphics.setBlendMode("alpha", "alphamultiply")
	graphics.setColor(1.0, 1.0, 1.0, 1.0)
	graphics.rectangle("line", 215, 145, 105, 52)
end
