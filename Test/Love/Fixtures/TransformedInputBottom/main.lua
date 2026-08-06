local presses = 0

local function near(actual, expected)
	return math.abs(actual - expected) <= 1.5
end

function love.mousepressed(x, y, button, _, clicks)
	presses = presses + 1
	assert(presses == 1 and near(x, 80) and near(y, 60))
	assert(button == 1 and clicks == 1 and love.mouse.isDown(1))
	print("LOVE_OVERLAP_BOTTOM_PRESS", presses, x, y, button, clicks)
end

function love.mousereleased(x, y, button)
	assert(presses == 1 and button == 1 and not love.mouse.isDown(1))
	print("LOVE_OVERLAP_BOTTOM_RELEASE", presses, x, y, button)
end

function love.wheelmoved(x, y)
	print("LOVE_OVERLAP_BOTTOM_WHEEL", x, y)
end

function love.keypressed(key, _, repeatPress)
	assert(key == "b" and not repeatPress)
	print("LOVE_FOCUS_BOTTOM_KEY", key)
end

function love.draw()
	love.graphics.clear(0.12, 0.035, 0.04, 1)
	love.graphics.setColor(1, 0.35, 0.2, 1)
	love.graphics.rectangle("fill", 0, 0, 240, 160)
end
