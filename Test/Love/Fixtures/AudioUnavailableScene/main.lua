local source
local frames = 0

function love.load()
	source = love.audio.newSource("tone.wav", "static")
	assert(source:getType() == "static")
	source:setLooping(true)
	source:setVolume(0.25)
	source:setPitch(1.5)
	assert(source:isLooping())
	assert(source:getVolume() == 0.25)
	assert(source:getPitch() == 1.5)
	assert(not source:play())
	assert(not love.audio.play(source))
	assert(not source:isPlaying())
	assert(not source:isPaused())
	print("LOVE_AUDIO_UNAVAILABLE_PLAY_SAFE")
end

function love.update()
	frames = frames + 1
	if frames == 2 then
		source:pause()
		source:seek(0.05, "seconds")
		assert(math.abs(source:tell("seconds") - 0.05) < 0.000001)
		source:stop()
		love.audio.pause()
		love.audio.stop()
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_AUDIO_UNAVAILABLE_RELEASE_SAFE")
	return false
end
