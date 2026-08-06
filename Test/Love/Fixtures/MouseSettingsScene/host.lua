local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Mouse <const> = Dora.Mouse

local workflow = {}

function workflow.run(statusFile)
	Content:remove(Content.writablePath .. "/Love/love-mouse-settings/restart-marker.txt")
	local node = assert(LoveNode("main.lua"), "failed to create MouseSettings LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	local sawRelative = false
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running then
			sawRelative = sawRelative or Mouse.relativeMode
			if frames < 180 then return false end
		end
		assert(not node.running, "MouseSettings LoveNode did not quit within 180 frames")
		assert(node.lastError == "", node.lastError)
		assert(sawRelative, "Love focused relative-mode request never reached Dora/SDL")
		assert(not Mouse.relativeMode, "Love mouse relative mode was not restored after exit")
		assert(Content:save(statusFile,
			"position=pass visibility=pass grab=pass relative=pass cursor=pass restart=pass reset=pass"))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_MOUSE_SETTINGS_PASS", frames)
		return true
	end)
end

return workflow
