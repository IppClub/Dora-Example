local Dora = require("Dora")
local App <const> = Dora.App
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local workflow = {}
local nodes = {}
local previousProfilerSending = Director.profilerSending

local function childCount(node)
	return node.children and node.children.count or 0
end

local function removeNodes()
	for _, node in ipairs(nodes) do node:removeFromParent(true) end
	nodes = {}
end

local function createBatch()
	for _ = 1, 5 do
		local node = assert(LoveNode("Workload/main.lua"), "failed to create audio soak LoveNode")
		Director.entry:addChild(node)
		nodes[#nodes + 1] = node
	end
end

function workflow.prepare()
	Director.profilerSending = true
end

function workflow.run(statusFile, durationSeconds)
	durationSeconds = math.max(1, tonumber(durationSeconds) or 1800)
	removeNodes()
	workflow.prepare()
	local started = App.runningTime
	local deadline = started + durationSeconds
	local cycles = 0
	local instances = 0
	local maxChildren = 0
	local cleanupFrames = nil
	createBatch()
	Director.systemScheduler:schedule(function()
		if cleanupFrames then
			cleanupFrames = cleanupFrames + 1
			if cleanupFrames < 120 then return false end
			assert(Content:save(statusFile, ("pass cycles=%d instances=%d maxChildren=%d elapsed=%.3f")
				:format(cycles, instances, maxChildren, App.runningTime - started)))
			return true
		end

		local allStopped = true
		for _, node in ipairs(nodes) do
			maxChildren = math.max(maxChildren, childCount(node))
			if node.running then allStopped = false end
		end
		if not allStopped then return false end

		for _, node in ipairs(nodes) do
			assert(node.lastError == "", node.lastError)
			assert(childCount(node) == 0, "stopped soak LoveNode retained audio children")
		end
		cycles = cycles + 1
		instances = instances + #nodes
		removeNodes()
		if App.runningTime >= deadline then
			cleanupFrames = 0
			return false
		end
		createBatch()
		return false
	end)
end

function workflow.finish()
	removeNodes()
	Director.profilerSending = previousProfilerSending
	package.loaded.host = nil
end

return workflow
