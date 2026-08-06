local frames = 0

function love.load()
	assert(love.graphics.getWidth() > 0 and love.graphics.getHeight() > 0)
end

function love.update()
	frames = frames + 1
	if frames >= 6 then
		assert(love.event.quit())
	end
end

function love.draw()
	love.graphics.clear(0.04, 0.05, 0.08, 1)
	love.graphics.setColor(0.2, 0.8, 0.4, 1)
	love.graphics.rectangle("fill", 4, 4, 24, 16)
end
