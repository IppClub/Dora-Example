local Dora = require("Dora")
local App <const> = Dora.App
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}
local activeRoot
local target
local steady
local mainSentinel = {}
local mainClosure = function(value)
	return value + 1
end
package.loaded.__p6_love_hot_reload_sentinel = mainSentinel

local function childCount(node)
	return node.children and node.children.count or 0
end

local function steadySaveRoot()
	return Path(Content.writablePath, "Love", "p6-hot-reload-steady")
end

local function steadyLoads()
	local content = Content:load(Path(steadySaveRoot(), "loads.txt"))
	return tonumber(content or "0") or 0
end

local function assertIsolation()
	assert(package.loaded.__p6_love_hot_reload_sentinel == mainSentinel)
	assert(mainClosure(3) == 4)
	assert(rawget(_G, "love") == nil)
	assert(steady and steady.running and steady.lastError == "")
	assert(steadyLoads() == 1, "unrelated LoveNode was restarted")
end

local function writeStatus(status)
	assert(Content:save(Path(activeRoot, "status.txt"), status))
end

function workflow.start(root)
	activeRoot = root
	local saveRoot = steadySaveRoot()
	if Content:exist(saveRoot) then
		assert(Content:remove(saveRoot))
	end
	target = assert(LoveNode(Path(activeRoot, "main.lua")), "failed to create hot reload target")
	steady = assert(LoveNode("steady.lua"), "failed to create steady LoveNode")
	Director.entry:addChild(target)
	Director.entry:addChild(steady)
	assert(target.running and target.lastError == "")
	assert(target.texture ~= nil and childCount(target) == 1)
	assertIsolation()
	writeStatus("v1")
	print("HOST_LOVE_HOT_RELOAD_V1_PASS", childCount(target), steadyLoads())
end

function workflow.reloadV2()
	assert(target:restart(), target.lastError)
	assert(target.running and target.lastError == "")
	assert(target.texture ~= nil and childCount(target) == 0)
	assertIsolation()
	writeStatus("v2")
	print("HOST_LOVE_HOT_RELOAD_V2_PASS", childCount(target), steadyLoads())
end

function workflow.verifyRejectedBuild()
	assert(target.running and target.lastError == "")
	assert(target.texture ~= nil and childCount(target) == 0)
	assertIsolation()
	writeStatus("rejected")
	print("HOST_LOVE_HOT_RELOAD_REJECTED_BUILD_PASS")
end

function workflow.expectFailedRestart()
	assert(not target:restart(), "invalid generated Lua unexpectedly restarted")
	assert(not target.running)
	assert(target.texture == nil, "failed restart retained the previous render texture")
	assert(childCount(target) == 0, "failed restart retained Love-owned child nodes")
	assert(target.lastError:find("boot:", 1, true), target.lastError)
	assert(target.lastError:find("main.ts", 1, true), target.lastError)
	assertIsolation()
	writeStatus("failed")
	print("HOST_LOVE_HOT_RELOAD_FAILED_RESTART_PASS", target.lastError)
end

function workflow.recover()
	assert(target:restart(), target.lastError)
	assert(target.running and target.lastError == "")
	assert(target.texture ~= nil and childCount(target) == 0)
	assertIsolation()
	writeStatus("recovered")
	print("HOST_LOVE_HOT_RELOAD_RECOVERY_PASS")
end

function workflow.finish()
	target:removeFromParent(true)
	steady:removeFromParent(true)
	assert(Content:remove(steadySaveRoot()))
	assert(Content:remove(activeRoot))
	package.loaded.host = nil
	print("HOST_LOVE_HOT_RELOAD_PASS")
	App:shutdown()
end

return workflow
