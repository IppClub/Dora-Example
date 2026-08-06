local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local App <const> = Dora.App

local workflow = {}

function workflow.run(statusFile)
	local first = assert(LoveNode("first.lua"), "failed to create first mobile LoveNode")
	local second = assert(LoveNode("second.lua"), "failed to create second mobile LoveNode")
	Director.entry:addChild(first)
	Director.entry:addChild(second)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if frames == 4 then
			first:emit("ControllerAdded", 77, "Virtual Mobile Controller")
			second:emit("ControllerAdded", 77, "Virtual Mobile Controller")
			first:emit("KeyDown", "A")
			first:emit("ButtonDown", 77, "a")
			first:emit("Axis", 77, "leftx", 0.5)
		elseif frames == 6 then
			first:emit("KeyUp", "A")
			first:emit("ButtonUp", 77, "a")
			first:emit("Axis", 77, "leftx", 0)
		end

		if (first.running or second.running) and frames < 300 then return false end
		assert(not first.running and not second.running,
			"mobile LoveNodes did not finish within 300 host frames")
		assert(first.lastError == "", first.lastError)
		assert(second.lastError == "", second.lastError)
		local platform = string.lower(App.platform)
		local systemMix = App.platform == "iOS" and "pass" or "unsupported"
		local audio = App.platform == "Linux" and "not-tested" or "soloud"
		assert(Content:save(statusFile,
			("platform=%s graphics=pass pixels=pass audio=%s systemmix=%s system=pass multi=2 input=injected stats=pass content=pass")
				:format(platform, audio, systemMix)))
		first:removeFromParent(true)
		second:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_MOBILE_RUNTIME_PASS", frames)
		return true
	end)
end

return workflow
