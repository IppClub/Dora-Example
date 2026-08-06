local frames = 0

function love.update()
	frames = frames + 1
end

function love.draw()
	local phase = (frames % 120) / 120
	love.graphics.clear(0.015, 0.02, 0.035, 1)
	love.graphics.setColor(0.2 + phase * 0.6, 0.75, 1 - phase * 0.5, 1)
	love.graphics.rectangle("fill", 6 + phase * 48, 8, 24, 20)
	love.graphics.setColor(1, 0.75, 0.2, 1)
	love.graphics.setPointSize(3)
	love.graphics.points(12 + phase * 68, 48)
end
