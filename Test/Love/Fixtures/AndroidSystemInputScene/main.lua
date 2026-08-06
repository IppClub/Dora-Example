local pressedId
local touchPressed = false
local touchMoved = false
local touchReleased = false
local keyPressed = false
local keyReleased = false
local frames = 0

local function containsTouch(id)
	for _, activeId in ipairs(love.touch.getTouches()) do
		if activeId == id then return true end
	end
	return false
end

local function inside(x, y)
	return x >= 0 and x <= love.graphics.getWidth()
		and y >= 0 and y <= love.graphics.getHeight()
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	print("LOVE_ANDROID_SYSTEM_TOUCH_PRESSED", x, y, dx, dy, pressure)
	assert(pressedId == nil, "unexpected second Android touch")
	assert(inside(x, y), ("touch press outside Love surface: %.3f %.3f"):format(x, y))
	assert(math.abs(dx) < 1 and math.abs(dy) < 1, "initial touch delta is not near zero")
	assert(pressure == 1, "Dora Android touch pressure must use the documented fixed value")
	assert(containsTouch(id), "pressed touch is absent from love.touch.getTouches")
	local currentX, currentY = love.touch.getPosition(id)
	assert(math.abs(currentX - x) < 0.01 and math.abs(currentY - y) < 0.01,
		"pressed touch position state does not match callback")
	pressedId = id
	touchPressed = true
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	print("LOVE_ANDROID_SYSTEM_TOUCH_MOVED", x, y, dx, dy, pressure)
	assert(id == pressedId, "Android touch id changed during swipe")
	assert(inside(x, y), ("touch move outside Love surface: %.3f %.3f"):format(x, y))
	assert(pressure == 1, "Dora Android touch pressure changed during swipe")
	assert(containsTouch(id), "moved touch is absent from love.touch.getTouches")
	local currentX, currentY = love.touch.getPosition(id)
	assert(math.abs(currentX - x) < 0.01 and math.abs(currentY - y) < 0.01,
		"moved touch position state does not match callback")
	if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then touchMoved = true end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	print("LOVE_ANDROID_SYSTEM_TOUCH_RELEASED", x, y, dx, dy, pressure)
	assert(id == pressedId, "Android touch id changed before release")
	assert(inside(x, y), ("touch release outside Love surface: %.3f %.3f"):format(x, y))
	assert(pressure == 1, "Dora Android touch pressure changed on release")
	assert(not containsTouch(id), "released touch remains in love.touch.getTouches")
	touchReleased = true
end

function love.keypressed(key, scancode, isRepeat)
	print("LOVE_ANDROID_SYSTEM_KEY_PRESSED", key, scancode, isRepeat)
	assert(not keyPressed, "Android keydown was delivered more than once")
	assert(key == "a" and scancode == "a" and not isRepeat,
		("unexpected Android key: %s/%s repeat=%s"):format(key, scancode, tostring(isRepeat)))
	assert(love.keyboard.isDown("a"), "Android key state was not updated before keypressed")
	keyPressed = true
end

function love.keyreleased(key, scancode)
	assert(keyPressed and not keyReleased, "Android keyup order or count is invalid")
	assert(key == "a" and scancode == "a", "unexpected Android key release")
	assert(not love.keyboard.isDown("a"), "Android key state was not cleared before keyreleased")
	keyReleased = true
end

function love.update()
	frames = frames + 1
	if touchPressed and touchMoved and touchReleased and keyPressed and keyReleased and frames >= 10 then
		print("LOVE_ANDROID_SYSTEM_INPUT_PASS", "touch=press+move+release", "key=a", "source=os")
		love.event.quit()
	end
	if frames == 850 then
		error(("Android system input timed out touch=%s/%s/%s key=%s/%s")
			:format(tostring(touchPressed), tostring(touchMoved), tostring(touchReleased),
				tostring(keyPressed), tostring(keyReleased)))
	end
end

function love.draw()
	love.graphics.clear(0.02, 0.03, 0.04, 1)
	love.graphics.setColor(touchPressed and 0.1 or 0.5, touchReleased and 0.9 or 0.2,
		keyPressed and 0.9 or 0.2, 1)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
end
