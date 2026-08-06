local frames = 0
local pressOrder = {}
local pressed = {}
local moved = {}
local released = {}
local sawTwoActive = false
local sawOneRemaining = false

local function activeTouches()
	local result = {}
	for _, id in ipairs(love.touch.getTouches()) do result[id] = true end
	return result
end

local function inside(x, y)
	return x >= 0 and x <= love.graphics.getWidth()
		and y >= 0 and y <= love.graphics.getHeight()
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	assert(not pressed[id], "Android multi-touch repeated a touchpressed ID")
	assert(#pressOrder < 2, "Android multi-touch produced more than two touch IDs")
	assert(inside(x, y), "Android multi-touch press is outside the Love surface")
	assert(math.abs(dx) < 1 and math.abs(dy) < 1, "Android multi-touch initial delta is not zero")
	assert(pressure == 1, "Dora Android multi-touch pressure must use the fixed value")
	pressed[id] = true
	pressOrder[#pressOrder + 1] = id
	local active = activeTouches()
	assert(active[id], "new Android multi-touch ID is absent from getTouches")
	if #pressOrder == 2 then
		assert(pressOrder[1] ~= pressOrder[2], "Android multi-touch IDs are not unique")
		assert(active[pressOrder[1]] and active[pressOrder[2]],
			"two Android touches were not simultaneously active")
		sawTwoActive = true
	end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	assert(pressed[id] and not released[id], "Android multi-touch moved an inactive ID")
	assert(inside(x, y), "Android multi-touch move is outside the Love surface")
	assert(pressure == 1, "Dora Android multi-touch pressure changed while moving")
	local active = activeTouches()
	assert(active[id], "moved Android multi-touch ID is absent from getTouches")
	local currentX, currentY = love.touch.getPosition(id)
	assert(math.abs(currentX - x) < 0.01 and math.abs(currentY - y) < 0.01,
		"Android multi-touch position state does not match callback")
	if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then moved[id] = true end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	assert(pressed[id] and not released[id], "Android multi-touch released an inactive ID")
	assert(inside(x, y), "Android multi-touch release is outside the Love surface")
	assert(pressure == 1, "Dora Android multi-touch pressure changed on release")
	released[id] = true
	local active = activeTouches()
	assert(not active[id], "released Android multi-touch ID remains in getTouches")
	local other = id == pressOrder[1] and pressOrder[2] or pressOrder[1]
	if other and not released[other] then
		assert(active[other], "releasing one Android touch removed the other")
		sawOneRemaining = true
	end
end

function love.update()
	frames = frames + 1
	if #pressOrder == 2
		and moved[pressOrder[1]] and moved[pressOrder[2]]
		and released[pressOrder[1]] and released[pressOrder[2]]
		and sawTwoActive and sawOneRemaining then
		assert(#love.touch.getTouches() == 0, "Android multi-touch state is not empty after release")
		print("LOVE_ANDROID_MULTITOUCH_PASS", "touches=2", "move=both", "release=ordered")
		love.event.quit()
	end
	if frames == 850 then
		error(("Android multi-touch timed out presses=%d two=%s one=%s")
			:format(#pressOrder, tostring(sawTwoActive), tostring(sawOneRemaining)))
	end
end

function love.draw()
	love.graphics.clear(0.03, 0.04, 0.05, 1)
	love.graphics.setColor(sawTwoActive and 0.2 or 0.7,
		sawOneRemaining and 0.9 or 0.2, #pressOrder == 2 and 0.8 or 0.2, 1)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
end
