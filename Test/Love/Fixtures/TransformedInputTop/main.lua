local presses = 0

local function near(actual, expected)
	return math.abs(actual - expected) <= 1.5
end

function love.mousemoved(x, y, dx, dy)
	if near(x, 40) and near(y, 30) then
		print("LOVE_TRANSFORM_TOP_MOVE_A", x, y, dx, dy)
	elseif near(x, 80) and near(y, 60) then
		assert(near(dx, 40) and near(dy, 30))
		print("LOVE_TRANSFORM_TOP_MOVE_B", x, y, dx, dy)
	end
end

function love.mousepressed(x, y, button, _, clicks)
	presses = presses + 1
	local expectedX = presses == 1 and 40 or 80
	local expectedY = presses == 1 and 30 or 60
	assert(presses <= 2 and near(x, expectedX) and near(y, expectedY))
	assert(button == 1 and clicks == 1 and love.mouse.isDown(1))
	print("LOVE_TRANSFORM_TOP_PRESS", presses, x, y, button, clicks)
end

function love.mousereleased(x, y, button)
	assert(button == 1 and not love.mouse.isDown(1))
	print("LOVE_TRANSFORM_TOP_RELEASE", presses, x, y, button)
end

function love.wheelmoved(x, y)
	print("LOVE_TRANSFORM_TOP_WHEEL", x, y)
end

function love.keypressed(key, _, repeatPress)
	assert(key == "a" and not repeatPress)
	print("LOVE_FOCUS_TOP_KEY", key)
end

function love.draw()
	love.graphics.clear(0.04, 0.08, 0.18, 1)
	love.graphics.setColor(0.2, 0.85, 1, 0.82)
	love.graphics.rectangle("fill", 0, 0, 240, 160)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", 1, 1, 238, 158)
end
