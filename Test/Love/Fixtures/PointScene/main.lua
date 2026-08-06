local frames = 0
local sizes = {1, 3, 5, 9}

function love.load()
	assert(love.graphics.getPointSize() == 1)
	love.graphics.setPointSize(5)
	love.graphics.push("all")
	love.graphics.setPointSize(9)
	love.graphics.pop()
	assert(love.graphics.getPointSize() == 5)
	print("LOVE_POINT_SIZE_STATE_PASS", love.graphics.getPointSize())
end

function love.update()
	frames = frames + 1
	if frames == 240 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_POINT_SIZE_QUIT_PASS")
	return false
end

function love.draw()
	love.graphics.clear(0.02, 0.025, 0.04, 1)
	for index, size in ipairs(sizes) do
		local x = 20 + (index - 1) * 25
		love.graphics.setColor(0.2, 0.35, 0.5, 1)
		love.graphics.rectangle("line", x - 10, 60, 20, 120)
		love.graphics.setColor(1, 0.8, 0.2, 1)
		love.graphics.setPointSize(size)
		love.graphics.points(x, 100, x, 140)
	end
	love.graphics.setColor(0.2, 0.8, 1, 1)
	love.graphics.setPointSize(5)
	love.graphics.push()
	love.graphics.translate(30, 15)
	love.graphics.scale(2, 3)
	love.graphics.points(55, 55)
	love.graphics.pop()
end
