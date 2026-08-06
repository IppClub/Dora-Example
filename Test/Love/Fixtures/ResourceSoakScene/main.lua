local image
local imageData
local font
local soundData
local fileSource
local pcmSource
local frames = 0

function love.load()
	image = love.graphics.newImage("pig.png")
	image:setFilter("nearest")
	image:setWrap("repeat", "mirroredrepeat")
	imageData = love.image.newImageData("pig.png")
	imageData:setPixel(0, 0, 1, 0.5, 0.25, 1)
	font = love.graphics.newFont(14)
	soundData = love.sound.newSoundData("tone.wav")
	fileSource = love.audio.newSource("tone.wav", "static")
	pcmSource = love.audio.newSource(soundData)
	fileSource:setVolume(0.01)
	pcmSource:setVolume(0.01)
	assert(love.audio.play(fileSource, pcmSource))
	assert(image:getWidth() == 256 and imageData:getWidth() == 256)
	assert(font:getHeight() == 14 and soundData:getSampleCount() == 17640)
end

function love.update()
	frames = frames + 1
	if frames == 4 then
		love.audio.stop()
		assert(love.event.quit())
	end
end

function love.draw()
	love.graphics.clear(0.02, 0.03, 0.05, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, 8, 8, 0, 0.25, 0.25)
	love.graphics.setFont(font)
	love.graphics.print("Love resource soak", 8, 86)
end

function love.quit()
	print("LOVE_RESOURCE_SOAK_INSTANCE_QUIT")
	return false
end
