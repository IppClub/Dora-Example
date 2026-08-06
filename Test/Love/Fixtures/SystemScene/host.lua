local Dora = require("Dora")
local App <const> = Dora.App
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create system LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then return false end
		assert(not node.running, "system LoveNode did not quit within 300 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			("platform=%s system=pass clipboard=roundtrip power=pass url-policy=pass")
				:format(string.lower(App.platform))))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_SYSTEM_PASS", App.platform, frames)
		return true
	end)
end

return workflow
