local source
local frames = 0

local function makeTone()
	local data = love.sound.newSoundData(1600, 8000, 16, 1)
	for index = 0, 1599 do
		data:setSample(index, math.sin(index * math.pi / 10) * 0.25)
	end
	return data
end

function love.load()
	assert(love.audio.setEffect("shared", {
		type = "echo",
		volume = 0.25,
		delay = 0.04,
		damping = 0.2,
		feedback = 0.15,
	}))
	local effect = assert(love.audio.getEffect("shared"))
	assert(effect.type == "echo" and math.abs(effect.delay - 0.04) < 0.00001)
	source = love.audio.newSource(makeTone())
	source:setLooping(true)
	source:setVolume(0.01)
	assert(source:setEffect("shared", true))
	assert(source:play())
end

function love.update()
	frames = frames + 1
	if frames == 12 then
		assert(select(1, source:getEffect("shared")))
		print("LOVE_AUDIO_EFFECT_FIRST_PASS", "delay=0.04", "close=first")
		assert(love.event.quit())
	elseif frames > 120 then
		error("first effect-isolation LoveNode did not quit")
	end
end

function love.quit()
	if source then source:stop() end
	return false
end
