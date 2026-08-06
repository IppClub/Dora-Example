local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

function workflow.run(statusFile)
	local saveRoot = Path(Content.writablePath, "Love", "love-async-lifecycle-target")
	local destroyRoot = Path(Content.writablePath, "Love", "love-async-lifecycle-destroy")
	if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
	if Content:exist(destroyRoot) then assert(Content:remove(destroyRoot)) end

	local target = assert(LoveNode("Target/main.lua"), "failed to create async lifecycle LoveNode")
	local destroyTarget = assert(LoveNode("Destroy/main.lua"),
		"failed to create async destroy LoveNode")
	Director.entry:addChild(target)
	Director.entry:addChild(destroyTarget)
	local frames = 0
	local destroyedAt
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if not destroyedAt and Content:exist(Path(destroyRoot, "queued.txt")) then
			destroyTarget:removeFromParent(true)
			destroyTarget = nil
			destroyedAt = frames
		end
		local destroyWindowPassed = destroyedAt and frames - destroyedAt >= 180
		if (target.running or not destroyWindowPassed) and frames < 1200 then return false end
		assert(not target.running, "async lifecycle target did not finish within 1200 host frames")
		assert(destroyedAt, "destroy target never queued its screenshot")
		assert(destroyWindowPassed, "destroy target did not complete the late-callback wait window")
		assert(target.lastError == "", target.lastError)
		assert(Content:load(Path(saveRoot, "generation.txt")) == "2",
			"async lifecycle workflow did not create exactly two generations")
		assert(not Content:exist(Path(saveRoot, "old-callback.txt")),
			"first-generation callback escaped its generation")
		assert(not Content:exist(Path(saveRoot, "old.png")),
			"first-generation filename screenshot escaped its generation")
		local current = assert(Content:load(Path(saveRoot, "current-callback.txt")),
			"second-generation callback result is missing")
		assert(current:match("^96x64:%d+$"), "unexpected current screenshot result: " .. current)
		assert(Content:exist(Path(saveRoot, "current.png")),
			"second-generation filename screenshot is missing")
		assert(not Content:exist(Path(destroyRoot, "destroyed-callback.txt")),
			"destroyed LoveNode received a late screenshot callback")
		assert(not Content:exist(Path(destroyRoot, "destroyed.png")),
			"destroyed LoveNode completed a late filename screenshot")
		assert(Content:save(statusFile,
			"generation=pass destroy=pass stale-callback=dropped stale-file=dropped current=pass cleanup=pass"))
		target:removeFromParent(true)
		if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
		if Content:exist(destroyRoot) then assert(Content:remove(destroyRoot)) end
		package.loaded.host = nil
		print("HOST_LOVE_ASYNC_LIFECYCLE_PASS", frames)
		return true
	end)
end

return workflow
