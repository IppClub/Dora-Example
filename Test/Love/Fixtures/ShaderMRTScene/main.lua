local source
local redTarget
local greenTarget
local shader
local frame = 0

local function expect(image, r, g, b, label)
	local ar, ag, ab, aa = image:getPixel(16, 16)
	assert(math.abs(ar - r) < 0.02 and math.abs(ag - g) < 0.02
		and math.abs(ab - b) < 0.02 and aa > 0.98,
		label .. ": " .. ar .. "," .. ag .. "," .. ab .. "," .. aa)
end

function love.load()
	source = love.graphics.newCanvas(32, 32)
	redTarget = love.graphics.newCanvas(32, 32)
	greenTarget = love.graphics.newCanvas(32, 32)
	shader = love.graphics.newShader("mrt.frag")
	assert(shader:getWarnings() == "")

	local valid, message = love.graphics.validateShader(false,
		"void effect() { love_PixelColor = vec4(1.0); }")
	assert(valid and message == nil, tostring(message))
	valid, message = love.graphics.validateShader(false,
		"void effect() { int outputIndex = 0; love_Canvases[outputIndex] = vec4(1.0); }")
	assert(not valid and message:find("constant output index", 1, true))
	valid, message = love.graphics.validateShader(false,
		"void effect() { love_Canvases[7] = vec4(1.0); }")
	assert(not valid and message:find("framebuffer attachment limit", 1, true))
end

function love.draw()
	love.graphics.setCanvas(source)
	love.graphics.clear(1, 1, 1, 1)

	love.graphics.setCanvas()
	love.graphics.setShader(shader)
	local ok, message = pcall(love.graphics.draw, source, 0, 0)
	assert(not ok and message:find("writes 2 color outputs", 1, true))

	love.graphics.setCanvas(redTarget)
	ok, message = pcall(love.graphics.draw, source, 0, 0)
	assert(not ok and message:find("provides only 1", 1, true))

	love.graphics.setCanvas({redTarget, greenTarget})
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.draw(source, 0, 0)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(redTarget, 4, 4)
	love.graphics.draw(greenTarget, 44, 4)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local red = redTarget:newImageData()
	local green = greenTarget:newImageData()
	expect(red, 1, 0, 0, "love_Canvases[0]")
	expect(green, 0, 1, 0, "love_Canvases[1]")
	print("LOVE_SHADER_MRT_PASS", red:getDimensions(), green:getDimensions())
	love.event.quit()
end
