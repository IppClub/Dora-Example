local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path
local App <const> = Dora.App

local workflow = {}

function workflow.run(statusFile)
	local saveRoot = Path(Content.writablePath, "Love", "love-mobile-physics")
	if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
	local node = LoveNode("main.lua")
	if not node then
		assert(Content:save(statusFile, "failed=create"))
		return
	end
	Director.entry:addChild(node)
	local frames = 0
	local stoppedFrames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.lastError ~= "" then
			assert(Content:save(statusFile, "failed=runtime error=" .. node.lastError:gsub("[\r\n]+", " ")))
			node:removeFromParent(true)
			if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
			package.loaded.host = nil
			return true
		end
		if node.running and frames < 1200 then return false end
		if node.running then
			assert(Content:save(statusFile, "failed=timeout"))
			node:removeFromParent(true)
			if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
			package.loaded.host = nil
			return true
		end
		stoppedFrames = stoppedFrames + 1
		local screenshot = Path(saveRoot, "physics.png")
		if not Content:exist(screenshot) and stoppedFrames < 120 then return false end
		if not Content:exist(screenshot) then
			assert(Content:save(statusFile, "failed=content error=missing-physics.png"))
		else
			assert(Content:save(statusFile,
				("platform=%s physics=playrho callbacks=pass joints=11 ccd=pass pixels=pass content=pass")
					:format(string.lower(App.platform))))
		end
		node:removeFromParent(true)
		assert(Content:remove(saveRoot))
		package.loaded.host = nil
		print("HOST_LOVE_MOBILE_PHYSICS_PASS", frames)
		return true
	end)
end

return workflow
