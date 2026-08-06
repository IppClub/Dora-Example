local staticSource
local streamSource
local pcmSource
local staticClone
local queueSource
local queueClone
local queueData
local monoQueueSource
local monoQueueData
local queueRefilled = false
local frames = 0

function love.load()
	assert(love.audio.getVolume() == 1)
	assert(love.audio.getActiveSourceCount() == 0)
	love.audio.setVolume(0.6)
	assert(math.abs(love.audio.getVolume() - 0.6) < 0.0001)
	print("LOVE_AUDIO_BUS_VOLUME_PASS", love.audio.getVolume())
	love.audio.setPosition(21, 22, 23)
	love.audio.setOrientation(1, 0, 0, 0, 0, 1)
	love.audio.setVelocity(3, 4, 5)
	love.audio.setDopplerScale(2.5)
	love.audio.setDistanceModel("exponentclamped")
	local sound = require("love.sound")
	local soundData = sound.newSoundData("tone.wav")
	assert(soundData:getSampleRate() == 44100)
	assert(soundData:getChannelCount() == 1 and soundData:getChannels() == 1)
	assert(soundData:getBitDepth() == 16 and soundData:getSampleCount() == 17640)
	assert(math.abs(soundData:getDuration() - 0.4) < 0.0001)
	assert(soundData:getSize() == 35280 and #soundData:getString() == 35280)
	local decoder = sound.newDecoder("tone.wav", 4096)
	assert(decoder:getSampleRate() == 44100 and decoder:getChannelCount() == 1)
	assert(decoder:getBitDepth() == 16 and math.abs(decoder:getDuration() - 0.4) < 0.0001)
	local firstChunk = assert(decoder:decode())
	assert(firstChunk:getSampleCount() == 2048 and firstChunk:getChannelCount() == 1)
	local decoderClone = decoder:clone()
	assert(decoderClone:decode():getSampleCount() == 2048)
	decoder:seek(0.2)
	local decoderTail = sound.newSoundData(decoder)
	assert(decoderTail:getSampleCount() == 8820 and decoder:decode() == nil)
	print("LOVE_DECODER_SOLOUD_PASS", firstChunk:getSampleCount(), decoderTail:getSampleCount(), decoder:getDuration())
	local clone = soundData:clone()
	local original = soundData:getSample(0)
	clone:setSample(0, 0.75)
	assert(soundData:getSample(0) == original and math.abs(clone:getSample(0) - 0.75) < 0.0001)
	local eightBit = sound.newSoundData(2, 8000, 8, 2)
	eightBit:setSample(0, 1, -1)
	eightBit:setSample(0, 2, 1)
	assert(eightBit:getSample(0, 1) == -1 and eightBit:getSample(0, 2) == 1)
	print("LOVE_SOUNDDATA_SOLOUD_PASS", soundData:getSampleRate(), soundData:getSampleCount(), soundData:getChannelCount(), soundData:getDuration())
	local formats = {
		{"tone.ogg", 2, false},
		{"tone.mp3", 1, true},
		{"tone.flac", 1, false},
	}
	for _, entry in ipairs(formats) do
		local input = entry[3] and love.filesystem.newFileData(entry[1]) or entry[1]
		local decoded = sound.newSoundData(input)
		assert(decoded:getSampleRate() == 44100 and decoded:getChannelCount() == entry[2])
		assert(decoded:getBitDepth() == 16 and decoded:getSampleCount() > 15000)
		assert(decoded:getDuration() > 0.35 and decoded:getDuration() < 0.5)
		local formatDecoder = sound.newDecoder(input, 2048)
		local formatChunk = assert(formatDecoder:decode())
		assert(formatChunk:getSampleRate() == 44100 and formatChunk:getChannelCount() == entry[2])
		print("LOVE_SOUNDDATA_FORMAT_PASS", entry[1], decoded:getSampleRate(), decoded:getChannelCount(), decoded:getSampleCount(), decoded:getDuration())
	end
	pcmSource = love.audio.newSource(clone)
	assert(pcmSource:getType() == "static" and pcmSource:getChannelCount() == 1
		and pcmSource:getChannels() == 1)
	pcmSource:setVolume(0.02)

	staticSource = love.audio.newSource("tone.wav", "static")
	streamSource = love.audio.newSource("tone.wav", "stream")
	assert(staticSource:getType() == "static")
	assert(streamSource:getType() == "stream")
	assert(staticSource:getChannelCount() == 1 and staticSource:getChannels() == 1)
	assert(streamSource:getChannelCount() == 1 and streamSource:getChannels() == 1)
	staticSource:setVolume(0.08)
	staticSource:setLooping(true)
	staticSource:setPosition(21, 22, 23)
	staticSource:setVelocity(1, 2, 3)
	staticSource:setDirection(0, 0, -1)
	staticSource:setCone(math.pi / 2, math.pi * 3 / 2, 0.25, 0.5)
	staticSource:setAirAbsorption(1.5)
	staticSource:setVolumeLimits(0.01, 0.7)
	staticSource:setRelative(false)
	staticSource:setAttenuationDistances(2, 2000000)
	staticSource:setRolloff(0.5)
	assert(love.audio.isEffectsSupported())
	assert(love.audio.getMaxSceneEffects() == 64 and love.audio.getMaxSourceEffects() == 3)
	assert(love.audio.setEffect("echo", {type = "echo", volume = 0.35,
		delay = 0.08, damping = 0.4, feedback = 0.3}))
	assert(love.audio.setEffect("room", {type = "reverb", volume = 0.2,
		decaytime = 1.5, diffusion = 0.7, highgain = 0.8}))
	assert(staticSource:setFilter({type = "lowpass", volume = 0.9, highgain = 0.65}))
	assert(staticSource:setEffect("echo", true))
	assert(staticSource:setEffect("room", {type = "highpass", volume = 0.8, lowgain = 0.5}))
	local directFilter = assert(staticSource:getFilter())
	local roomEnabled, roomFilter = staticSource:getEffect("room")
	assert(directFilter.type == "lowpass" and roomEnabled and roomFilter.type == "highpass")
	local sourceX, sourceY, sourceZ = staticSource:getPosition()
	local velocityX, velocityY, velocityZ = staticSource:getVelocity()
	local directionX, directionY, directionZ = staticSource:getDirection()
	local coneInner, coneOuter, coneVolume, coneHighGain = staticSource:getCone()
	local airAbsorption = staticSource:getAirAbsorption()
	local minVolume, maxVolume = staticSource:getVolumeLimits()
	local referenceDistance, maxDistance = staticSource:getAttenuationDistances()
	assert(sourceX == 21 and sourceY == 22 and sourceZ == 23)
	assert(velocityX == 1 and velocityY == 2 and velocityZ == 3)
	assert(directionX == 0 and directionY == 0 and directionZ == -1)
	assert(math.abs(coneInner - math.pi / 2) < 0.00001
		and math.abs(coneOuter - math.pi * 3 / 2) < 0.00001
		and coneVolume == 0.25 and coneHighGain == 0.5)
	assert(airAbsorption == 1.5)
	assert(math.abs(minVolume - 0.01) < 0.00001 and math.abs(maxVolume - 0.7) < 0.00001)
	assert(not staticSource:isRelative() and referenceDistance == 2
		and maxDistance == 1000000 and staticSource:getRolloff() == 0.5)
	streamSource:setVolume(0.04)
	streamSource:setPitch(1.25)
	staticClone = staticSource:clone()
	assert(staticClone ~= staticSource and staticClone:getType() == "static")
	assert(staticClone:getChannelCount() == staticSource:getChannelCount())
	assert(staticClone:getVolume() == staticSource:getVolume() and staticClone:isLooping())
	local cloneX, cloneY, cloneZ = staticClone:getPosition()
	local cloneDirectionX, cloneDirectionY, cloneDirectionZ = staticClone:getDirection()
	local cloneConeInner, cloneConeOuter, cloneConeVolume, cloneConeHighGain = staticClone:getCone()
	local cloneAirAbsorption = staticClone:getAirAbsorption()
	local cloneMinVolume, cloneMaxVolume = staticClone:getVolumeLimits()
	local cloneReference, cloneMax = staticClone:getAttenuationDistances()
	assert(cloneX == 21 and cloneY == 22 and cloneZ == 23 and not staticClone:isRelative())
	assert(cloneDirectionX == 0 and cloneDirectionY == 0 and cloneDirectionZ == -1)
	assert(math.abs(cloneConeInner - coneInner) < 0.00001
		and math.abs(cloneConeOuter - coneOuter) < 0.00001
		and cloneConeVolume == 0.25 and cloneConeHighGain == 0.5)
	assert(cloneAirAbsorption == 1.5)
	assert(math.abs(cloneMinVolume - 0.01) < 0.00001
		and math.abs(cloneMaxVolume - 0.7) < 0.00001)
	assert(cloneReference == 2 and cloneMax == 1000000 and staticClone:getRolloff() == 0.5)
	assert(staticClone:tell() == 0 and not staticClone:isPlaying())
	assert(staticClone:getFilter().type == "lowpass" and #staticClone:getActiveEffects() == 2)
	assert(math.abs(staticSource:getDuration() - 0.4) < 0.0001)
	assert(staticSource:getDuration("samples") == 17640)
	staticClone:setVolume(0.03)
	assert(math.abs(staticSource:getVolume() - 0.08) < 0.0001)
	assert(love.audio.play(staticSource, streamSource, pcmSource, staticClone))
	staticSource:setPosition(2, 3, 4)
	staticSource:setVelocity(4, 5, 6)
	staticSource:setDirection(1, 0, 0)
	staticSource:setCone(0, math.pi, 0.4, 0.6)
	staticSource:setAirAbsorption(2.5)
	staticSource:setVolumeLimits(0.02, 0.6)
	staticSource:setRelative(true)
	staticSource:setAttenuationDistances(3, 900)
	staticSource:setRolloff(0.75)
	sourceX, sourceY, sourceZ = staticSource:getPosition()
	velocityX, velocityY, velocityZ = staticSource:getVelocity()
	directionX, directionY, directionZ = staticSource:getDirection()
	coneInner, coneOuter, coneVolume, coneHighGain = staticSource:getCone()
	airAbsorption = staticSource:getAirAbsorption()
	minVolume, maxVolume = staticSource:getVolumeLimits()
	referenceDistance, maxDistance = staticSource:getAttenuationDistances()
	assert(sourceX == 2 and sourceY == 3 and sourceZ == 4)
	assert(velocityX == 4 and velocityY == 5 and velocityZ == 6)
	assert(directionX == 1 and directionY == 0 and directionZ == 0)
	assert(coneInner == 0 and math.abs(coneOuter - math.pi) < 0.00001
		and math.abs(coneVolume - 0.4) < 0.00001 and math.abs(coneHighGain - 0.6) < 0.00001)
	assert(airAbsorption == 2.5)
	assert(math.abs(minVolume - 0.02) < 0.00001 and math.abs(maxVolume - 0.6) < 0.00001)
	assert(staticSource:isRelative() and referenceDistance == 3
		and maxDistance == 900 and staticSource:getRolloff() == 0.75)
	assert(love.audio.getActiveSourceCount() == 4 and love.audio.getSourceCount() == 4)
	print("LOVE_AUDIO_SOURCE_CHANNELS_PASS", staticSource:getChannelCount(),
		streamSource:getChannelCount(), pcmSource:getChannelCount(), staticClone:getChannelCount())
	print("LOVE_AUDIO_SOURCE_SPATIAL_PASS", sourceX, sourceY, sourceZ,
		velocityX, velocityY, velocityZ, referenceDistance, maxDistance, staticSource:getRolloff())
	print("LOVE_AUDIO_SOURCE_CONE_PASS", "direction=pass", "cone=pass",
		"air-absorption=pass", "clone=pass", "dynamic=pass", "volume-limits=pass")
	print("LOVE_SOUNDDATA_SOURCE_NODE_PASS", pcmSource:getType())
	print("LOVE_AUDIO_CLONE_DURATION_PASS", staticClone:getDuration(), staticClone:getDuration("samples"))
	print("LOVE_AUDIO_STARTED", staticSource:getType(), streamSource:getType())
end

function love.update()
	frames = frames + 1
	if frames == 3 then
		local paused = love.audio.pause()
		assert(#paused == 4)
		local found = {}
		for _, source in ipairs(paused) do found[source] = true end
		assert(found[staticSource] and found[streamSource] and found[pcmSource] and found[staticClone])
		assert(staticSource:isPaused() and streamSource:isPaused()
			and pcmSource:isPaused() and staticClone:isPaused())
		assert(love.audio.getActiveSourceCount() == 4)
		assert(#love.audio.pause() == 0)
		assert(love.audio.play(paused))
		assert(staticSource:isPlaying() and streamSource:isPlaying()
			and pcmSource:isPlaying() and staticClone:isPlaying())
		queueData = love.sound.newSoundData(800, 8000, 16, 2)
		queueData:setSample(0, 1, -1)
		queueData:setSample(0, 2, 1)
		queueData:setSample(799, 1, 1)
		queueData:setSample(799, 2, -1)
		queueSource = love.audio.newQueueableSource(8000, 16, 2, 2)
		queueSource:setVolume(0.01)
		assert(queueSource:getType() == "queue" and queueSource:getFreeBufferCount() == 2)
		assert(queueSource:queue(queueData) and queueSource:queue(queueData))
		assert(queueSource:getFreeBufferCount() == 0
			and queueSource:getDuration("samples") == 1600)
		queueClone = queueSource:clone()
		assert(queueClone:getType() == "queue" and queueClone:getFreeBufferCount() == 2
			and queueClone:getDuration("samples") == 0)
		monoQueueData = love.sound.newSoundData(400, 8000, 8, 1)
		monoQueueData:setSample(0, -1)
		monoQueueData:setSample(399, 1)
		monoQueueSource = love.audio.newQueueableSource(8000, 8, 1, 1)
		monoQueueSource:setVolume(0.01)
		assert(monoQueueSource:queue(monoQueueData)
			and monoQueueSource:getFreeBufferCount() == 0)
		assert(queueSource:play() and queueSource:isPlaying())
		assert(monoQueueSource:play() and monoQueueSource:isPlaying())
		print("LOVE_AUDIO_PAUSE_LIST_PASS", #paused)
	elseif frames == 6 then
		staticSource:seek(0.05, "seconds")
		assert(staticSource:tell("seconds") >= 0)
		assert(love.audio.setEffect("echo", {type = "echo", volume = 0.5,
			delay = 0.12, damping = 0.2, feedback = 0.45}))
		assert(staticSource:setFilter({type = "bandpass", volume = 0.85,
			lowgain = 0.4, highgain = 0.7}))
		assert(staticSource:setEffect("room", false))
		assert(staticSource:getFilter().type == "bandpass"
			and #staticSource:getActiveEffects() == 1)
		print("LOVE_AUDIO_EFFECTS_PASS", "direct=pass", "named=pass",
			"clone=pass", "dynamic=pass", "soloud-approx=pass")
		print("LOVE_AUDIO_SEEK_OK")
	elseif frames > 3 and not queueRefilled and queueSource:getFreeBufferCount() > 0
		and monoQueueSource:getFreeBufferCount() == 1 then
		assert(queueSource:isPlaying(), "queue Source underrun before dynamic refill")
		assert(queueSource:queue(queueData))
		queueRefilled = true
		print("LOVE_AUDIO_QUEUE_PASS", queueSource:getType(),
			queueSource:getFreeBufferCount(), queueSource:getDuration("samples"),
			"mono8", monoQueueSource:getFreeBufferCount())
	elseif frames >= 12 and queueRefilled then
		love.audio.stop()
		assert(not staticSource:isPlaying() and not streamSource:isPlaying()
			and not staticClone:isPlaying() and not queueSource:isPlaying()
			and not monoQueueSource:isPlaying())
		assert(queueSource:getFreeBufferCount() == 2 and queueSource:getDuration("samples") == 0)
		assert(monoQueueSource:getFreeBufferCount() == 1
			and monoQueueSource:getDuration("samples") == 0)
		assert(love.audio.getActiveSourceCount() == 0 and love.audio.getSourceCount() == 0)
		print("LOVE_AUDIO_ACTIVE_COUNT_PASS", love.audio.getActiveSourceCount())
		assert(love.event.quit())
	elseif frames >= 240 then
		error("queue Source did not release a consumed buffer within 240 frames")
	end
end

function love.quit()
	print("LOVE_AUDIO_RELEASE_OK")
	return false
end

function love.draw()
	love.graphics.clear(0.03, 0.06, 0.1, 1)
	love.graphics.setColor(0.2, 0.8, 1, 1)
	love.graphics.rectangle("fill", 20, 60, 380, 60)
end
