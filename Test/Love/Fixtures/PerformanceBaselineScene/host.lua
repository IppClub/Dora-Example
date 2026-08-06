local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}
local nodes = {}
local previousProfilerSending = Director.profilerSending

local function removeNodes()
	for _, node in ipairs(nodes) do
		node:removeFromParent(true)
	end
	nodes = {}
end

function workflow.setCount(count, statusFile)
	assert(count == 0 or count == 1 or count == 2, "unsupported performance node count")
	removeNodes()
	for _ = 1, count do
		local node = assert(LoveNode("main.lua"), "failed to create performance LoveNode")
		Director.entry:addChild(node)
		nodes[#nodes + 1] = node
	end
	Director.profilerSending = true
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if frames < 3 then return false end
		for _, node in ipairs(nodes) do
			assert(node.running, "performance LoveNode stopped unexpectedly")
			assert(node.lastError == "", node.lastError)
		end
		assert(Content:save(statusFile, ("count=%d"):format(count)))
		return true
	end)
end

function workflow.cleanup(statusFile)
	removeNodes()
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if frames < 90 then return false end
		assert(Content:save(statusFile, "cleanup=pass"))
		return true
	end)
end

function workflow.finish(statusFile)
	Director.profilerSending = previousProfilerSending
	package.loaded.host = nil
	Director.systemScheduler:schedule(function()
		assert(Content:save(statusFile, "finish=pass"))
		return true
	end)
end

return workflow
