local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

local function saveRoot(identity)
	return Path(Content.writablePath, "Love", identity)
end

local function readNumber(identity, file)
	return tonumber(Content:load(Path(saveRoot(identity), file)) or "0") or 0
end

local function childCount(node)
	return node.children and node.children.count or 0
end

function workflow.run(statusFile)
	for _, identity in ipairs({"love-event-restart-target", "love-event-restart-steady"}) do
		local root = saveRoot(identity)
		if Content:exist(root) then assert(Content:remove(root)) end
	end

	local target = assert(LoveNode("Target/main.lua"), "failed to create restart target")
	local steady = assert(LoveNode("Steady/main.lua"), "failed to create steady LoveNode")
	Director.entry:addChild(target)
	Director.entry:addChild(steady)
	local sawSecondGeneration = false
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		local generation = readNumber("love-event-restart-target", "generation.txt")
		if generation == 2 and target.running then
			sawSecondGeneration = true
			assert(target.lastError == "", target.lastError)
			local targetChildren = childCount(target)
			assert(targetChildren == 0, "restart retained the first generation AudioSource child: " .. targetChildren)
			assert(steady.running and steady.lastError == "", steady.lastError)
			assert(readNumber("love-event-restart-steady", "loads.txt") == 1,
				"restart affected the unrelated LoveNode")
		end
		if target.running and frames < 900 then return false end
		assert(not target.running, "restart target did not finish within 900 host frames")
		assert(target.lastError == "", target.lastError)
		assert(sawSecondGeneration, "host never observed the restarted generation")
		assert(generation == 2, "restart did not create exactly two generations")
		assert(steady.running and readNumber("love-event-restart-steady", "loads.txt") == 1)
		assert(Content:save(statusFile, "restart=pass generations=2 isolation=pass resources=pass"))
		target:removeFromParent(true)
		steady:removeFromParent(true)
		for _, identity in ipairs({"love-event-restart-target", "love-event-restart-steady"}) do
			local root = saveRoot(identity)
			if Content:exist(root) then assert(Content:remove(root)) end
		end
		package.loaded.host = nil
		print("HOST_LOVE_EVENT_RESTART_PASS", frames)
		return true
	end)
end

return workflow
