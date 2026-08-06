local pressed = {}
local released = {}
local moveCount = 0
local wheelSeen = false
local doubleClickSeen = false
local mouseX, mouseY = 240, 150

local function complete()
	for button = 1, 3 do
		if not pressed[button] or not released[button] then
			return false
		end
	end
	return moveCount > 0 and wheelSeen and doubleClickSeen
end

function love.load()
	assert(physical_mouse_scene == true)
	print("LOVE_PHYSICAL_MOUSE_READY")
end

function love.mousepressed(x, y, button, isTouch, presses)
	assert(button >= 1 and button <= 3)
	assert(isTouch == false)
	assert(presses >= 1)
	assert(love.mouse.isDown(button))
	pressed[button] = true
	if button == 1 and presses >= 2 then doubleClickSeen = true end
	mouseX, mouseY = x, y
	print("LOVE_PHYSICAL_MOUSE_PRESS", button, math.floor(x), math.floor(y), presses)
end

function love.mousereleased(x, y, button, isTouch, presses)
	assert(button >= 1 and button <= 3)
	assert(isTouch == false)
	assert(presses >= 1)
	assert(not love.mouse.isDown(button))
	released[button] = true
	mouseX, mouseY = x, y
	print("LOVE_PHYSICAL_MOUSE_RELEASE", button, math.floor(x), math.floor(y), presses)
end

function love.mousemoved(x, y, deltaX, deltaY, isTouch)
	assert(isTouch == false)
	moveCount = moveCount + 1
	mouseX, mouseY = x, y
	if moveCount == 1 then
		print("LOVE_PHYSICAL_MOUSE_MOVE", math.floor(x), math.floor(y), math.floor(deltaX), math.floor(deltaY))
	end
end

function love.wheelmoved(x, y)
	assert(x ~= 0 or y ~= 0)
	wheelSeen = true
	print("LOVE_PHYSICAL_MOUSE_WHEEL", x, y)
end

function love.update()
	if complete() then
		print("LOVE_PHYSICAL_MOUSE_PASS", moveCount)
		love.event.quit()
	end
end

function love.draw()
	love.graphics.clear(0.025, 0.035, 0.07, 1)
	love.graphics.setColor(0.2, 0.8, 1, 1)
	love.graphics.rectangle("line", 10, 10, 460, 280)
	love.graphics.line(240, 20, 240, 280)
	love.graphics.line(20, 150, 460, 150)
	love.graphics.circle("fill", mouseX, mouseY, 8)
end
