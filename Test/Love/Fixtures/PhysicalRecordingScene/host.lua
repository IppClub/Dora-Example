local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

function workflow.run(readyFile, statusFile)
	local saveRoot = Path(Content.writablePath, "Love", "love-physical-recording")
	if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
	local node = assert(LoveNode("boot.lua"), "failed to create physical recording LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	local ready = false
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and not ready and frames >= 10 then
			assert(Content:save(readyFile, "ready"))
			ready = true
		end
		if node.running and frames < 2100 then return false end

		local result = Content:load(Path(saveRoot, "result.txt"))
		if node.lastError ~= "" then
			result = "failed: " .. node.lastError
		elseif node.running then
			result = "failed: physical recording timed out"
		elseif not result or result == "" then
			result = "failed: recording scene produced no result"
		end
		assert(Content:save(statusFile, result))
		node:removeFromParent(true)
		if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
		package.loaded.host = nil
		print("HOST_LOVE_PHYSICAL_RECORDING_DONE", result, frames)
		return true
	end)
end

return workflow
