local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create Shader interpolation LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 120 then return false end
		assert(not node.running, "Shader interpolation LoveNode did not quit within 120 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"flat=pass smooth=pass noperspective=compile centroid=compile combined=pass interface-block=pass matrices=pass arrays=pass block-arrays=pass nested-structs=pass multi-declarators=pass integer-varyings=pass inline-structs=pass diagnostics=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_SHADER_INTERPOLATION_PASS", frames)
		return true
	end)
end

return workflow
