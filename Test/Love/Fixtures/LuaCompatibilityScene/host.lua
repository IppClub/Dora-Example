local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create Lua compatibility LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then
			return false
		end
		assert(not node.running, "Lua compatibility LoveNode did not quit within 300 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "function=pass stack=pass isolation=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_LUA55_FENV_PASS", frames)
		return true
	end)
end

return workflow

