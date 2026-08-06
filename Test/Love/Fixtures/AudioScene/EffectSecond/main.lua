local source
local frames = 0

local function makeTone()
	local data = love.sound.newSoundData(1600, 8000, 16, 1)
	for index = 0, 1599 do
		data:setSample(index, math.sin(index * math.pi / 8) * 0.25)
	end
	return data
end

function love.load()
	assert(love.audio.setEffect("shared", {
		type = "echo",
		volume = 0.6,
		delay = 0.18,
		damping = 0.55,
		feedback = 0.45,
	}))
	local effect = assert(love.audio.getEffect("shared"))
	assert(effect.type == "echo" and math.abs(effect.delay - 0.18) < 0.00001)
	source = love.audio.newSource(makeTone())
	source:setLooping(true)
	source:setVolume(0.01)
	assert(source:setEffect("shared", {type = "lowpass", volume = 0.9, highgain = 0.7}))
	assert(source:play())
end

function love.update()
	frames = frames + 1
	if frames == 60 then
		local effect = assert(love.audio.getEffect("shared"))
		local enabled, filter = source:getEffect("shared")
		assert(effect.type == "echo" and math.abs(effect.delay - 0.18) < 0.00001
			and math.abs(effect.volume - 0.6) < 0.00001
			and math.abs(effect.feedback - 0.45) < 0.00001)
		assert(enabled and filter.type == "lowpass"
			and math.abs(filter.highgain - 0.7) < 0.00001)
		assert(source:isPlaying())
		print("LOVE_AUDIO_EFFECT_SECOND_PASS", "delay=0.18",
			"after-first-close=pass", "source-filter=pass")
		assert(love.event.quit())
	elseif frames > 180 then
		error("second effect-isolation LoveNode did not quit")
	end
end

function love.quit()
	if source then source:stop() end
	return false
end
