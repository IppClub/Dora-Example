local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create ImageFont LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 180 then return false end
		assert(not node.running, "ImageFont LoveNode did not quit within 180 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"imagefont=pass pixels=pass metrics=pass dpi=pass fallback=pass shader_vertex_id=pass batched_mesh=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_IMAGE_FONT_PASS", frames)
		return true
	end)
end

return workflow
