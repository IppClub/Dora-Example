local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create Shader diagnostics LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 120 then return false end
		assert(not node.running, "Shader diagnostics LoveNode did not quit within 120 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "line-map=pass warnings=pass state=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_SHADER_DIAGNOSTICS_PASS", frames)
		return true
	end)
end

return workflow
