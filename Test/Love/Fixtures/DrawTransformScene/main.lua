local graphics = require("love.graphics")
local image = require("love.image")

local canvas
local texture
local leftHalf
local rendered = false
local verified = false

local function near(actual, expected)
	return math.abs(actual - expected) < 0.04
end

local function verifyPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s at %d,%d: expected %.1f %.1f %.1f %.1f, got %.3f %.3f %.3f %.3f")
			:format(label, x, y, expected[1], expected[2], expected[3], expected[4], r, g, b, a))
end

function love.load()
	local pixels = image.newImageData(4, 2)
	for y = 0, 1 do
		for x = 0, 1 do
			pixels:setPixel(x, y, 1, 0, 0, 1)
		end
		for x = 2, 3 do
			pixels:setPixel(x, y, 0, 1, 0, 1)
		end
	end
	texture = graphics.newImage(pixels)
	texture:setFilter("nearest", "nearest")
	leftHalf = graphics.newQuad(0, 0, 2, 2, texture)
	canvas = graphics.newCanvas(40, 20)
	canvas:setFilter("nearest", "nearest")
end

function love.draw()
	if not rendered then
		graphics.setCanvas(canvas)
		graphics.clear(0, 0, 0, 1)
		graphics.setColor(1, 1, 1, 1)
		graphics.origin()

		-- draw(texture, transform)
		graphics.draw(texture, love.math.newTransform(4, 3))

		-- draw(texture, quad, transform), including scale in the Transform.
		graphics.draw(texture, leftHalf, love.math.newTransform(12, 3, 0, 2, 2))

		-- The supplied Transform is composed after the active graphics transform.
		graphics.push()
		graphics.translate(2, 1)
		graphics.draw(texture, love.math.newTransform(24, 3))
		graphics.pop()

		-- Origin offsets embedded in a Transform must not be applied twice.
		graphics.draw(texture, love.math.newTransform(8, 12, 0, 1, 1, 2, 0))

		graphics.setCanvas()
		rendered = true
	end

	graphics.clear(0.05, 0.05, 0.08, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.draw(canvas, 0, 0)
end

function love.update()
	if rendered and not verified then
		local data = canvas:newImageData()
		verifyPixel(data, 4, 3, {1, 0, 0, 1}, "full texture red half")
		verifyPixel(data, 6, 3, {0, 1, 0, 1}, "full texture green half")
		verifyPixel(data, 12, 3, {1, 0, 0, 1}, "quad transform origin")
		verifyPixel(data, 15, 6, {1, 0, 0, 1}, "quad transform scale")
		verifyPixel(data, 16, 3, {0, 0, 0, 1}, "quad excludes right texture half")
		verifyPixel(data, 26, 4, {1, 0, 0, 1}, "active transform composition red half")
		verifyPixel(data, 28, 4, {0, 1, 0, 1}, "active transform composition green half")
		verifyPixel(data, 6, 12, {1, 0, 0, 1}, "Transform origin red half")
		verifyPixel(data, 8, 12, {0, 1, 0, 1}, "Transform origin green half")
		verified = true
		love.event.quit()
	end
end
