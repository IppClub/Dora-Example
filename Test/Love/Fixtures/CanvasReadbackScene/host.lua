local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create Canvas readback LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 180 then
			return false
		end
		assert(not node.running, "Canvas readback LoveNode did not quit within 180 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"rgba8-msaa=pass crop=pass native-formats=pass draw-rejection=pass layered-mips=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_CANVAS_READBACK_PASS", frames)
		return true
	end)
end

return workflow
