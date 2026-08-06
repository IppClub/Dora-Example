local frames = 0

function love.load()
	local x, y, z = love.audio.getPosition()
	assert(x == 21 and y == 22 and z == 23)
	local fx, fy, fz, ux, uy, uz = love.audio.getOrientation()
	assert(fx == 1 and fy == 0 and fz == 0)
	assert(ux == 0 and uy == 0 and uz == 1)
	local vx, vy, vz = love.audio.getVelocity()
	assert(vx == 3 and vy == 4 and vz == 5)
	assert(love.audio.getDopplerScale() == 2.5)
	assert(love.audio.getDistanceModel() == "exponentclamped")
	assert(love.audio.getVolume() == 1, "LoveNode bus volume must remain instance-local")
	print("LOVE_AUDIO_GLOBAL_SPATIAL_PASS", x, y, z, vx, vy, vz,
		love.audio.getDopplerScale(), love.audio.getDistanceModel())
end

function love.update()
	frames = frames + 1
	if frames >= 2 then
		assert(love.event.quit())
	end
end
