local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create wireframe LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 120 then return false end
		assert(not node.running, "wireframe LoveNode did not quit within 120 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"state=pass primitive=pass mesh=pass image=pass shader=pass points=unchanged pixels=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_WIREFRAME_PASS", frames)
		return true
	end)
end

return workflow
