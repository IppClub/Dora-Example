local image
local animated
local additive
local moving
local frames = 0
local screenshotRequested = false
local screenshotVerified = false

function love.load()
	love.filesystem.setIdentity("dora-love-particles")
	image = love.graphics.newImage("atlas.png")
	image:setFilter("nearest")
	local red = love.graphics.newQuad(0, 0, 64, 64, image)
	local blue = love.graphics.newQuad(0, 64, 64, 64, image)

	animated = love.graphics.newParticleSystem(image, 4)
	animated:setParticleLifetime(2)
	animated:setPosition(100, 100)
	animated:setSpeed(0)
	animated:setSizes(1, 0.75)
	animated:setColors({1, 1, 1, 1}, {1, 1, 1, 0.6})
	animated:setQuads(red, blue)
	animated:emit(1)
	animated:update(1.1)
	animated:pause()
	assert(animated:getCount() == 1 and animated:isPaused())
	assert(#animated:getQuads() == 2)

	additive = love.graphics.newParticleSystem(image, 4)
	additive:setParticleLifetime(2)
	additive:setPosition(220, 100)
	additive:setSpeed(0)
	additive:setColors({1, 1, 1, 0.5})
	additive:setQuads(red)
	additive:emit(2)
	additive:pause()
	assert(additive:getCount() == 2)

	moving = love.graphics.newParticleSystem(image, 4)
	moving:setParticleLifetime(2)
	moving:setPosition(300, 100)
	moving:setDirection(0)
	moving:setSpeed(40)
	moving:setLinearAcceleration(0, 0)
	moving:setQuads(red)
	moving:emit(1)
	moving:update(0.5)
	moving:pause()
	local moveX, moveY = moving:getPosition()
	assert(moveX == 300 and moveY == 100 and moving:getCount() == 1)

	local lifecycle = love.graphics.newParticleSystem(image, 4)
	lifecycle:setParticleLifetime(1)
	lifecycle:setEmissionRate(4)
	lifecycle:setEmitterLifetime(0.6)
	lifecycle:update(0.5)
	assert(lifecycle:getCount() == 1)
	lifecycle:update(0.2)
	assert(lifecycle:getCount() == 2 and lifecycle:isStopped())
	local clone = lifecycle:clone()
	assert(clone:getCount() == 0 and clone:getBufferSize() == 4 and clone:getTexture() == image)
	clone:start()
	clone:emit(4)
	assert(clone:isFull())
	clone:reset()
	assert(clone:isEmpty())
	print("LOVE_PARTICLE_STATE_PASS", animated:getCount(), additive:getCount(), moving:getCount(), lifecycle:getCount())
	print("LOVE_PARTICLE_SAVE_ROOT", love.filesystem.getSaveDirectory())
end

function love.update()
	frames = frames + 1
	if frames > 240 and not screenshotVerified then
		error("ParticleSystem screenshot callback did not complete")
	end
	if frames >= 90 and screenshotVerified then
		animated:reset()
		additive:reset()
		moving:reset()
		assert(love.event.quit())
	end
end

function love.draw()
	love.graphics.clear(0.02, 0.025, 0.04, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(animated)
	love.graphics.setBlendMode("add")
	love.graphics.draw(additive)
	love.graphics.setBlendMode("alpha")
	love.graphics.draw(moving)
	love.graphics.setColor(0.3, 0.8, 1, 1)
	love.graphics.rectangle("line", 50, 50, 330, 100)
	if frames >= 10 and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("particles.png")
		love.graphics.captureScreenshot(function(data)
			local blueR, blueG, blueB = data:getPixel(100, 100)
			local addR, addG, addB = data:getPixel(220, 100)
			local moveR, moveG, moveB = data:getPixel(340, 100)
			print("LOVE_PARTICLE_PIXEL_VALUES", blueR, blueG, blueB, addR, addG, addB, moveR, moveG, moveB)
			assert(blueR < 0.3 and blueG < 0.65 and blueB > 0.55)
			assert(addR > 0.75 and addG < 0.35 and addB < 0.4)
			assert(moveR > 0.75 and moveG < 0.3 and moveB < 0.35)
			screenshotVerified = true
			print("LOVE_PARTICLE_PIXEL_PASS", blueB, addR, moveR)
		end)
	end
end

function love.quit()
	print("LOVE_PARTICLE_QUIT_PASS", animated:getCount(), additive:getCount(), moving:getCount())
	return false
end
