local frames = 0

function love.update()
	frames = frames + 1
	if frames == 2 then
		assert(love.event.quit() == true)
	end
end

function love.quit()
	print("LOVE_QUIT_CALLBACK")
	return false
end

function love.draw()
	love.graphics.clear(0.12, 0.04, 0.04, 1)
	love.graphics.setColor(1, 0.25, 0.15, 1)
	love.graphics.rectangle("line", 16, 16, 288, 148)
end
