local love = require("love")
local filesystem = love.filesystem

filesystem.setIdentity("love-event-restart-target")

local generation = (tonumber(filesystem.read("generation.txt") or "0") or 0) + 1
assert(filesystem.write("generation.txt", tostring(generation)))

local frames = 0
local source

function love.load()
	if generation == 1 then
		local samples = love.sound.newSoundData(256, 8000, 16, 1)
		source = love.audio.newSource(samples)
		source:setLooping(true)
		assert(source:play())
		assert(love.audio.getActiveSourceCount() == 1)
	else
		assert(generation == 2, "unexpected restart generation " .. tostring(generation))
		assert(love.audio.getActiveSourceCount() == 0)
	end
	print("LOVE_EVENT_RESTART_LOAD", generation)
end

function love.update()
	frames = frames + 1
	if generation == 1 and frames == 3 then
		assert(love.event.quit("restart"))
	elseif generation == 2 and frames == 20 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_EVENT_RESTART_QUIT", generation)
	return false
end

function love.draw()
	love.graphics.clear(generation == 1 and 0.7 or 0.1, generation == 2 and 0.7 or 0.1, 0.2, 1)
end
