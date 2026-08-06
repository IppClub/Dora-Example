local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create SpriteBatch LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then return false end
		assert(not node.running, "SpriteBatch LoveNode did not quit within 300 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"sprite_2d=pass array_batch=pass add_layer=pass set_layer=pass attached_attribute=pass custom_shader=pass pixels=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_SPRITEBATCH_PASS", frames)
		return true
	end)
end

return workflow
