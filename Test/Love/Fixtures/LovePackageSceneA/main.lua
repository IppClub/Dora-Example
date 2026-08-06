local helper = require("pkg.helper")
local frame = 0
local image

function love.load()
	local resource, size = love.filesystem.read("data/message.txt")
	assert(resource == "RESOURCE_A\n" and size == #resource)
	assert(love.filesystem.getSource():find("LovePackages", 1, true))
	local ok, message = love.filesystem.write("state.txt", helper.name)
	assert(ok and message == nil)
	assert(love.filesystem.read("state.txt") == helper.name)
	image = love.graphics.newImage("pig.png")
	assert(image:getWidth() == 256 and image:getHeight() == 256)
	print("LOVE_PACKAGE_A_LOAD", helper.name, resource:gsub("\n", ""))
end

function love.draw()
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(table.unpack(helper.color))
	love.graphics.rectangle("fill", 8, 8, 40, 24)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, 56, 8, 0, 0.125, 0.125)
end

function love.update()
	frame = frame + 1
	if frame == 2 then
		print("LOVE_PACKAGE_A_PASS")
		love.event.quit()
	end
end
