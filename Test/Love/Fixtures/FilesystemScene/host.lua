local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

function workflow.run(statusFile)
	local saveRoot = Path(Content.writablePath, "Love", "dora-love-filesystem-scene")
	if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end

	local node = assert(LoveNode("boot.lua"), "failed to create filesystem LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then return false end
		assert(not node.running, "filesystem LoveNode did not finish within 300 host frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile, "executable-path=pass content=pass"))
		node:removeFromParent(true)
		if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
		package.loaded.host = nil
		print("HOST_LOVE_FILESYSTEM_QUERY_PASS", frames)
		return true
	end)
end

return workflow
