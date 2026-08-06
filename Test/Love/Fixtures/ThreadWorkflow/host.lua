local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

local function saveRoot()
	return Path(Content.writablePath, "Love", "love-thread-workflow")
end

local function read(path)
	return Content:load(Path(saveRoot(), path))
end

function workflow.run(statusFile)
	local root = saveRoot()
	if Content:exist(root) then assert(Content:remove(root)) end
	local node = assert(LoveNode("main.lua"), "failed to create Thread workflow LoveNode")
	Director.entry:addChild(node)
	local restarted = false
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		assert(node.lastError == "", node.lastError)
		local generation = tonumber(read("generation.txt") or "0") or 0
		if not restarted and generation == 1 and not node.running then
			assert(read("status.txt") == "thread=pass generation=1 source=content error=pass isolation=pass")
			assert(node:restart(), node.lastError)
			restarted = true
			return false
		end
		if restarted and generation == 2 and not node.running then
			assert(read("status.txt") == "thread=pass generation=2 source=content error=pass isolation=pass")
			assert(Content:save(statusFile,
				"thread=pass generations=2 source=content error=pass isolation=pass"))
			node:removeFromParent(true)
			assert(Content:remove(root))
			package.loaded.host = nil
			print("HOST_LOVE_THREAD_WORKFLOW_PASS", frames)
			return true
		end
		assert(frames < 900, "Thread workflow did not finish within 900 host frames")
		return false
	end)
end

return workflow
