local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(readyFile, statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create Android IME LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	local ready = false
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and not ready and frames >= 15 then
			assert(Content:save(readyFile, "ready"))
			ready = true
		end
		if node.running and frames < 900 then return false end

		local result
		if node.lastError ~= "" then
			result = "failed: " .. node.lastError
		elseif node.running then
			result = "failed: Android IME timed out"
		else
			result = "platform=android default=true ime=explicit key=single text=a closed=true content=pass"
		end
		assert(Content:save(statusFile, result))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_ANDROID_IME_DONE", result, frames)
		return true
	end)
end

return workflow
