local sources = {}
local frames = 0

local function makeTone()
	local data = love.sound.newSoundData(800, 8000, 16, 1)
	for index = 0, 799 do
		data:setSample(index, math.sin(index * math.pi / 8) * 0.08)
	end
	return data
end

function love.load()
	assert(love.audio.setEffect("soak-echo", {
		type = "echo", volume = 0.35, delay = 0.04, damping = 0.2, feedback = 0.25,
	}))
	assert(love.audio.setEffect("soak-room", {
		type = "reverb", volume = 0.2, decaytime = 0.3,
		diffusion = 0.6, highgain = 0.75,
	}))
	local tone = makeTone()
	for index = 1, 24 do
		local source = love.audio.newSource(tone)
		source:setLooping(true)
		source:setVolume(0.002)
		if index % 2 == 0 then
			assert(source:setFilter({type = "lowpass", volume = 0.9,
				highgain = 0.3 + (index % 5) * 0.1}))
		else
			assert(source:setFilter({type = "highpass", volume = 0.9,
				lowgain = 0.25 + (index % 4) * 0.15}))
		end
		assert(source:setEffect("soak-echo", true))
		assert(source:setEffect("soak-room", {
			type = "lowpass", volume = 0.8, highgain = 0.65,
		}))
		assert(source:play())
		sources[index] = source
	end
	assert(love.audio.getActiveSourceCount() == 24)
end

function love.update()
	frames = frames + 1
	if frames == 15 then
		assert(love.audio.setEffect("soak-echo", {
			type = "echo", volume = 0.45, delay = 0.08, damping = 0.45, feedback = 0.35,
		}))
		for index, source in ipairs(sources) do
			if index % 3 == 0 then
				assert(source:setFilter({type = "bandpass", volume = 0.75,
					lowgain = 0.2, highgain = 0.45 + (index % 4) * 0.1}))
			else
				assert(source:setFilter({type = "lowpass", volume = 0.75,
					highgain = 0.45 + (index % 4) * 0.1}))
			end
		end
	elseif frames == 30 then
		for index, source in ipairs(sources) do
			assert(source:setEffect("soak-room", index % 2 == 0))
		end
	elseif frames == 45 then
		for _, source in ipairs(sources) do source:pause() end
		assert(love.audio.getActiveSourceCount() == 24)
	elseif frames == 47 then
		assert(love.audio.play(sources))
	elseif frames == 75 then
		for index = 1, 12 do sources[index]:stop() end
		assert(love.audio.getActiveSourceCount() == 12)
		for index = 1, 12 do assert(sources[index]:play()) end
	elseif frames == 110 then
		assert(love.audio.getActiveSourceCount() == 24)
		assert(love.event.quit())
	elseif frames > 180 then
		error("audio effect soak workload did not quit")
	end
end

function love.quit()
	love.audio.stop()
	return false
end
