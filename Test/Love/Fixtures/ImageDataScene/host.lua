local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create ImageData LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 120 then
			return false
		end
		assert(not node.running, "ImageData LoveNode did not quit within 120 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "png=pass tga=pass content=pass gpu=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_IMAGEDATA_PASS", frames)
		return true
	end)
end

return workflow
