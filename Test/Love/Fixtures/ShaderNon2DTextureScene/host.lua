local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create non-2D Shader LoveNode")
	Director.entry:addChild(node)
	local seenRunning = false
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		seenRunning = seenRunning or node.running
		if (not seenRunning or node.running) and frames < 300 then return false end
		local running = node.running
		local lastError = node.lastError
		node:removeFromParent(true)
		package.loaded.host = nil
		assert(seenRunning, "non-2D Shader LoveNode never entered running state")
		assert(not running, "non-2D Shader LoveNode did not finish within 300 host frames")
		assert(lastError == "", lastError)
		assert(Content:save(statusFile,
			"single=array+cube+volume arrays=array+cube+volume dynamic-index=pass type-guard=pass pixels=pass"))
		print("HOST_LOVE_SHADER_NON2D_PASS", frames)
		return true
	end)
end

return workflow
