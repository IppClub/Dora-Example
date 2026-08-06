local pressed = false
local mouseX, mouseY = -100, -100

function love.load()
	assert(input_scene_owner == "second")
end

function love.keypressed(key)
	assert(key == "a")
	pressed = true
	print("LOVE_INPUT_SECOND_KEY", key)
end


function love.mousepressed(x, y, button)
	assert(button == 1 and love.mouse.isDown(1))
	mouseX, mouseY = x, y
	print("LOVE_INPUT_SECOND_PRESS", x, y)
end

function love.mousemoved(x, y)
	mouseX, mouseY = x, y
end

function love.wheelmoved(x, y)
	print("LOVE_INPUT_SECOND_WHEEL", x, y)
end

function love.draw()
	if pressed then
		love.graphics.clear(0.45, 0.26, 0.04, 1)
		love.graphics.setColor(1, 0.85, 0.2, 1)
	else
		love.graphics.clear(0.2, 0.03, 0.08, 1)
		love.graphics.setColor(1, 0.25, 0.45, 1)
	end
	love.graphics.rectangle("line", 18, 18, 324, 184)
	love.graphics.line(342, 18, 18, 202)
	love.graphics.circle("fill", mouseX, mouseY, 7)
end
