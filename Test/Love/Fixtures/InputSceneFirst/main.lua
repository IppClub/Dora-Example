local pressed = false
local mouseX, mouseY = -100, -100

function love.load()
	assert(input_scene_owner == "first")
end

function love.keypressed(key, scancode, isrepeat)
	assert(key == "a" and scancode == "a" and isrepeat == false)
	assert(love.keyboard.isDown("a"))
	pressed = true
	print("LOVE_INPUT_FIRST_KEY", key)
end

function love.keyreleased(key)
	assert(key == "a")
	pressed = false
end

function love.mousepressed(x, y, button)
	assert(button == 1 and love.mouse.isDown(1))
	mouseX, mouseY = x, y
	print("LOVE_INPUT_FIRST_PRESS", x, y)
end

function love.mousemoved(x, y)
	mouseX, mouseY = x, y
end

function love.wheelmoved(x, y)
	print("LOVE_INPUT_FIRST_WHEEL", x, y)
end

function love.draw()
	if pressed then
		love.graphics.clear(0.05, 0.4, 0.16, 1)
		love.graphics.setColor(0.2, 1, 0.45, 1)
	else
		love.graphics.clear(0.04, 0.08, 0.18, 1)
		love.graphics.setColor(0.2, 0.55, 1, 1)
	end
	love.graphics.rectangle("line", 18, 18, 324, 184)
	love.graphics.line(18, 18, 342, 202)
	love.graphics.circle("fill", mouseX, mouseY, 7)
end
