local frames = 0
local generation = 0
local systemCursorTypes = {
	"arrow", "ibeam", "wait", "crosshair", "waitarrow", "sizenwse",
	"sizenesw", "sizewe", "sizens", "sizeall", "no", "hand",
}

function love.load()
	love.filesystem.setIdentity("love-mouse-settings")
	if love.filesystem.getInfo("restart-marker.txt") then
		generation = 2
	else
		generation = 1
		assert(love.filesystem.write("restart-marker.txt", "restart"))
	end
	assert(love.mouse.isVisible())
	assert(not love.mouse.isGrabbed())
	assert(not love.mouse.getRelativeMode())
	assert(love.mouse.isCursorSupported())
	assert(love.mouse.getCursor() == nil)
end

function love.update()
	frames = frames + 1
	if generation == 1 and frames == 2 then
		love.mouse.setPosition(96, 64)
		love.mouse.setX(100)
		love.mouse.setY(68)
		local x, y = love.mouse.getPosition()
		assert(x == 100 and y == 68)
		love.mouse.setVisible(false)
		love.mouse.setGrabbed(true)
		assert(love.mouse.setRelativeMode(true))
		assert(not love.mouse.isVisible())
		assert(love.mouse.isGrabbed())
		assert(love.mouse.getRelativeMode())
		local data = love.image.newImageData(8, 8)
		data:setPixel(2, 3, 1, 1, 1, 1)
		local imageCursor = love.mouse.newCursor(data, 2, 3)
		assert(imageCursor:getType() == "image")
		assert(imageCursor:type() == "Cursor" and imageCursor:typeOf("Object"))
		love.mouse.setCursor(imageCursor)
		assert(love.mouse.getCursor() == imageCursor)
	elseif generation == 1 and frames == 45 then
		-- Restart while cursor, visibility, grab, and relative mode are still active.
		-- LoveNode must restore the host before destroying the old Runtime handles.
		love.event.quit("restart")
	elseif generation == 2 and frames == 2 then
		for _, cursorType in ipairs(systemCursorTypes) do
			local cursor = love.mouse.getSystemCursor(cursorType)
			assert(cursor:getType() == cursorType)
			assert(cursor == love.mouse.getSystemCursor(cursorType))
		end
		local hand = love.mouse.getSystemCursor("hand")
		love.mouse.setCursor(hand)
		assert(love.mouse.getCursor() == hand)
		love.mouse.setCursor()
		assert(love.mouse.getCursor() == nil)
	elseif generation == 2 and frames >= 15 then
		love.event.quit()
	end
end

function love.draw()
	love.graphics.clear(0.04, 0.06, 0.1, 1)
	love.graphics.setColor(0.2, 0.8, 1, 1)
	love.graphics.circle("fill", generation == 1 and 100 or 132, 68, 8)
end
