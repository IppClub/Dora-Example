local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node = assert(LoveNode("main.lua"), "failed to create keyboard LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if frames == 4 then
			node:emit("KeyDown", "A")
			node:emit("KeyRepeat", "A")
			node:emit("TextInput", "你")
			node:emit("TextEditing", "拼音", 1, 2)
			node:emit("KeyUp", "A")
		end
		if node.running and frames < 300 then return false end
		assert(not node.running, "keyboard LoveNode did not finish within 300 host frames")
		assert(node.lastError == "", node.lastError)
		assert(Content:save(statusFile,
			"methods=9 layout=a scan=a repeat=pass text=pass ime=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_KEYBOARD_PASS", frames)
		return true
	end)
end

return workflow
