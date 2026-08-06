local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create ArrayImage LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 180 then return false end
		assert(not node.running, "ArrayImage LoveNode did not quit within 180 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"draw_layer=pass quad_layer=pass explicit_layer=pass pixels=pass shader_maintex=pass replace_pixels=2d+array type_guard=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_ARRAY_IMAGE_LAYER_PASS", frames)
		return true
	end)
end

return workflow
