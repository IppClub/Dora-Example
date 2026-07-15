-- [ts]: AutoManaged2DRegression.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Node = ____Dora.Node -- 1
local sleep = ____Dora.sleep -- 1
local thread = ____Dora.thread -- 1
local resultPath = "/tmp/dora-2d-auto-managed-result.txt" -- 3
local results = {} -- 4
local function emit(message) -- 6
	print(message) -- 7
	results[#results + 1] = message -- 8
end -- 6
local function finish(status, reason) -- 11
	if reason == nil then -- 11
		reason = "" -- 11
	end -- 11
	emit(("AUTO_MANAGED_2D_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 12
	Content:save( -- 13
		resultPath, -- 13
		table.concat(results, "\n") .. "\n" -- 13
	) -- 13
	App.devMode = false -- 14
	App:shutdown() -- 15
end -- 11
local function expect(condition, reason) -- 18
	if not condition then -- 18
		finish("FAIL", reason) -- 20
		error(reason) -- 21
	end -- 21
end -- 18
Content:remove(resultPath) -- 25
local automaticNode = Node() -- 27
automaticNode.tag = "automatic-2d-node" -- 28
local explicitRoot = Node() -- 30
explicitRoot.tag = "explicit-2d-root" -- 31
local explicitChild = Node() -- 32
explicitChild.tag = "explicit-2d-child" -- 33
explicitRoot:addChild(explicitChild) -- 34
local cleanedNode = Node() -- 36
cleanedNode:cleanup() -- 37
thread(function() -- 39
	sleep() -- 40
	expect(automaticNode.parent == Director.entry, "node_not_auto_attached") -- 41
	expect(explicitRoot.parent == Director.entry, "explicit_root_not_auto_attached") -- 42
	expect(explicitChild.parent == explicitRoot, "explicit_child_was_reparented") -- 43
	expect(cleanedNode.parent == nil, "cleaned_node_was_auto_attached") -- 44
	emit("AUTO_MANAGED_2D_RESULT node=PASS explicit=PASS cleanup=PASS") -- 46
	finish("PASS") -- 47
end) -- 39
return ____exports -- 39