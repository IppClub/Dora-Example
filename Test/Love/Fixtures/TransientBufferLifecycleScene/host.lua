local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile, cycles, frameBudget)
	local current
	local cycle = 0
	local frames = 0
	local cooldown = 0
	Director.systemScheduler:schedule(function()
		if not current then
			if cooldown > 0 then
				cooldown = cooldown - 1
				return false
			end
			cycle = cycle + 1
			if cycle > cycles then
				assert(Content:save(statusFile,
					("cycles=%d frames=%d points=840"):format(cycles, frameBudget)))
				package.loaded.host = nil
				return true
			end
			current = assert(LoveNode("main.lua"), "failed to create transient-buffer LoveNode")
			Director.entry:addChild(current)
			frames = 0
			return false
		end

		frames = frames + 1
		if not current.running then
			assert(Content:save(statusFile, "error=" .. current.lastError))
			current:removeFromParent(true)
			package.loaded.host = nil
			return true
		end
		if frames < frameBudget then return false end
		current:removeFromParent(true)
		current = nil
		cooldown = 6
		return false
	end)
end

return workflow
