local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local first = assert(LoveNode("first.lua"), "failed to create first graphics stats LoveNode")
	local second = assert(LoveNode("second.lua"), "failed to create second graphics stats LoveNode")
	Director.entry:addChild(first)
	Director.entry:addChild(second)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if (first.running or second.running) and frames < 120 then
			return false
		end
		assert(not first.running and not second.running,
			"graphics stats LoveNodes did not quit within 120 frames")
		assert(first.lastError == "", first.lastError)
		assert(second.lastError == "", second.lastError)
		assert(Content:save(statusFile,
			"instances=2 counters=pass spritepair=1draw+1batched resources=isolated texturememory=pass target=pass"))
		first:removeFromParent(true)
		second:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_GRAPHICS_STATS_PASS", frames)
		return true
	end)
end

return workflow
