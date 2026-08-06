local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create custom-attribute LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 900 then
			return false
		end
		assert(not node.running, "custom-attribute LoveNode did not quit within 900 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "draw-instanced=pass custom-attributes=pass layout-location=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_DRAW_INSTANCED_PASS", frames)
		return true
	end)
end

return workflow
