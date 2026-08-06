assert(OWNER_ROLE == "first" or OWNER_ROLE == "second")

local source
local frames = 0

function love.load()
	source = love.audio.newSource("tone.wav", "static")
	source:setLooping(true)
	source:setVolume(OWNER_ROLE == "first" and 0.03 or 0.05)
	assert(source:play())
	print("LOVE_AUDIO_OWNER_STARTED", OWNER_ROLE)
end

function love.update()
	frames = frames + 1
	assert(source:isPlaying())
	if OWNER_ROLE == "first" and frames == 12 then
		assert(love.event.quit())
	elseif OWNER_ROLE == "second" and frames == 45 then
		print("LOVE_AUDIO_SECOND_SURVIVED_FIRST_EXIT", source:isPlaying())
	elseif OWNER_ROLE == "second" and frames == 90 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_AUDIO_OWNER_QUIT", OWNER_ROLE, source:isPlaying())
	return false
end

function love.draw()
	if OWNER_ROLE == "first" then
		love.graphics.clear(0.12, 0.03, 0.03, 1)
	else
		love.graphics.clear(0.03, 0.08, 0.12, 1)
	end
end
