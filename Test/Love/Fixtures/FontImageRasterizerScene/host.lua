local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

function workflow.run(statusFile)
	local saveRoot = Path(Content.writablePath, "Love", "love-font-image-rasterizer")
	if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end

	local node = assert(LoveNode("Love/main.lua"), "failed to create font LoveNode")
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 300 then return false end
		assert(not node.running, "font LoveNode did not finish within 300 host frames")
		assert(node.lastError == "", node.lastError)
		local result = Content:load(Path(saveRoot, "status.txt"))
		assert(result == "font=pass image=2 truetype=pass bmfont=pass retention=pass data=pass", result or "missing font status")
		assert(Content:save(statusFile, result))
		node:removeFromParent(true)
		if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
		package.loaded.host = nil
		print("HOST_LOVE_FONT_IMAGE_RASTERIZER_PASS", frames)
		return true
	end)
end

return workflow
