local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local AudioSource <const> = Dora.AudioSource

local workflow = {}

function workflow.run(statusFile)
	local hostSource = assert(AudioSource("tone.wav", false), "failed to create host Dora AudioSource")
	hostSource.looping = true
	hostSource.volume = 0.01
	Director.entry:addChild(hostSource)
	assert(hostSource:play(), "failed to start host Dora AudioSource")
	assert(hostSource.playing, "host Dora AudioSource was not playing before LoveNode startup")
	local node = assert(LoveNode("main.lua"), "failed to create audio LoveNode")
	local reader = assert(LoveNode("SpatialReader/main.lua"), "failed to create spatial reader LoveNode")
	local firstEffect = assert(LoveNode("EffectFirst/main.lua"), "failed to create first effect LoveNode")
	local secondEffect = assert(LoveNode("EffectSecond/main.lua"), "failed to create second effect LoveNode")
	Director.entry:addChild(node)
	Director.entry:addChild(reader)
	Director.entry:addChild(firstEffect)
	Director.entry:addChild(secondEffect)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if (node.running or reader.running or firstEffect.running or secondEffect.running) and frames < 900 then
			return false
		end
		assert(not node.running, "audio LoveNode did not quit within 900 frames")
		assert(not reader.running, "spatial reader LoveNode did not quit within 900 frames")
		assert(not firstEffect.running, "first effect LoveNode did not quit within 900 frames")
		assert(not secondEffect.running, "second effect LoveNode did not quit within 900 frames")
		assert(node.lastError == "", node.lastError)
		assert(reader.lastError == "", reader.lastError)
		assert(firstEffect.lastError == "", firstEffect.lastError)
		assert(secondEffect.lastError == "", secondEffect.lastError)
		assert(hostSource.playing,
			"LoveNode stop/cleanup unexpectedly stopped the host Dora AudioSource")
		node:removeFromParent(true)
		reader:removeFromParent(true)
		firstEffect:removeFromParent(true)
		secondEffect:removeFromParent(true)
		assert(hostSource.playing,
			"LoveNode removal unexpectedly stopped the host Dora AudioSource")
		hostSource:stop()
		assert(not hostSource.playing, "host Dora AudioSource did not stop independently")
		hostSource:removeFromParent(true)
		assert(Content:save(statusFile, "pause-list=pass source-table=pass active-count=pass channels=pass aliases=pass spatial-shared=pass doppler-shared=pass distance-model-shared=pass source-spatial=pass source-cone=pass source-hf=pass volume-limits=pass queue=pass effects=pass effect-isolation=pass dora-coexist=pass soloud=pass"))
		package.loaded.host = nil
		print("HOST_LOVE_AUDIO_PASS", frames)
		return true
	end)
end

return workflow
