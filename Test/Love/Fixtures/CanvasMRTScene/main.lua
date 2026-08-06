local first
local second
local mismatched
local ready = false

function love.load()
	first = love.graphics.newCanvas(64, 64)
	second = love.graphics.newCanvas(64, 64)
	mismatched = love.graphics.newCanvas(32, 64)
	first:setFilter("nearest")
	second:setFilter("nearest")
end

function love.draw()
	love.graphics.setCanvas(first)
	love.graphics.clear(1, 0, 0, 1)
	love.graphics.setCanvas(second)
	love.graphics.clear(0, 0, 1, 1)

	-- This must bind one real framebuffer with two color attachments. A view clear
	-- applies to both; the default Dora sprite shader then writes only color 0.
	love.graphics.setCanvas({first, second})
	local activeFirst, activeSecond = love.graphics.getCanvas()
	assert(activeFirst == first and activeSecond == second)
	love.graphics.clear(0, 1, 0, 1)
	love.graphics.setColor(1, 1, 0, 1)
	love.graphics.rectangle("fill", 8, 8, 24, 24)

	local ok, message = pcall(love.graphics.setCanvas, {first, mismatched})
	assert(not ok and message:find("identical dimensions", 1, true))
	activeFirst, activeSecond = love.graphics.getCanvas()
	assert(activeFirst == first and activeSecond == second)

	love.graphics.setCanvas()
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(first, 40, 50)
	love.graphics.draw(second, 140, 50)

	if not ready then
		ready = true
		print("LOVE_CANVAS_MRT_SCENE_READY", first:getDimensions(), second:getDimensions())
	end
end
