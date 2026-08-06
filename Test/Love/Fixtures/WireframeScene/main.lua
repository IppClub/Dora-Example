local graphics = require("love.graphics")
local image = require("love.image")

local canvases = {}
local rendered = false
local verified = false

local function beginSample(index, wireframe)
	graphics.setCanvas(canvases[index])
	graphics.clear(0, 0, 0, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.setWireframe(wireframe)
end

local function bright(data, x, y)
	local r, g, b = data:getPixel(x, y)
	return math.max(r, g, b)
end

local function nearby(data, x, y, radius)
	local value = 0
	for py = math.max(0, y - radius), math.min(63, y + radius) do
		for px = math.max(0, x - radius), math.min(63, x + radius) do
			value = math.max(value, bright(data, px, py))
		end
	end
	return value
end

local function hasGreenEdge(data)
	for y = 0, 63 do
		for x = 0, 63 do
			local r, g, b = data:getPixel(x, y)
			if g > 0.8 and r < 0.4 and b < 0.5 then return true end
		end
	end
	return false
end

function love.load()
	assert(not graphics.isWireframe())
	graphics.setWireframe(true)
	graphics.push("all")
	graphics.setWireframe(false)
	graphics.pop()
	assert(graphics.isWireframe())
	assert(not pcall(graphics.setWireframe, 1))
	graphics.reset()
	assert(not graphics.isWireframe())
	for index = 1, 6 do canvases[index] = graphics.newCanvas(64, 64) end
end

function love.draw()
	if not rendered then
		beginSample(1, false)
		graphics.rectangle("fill", 8, 8, 48, 48)

		beginSample(2, true)
		graphics.rectangle("fill", 8, 8, 48, 48)

		beginSample(3, true)
		local mesh = graphics.newMesh({
			{8, 54, 0, 0, 1, 1, 1, 1},
			{32, 8, 0, 0, 1, 1, 1, 1},
			{56, 54, 0, 0, 1, 1, 1, 1},
		}, "triangles", "static")
		graphics.draw(mesh)

		beginSample(4, true)
		graphics.setPointSize(5)
		graphics.points(32, 32)

		local pixels = image.newImageData(8, 8)
		pixels:mapPixel(function() return 1, 1, 1, 1 end)
		local texture = graphics.newImage(pixels)
		beginSample(5, true)
		graphics.draw(texture, 8, 8, 0, 6, 6)

		beginSample(6, true)
		local shader = graphics.newShader([[
			#pragma language glsl3
			vec4 effect(vec4 color, Image texture, vec2 uv, vec2 pixel) {
				return vec4(0.2, 1.0, 0.3, 1.0);
			}
		]])
		graphics.setShader(shader)
		graphics.rectangle("fill", 8, 8, 48, 48)
		graphics.setShader()
		graphics.setWireframe(false)
		graphics.setCanvas()
		rendered = true
	end

	graphics.clear(0.03, 0.03, 0.05, 1)
	for index, canvas in ipairs(canvases) do
		graphics.setColor(1, 1, 1, 1)
		graphics.draw(canvas, (index - 1) * 64, 16)
	end
end

function love.update()
	if rendered and not verified then
		local filled = canvases[1]:newImageData()
		local rectangle = canvases[2]:newImageData()
		local mesh = canvases[3]:newImageData()
		local point = canvases[4]:newImageData()
		local texture = canvases[5]:newImageData()
		local shader = canvases[6]:newImageData()
		assert(bright(filled, 20, 32) > 0.9, "filled control lost its interior")
		assert(bright(rectangle, 20, 32) < 0.1, "wireframe rectangle retained a filled interior")
		assert(nearby(rectangle, 8, 30, 2) > 0.5, "wireframe rectangle edge is missing")
		assert(nearby(rectangle, 32, 32, 2) > 0.5, "wireframe rectangle triangle seam is missing")
		assert(bright(mesh, 32, 30) < 0.1, "wireframe Mesh retained a filled interior")
		assert(nearby(mesh, 32, 8, 2) > 0.5, "wireframe Mesh edge is missing")
		assert(bright(point, 32, 32) > 0.9 and bright(point, 30, 30) > 0.5,
			"wireframe incorrectly changed point rasterization")
		assert(bright(texture, 20, 32) < 0.1, "wireframe Image retained a filled interior")
		assert(nearby(texture, 8, 30, 2) > 0.5, "wireframe Image edge is missing")
		assert(hasGreenEdge(shader), "wireframe Shader edge output is incorrect")
		assert(bright(shader, 20, 32) < 0.1, "wireframe Shader primitive retained a filled interior")
		verified = true
		love.event.quit()
	end
end
