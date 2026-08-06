function love.load()
	assert(second_boot_value == "second")
end

function love.draw()
	local width, height = love.graphics.getDimensions()
	assert(width == 800 and height == 600)
	love.graphics.clear(0.16, 0.04, 0.08, 1)
	love.graphics.setColor(1, 0.75, 0.2, 1)
	love.graphics.rectangle("fill", 80, 80, 640, 150)
	love.graphics.setColor(0.3, 0.95, 1, 1)
	love.graphics.push()
	love.graphics.translate(400, 400)
	love.graphics.rotate(-0.4)
	love.graphics.polygon("fill", -120, 90, 0, -100, 120, 90)
	love.graphics.pop()
end
