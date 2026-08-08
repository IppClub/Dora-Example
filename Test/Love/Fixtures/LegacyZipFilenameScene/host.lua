local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(packagePath, statusFile)
	local node = assert(LoveNode(packagePath), "failed to create legacy ZIP filename LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then
			return false
		end
		assert(not node.running, "legacy ZIP filename LoveNode did not quit within 300 frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "non-utf8-tolerance=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_NON_UTF8_ZIP_FILENAME_PASS", frames)
		return true
	end)
end

return workflow
