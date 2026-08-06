local Dora = require("Dora")
local App <const> = Dora.App
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode

local node = assert(LoveNode("love-ts-runtime.lua"),
	"failed to create LoveNode from generated TypeScript")
Director.entry:addChild(node)

local failures = {
	{"fault-ts.lua", "fault-ts.ts:4:", "LOVE_TS_SOURCE_MAP_FAILURE", "HOST_LOVE_TS_SOURCE_MAP_PASS"},
	{"fault-teal.lua", "fault-teal.tl:4:", "LOVE_TEAL_SOURCE_MAP_FAILURE", "HOST_LOVE_TEAL_SOURCE_MAP_PASS"},
	{"fault-yue.lua", "fault-yue.yue:4:", "LOVE_YUE_SOURCE_MAP_FAILURE", "HOST_LOVE_YUE_SOURCE_MAP_PASS"},
}
local failureIndex = 0

Director.systemScheduler:schedule(function()
	if node.running then
		return false
	end
	if failureIndex == 0 then
		assert(node.lastError == "", node.lastError)
		print("HOST_LOVE_TS_RUNTIME_PASS")
	else
		local case = failures[failureIndex]
		assert(node.lastError:find(case[2], 1, true), node.lastError)
		assert(node.lastError:find(case[3], 1, true), node.lastError)
		print(case[4])
	end
	node:removeFromParent()
	failureIndex = failureIndex + 1
	local case = failures[failureIndex]
	if case then
		node = assert(LoveNode(case[1]), "failed to create mapped LoveNode " .. case[1])
		Director.entry:addChild(node)
		return false
	end
	App:shutdown()
	return true
end)
