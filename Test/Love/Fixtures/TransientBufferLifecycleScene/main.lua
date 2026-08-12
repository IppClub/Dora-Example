function love.draw()
	for index = 1, 840 do
		love.graphics.points((index * 17) % 320, (index * 31) % 180)
	end
end
