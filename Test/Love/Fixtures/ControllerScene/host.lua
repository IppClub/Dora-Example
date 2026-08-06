local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}

function workflow.run(statusFile)
	local node
	local warmupFrames = 0
	local frames = 0
	Director.systemScheduler:schedule(function()
		-- The preceding workflow reports its status from a scheduler callback and
		-- may still be finishing LoveNode cleanup when the next HTTP command is
		-- accepted. Defer construction so the old input owner has completed that
		-- callback before this controller-only instance chooses focus.
		if not node then
			warmupFrames = warmupFrames + 1
			if warmupFrames < 3 then return false end
			node = LoveNode("boot-first.lua")
			if not node then
				assert(Content:save(statusFile,
					"failed: controller fixture requires DORA_VIRTUAL_CONTROLLER=1 on the Debug Dora process"))
				package.loaded.host = nil
				return true
			end
			Director.entry:addChild(node)
			return false
		end
		frames = frames + 1
		if frames == 4 then
			node:emit("JoystickButtonDown", 0, 0)
			node:emit("ButtonDown", 0, "a")
		elseif frames == 5 then
			node:emit("JoystickAxis", 0, 0, 0.5)
		elseif frames == 6 then
			node:emit("JoystickButtonUp", 0, 0)
			node:emit("ButtonUp", 0, "a")
		end
		if node.running and frames < 300 then return false end
		local running = node.running
		local lastError = node.lastError
		node:removeFromParent(true)
		package.loaded.host = nil
		assert(not running, "controller LoveNode did not finish within 300 host frames")
		assert(lastError == "", lastError)
		assert(Content:save(statusFile, "device=pass raw-query=pass raw-callback=pass mapping=pass vibration=query routing=pass"))
		print("HOST_LOVE_JOYSTICK_WORKFLOW_PASS", frames)
		return true
	end)
end

return workflow
