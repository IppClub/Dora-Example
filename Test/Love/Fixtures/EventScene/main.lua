local marker
local automaticallyDispatched = false
local updated = false

function love.hostevent(flag, number, text, object)
	assert(flag == false and number == 21 and text == "node")
	assert(object == marker)
	automaticallyDispatched = true
end

function love.load()
	love.event.pump()
	marker = love.data.newByteData("event-scene-marker")

	assert(love.event.push("manual", true, 7, "load", marker, nil, "ignored"))
	local name, flag, number, text, object = love.event.wait()
	assert(name == "manual" and flag == true and number == 7 and text == "load")
	assert(object == marker and love.event.wait() == nil)

	assert(love.event.push("discarded", marker))
	love.event.clear()
	assert(love.event.poll()() == nil)

	assert(love.event.push("hostevent", false, 21, "node", marker))
end

function love.update()
	assert(automaticallyDispatched)
	assert(not updated)
	updated = true

	assert(love.event.push("manual-update", 12, marker))
	local iterator = love.event.poll()
	local name, number, object = iterator()
	assert(name == "manual-update" and number == 12 and object == marker)
	assert(iterator() == nil)

	assert(love.event.push("discarded-update", marker))
	love.event.clear()
	assert(love.event.wait() == nil)
	print("LOVE_EVENT_HOST_PASS")
	assert(love.event.quit())
end

function love.quit()
	assert(automaticallyDispatched and updated)
	print("LOVE_EVENT_QUIT_PASS")
	return false
end
