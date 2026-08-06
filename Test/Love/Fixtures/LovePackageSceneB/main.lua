local helper = require("pkg.helper")
local frame = 0

function love.load()
	local resource, size = love.filesystem.read("data/message.txt")
	assert(resource == "RESOURCE_B\n" and size == #resource)
	assert(love.filesystem.getSource():find("LovePackages", 1, true))
	local ok, message = love.filesystem.write("state.txt", helper.name)
	assert(ok and message == nil)
	assert(love.filesystem.read("state.txt") == helper.name)
	print("LOVE_PACKAGE_B_LOAD", helper.name, resource:gsub("\n", ""))
end

function love.draw()
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(table.unpack(helper.color))
	love.graphics.rectangle("fill", 6, 6, 36, 20)
end

function love.update()
	frame = frame + 1
	if frame == 5 then
		print("LOVE_PACKAGE_B_PASS")
		love.event.quit()
	end
end
