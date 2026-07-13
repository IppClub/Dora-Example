-- [ts]: JoltLifecycleRegression.ts
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBody3D = ____PhysicsBody3D.makeBody3D -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Constraint3D = ____Dora.Constraint3D -- 7
local Content = ____Dora.Content -- 9
local Director = ____Dora.Director -- 10
local Node3D = ____Dora.Node3D -- 11
local FixtureDef3D = ____Dora.FixtureDef3D -- 12
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 14
local Vec3 = ____Dora.Vec3 -- 15
local threadLoop = ____Dora.threadLoop -- 16
local output = "/tmp/dora-3d-jolt-lifecycle" -- 19
local resultPath = output .. "/result.txt" -- 20
local worldCycles = 1000 -- 21
local asyncCases = {{path = "Test/Model3D/Assets/Model/Duck.glb", hull = true}, {path = "Test/Model3D/Assets/Model/Duck.glb", hull = false}, {path = "Test/Model3D/Assets/Model/Fox.glb", hull = true}, {path = "Test/Model3D/Assets/Model/Fox.glb", hull = false}} -- 22
local asyncCycles = #asyncCases -- 28
local handlersPerCycle = 8 -- 29
local lifecycleCompleted = 0 -- 31
local asyncCompleted = 0 -- 32
local pendingHandlers = 0 -- 33
local pendingShape -- 34
local pendingFailed = false -- 35
local asyncReady = false -- 36
local finished = false -- 37
local function finish(status, reason) -- 39
	if reason == nil then -- 39
		reason = "none" -- 39
	end -- 39
	if finished then -- 39
		return -- 40
	end -- 40
	finished = true -- 41
	local summary = ((((("JOLT_LIFECYCLE_SUMMARY status=" .. status) .. " reason=") .. reason) .. " ") .. ((("worldCycles=" .. tostring(lifecycleCompleted)) .. "/") .. tostring(worldCycles)) .. " ") .. (((("asyncCycles=" .. tostring(asyncCompleted)) .. "/") .. tostring(asyncCycles)) .. " handlers=") .. tostring(handlersPerCycle) -- 42
	print(summary) -- 46
	Content:save(resultPath, summary .. "\n") -- 47
	App.devMode = false -- 48
	App:shutdown() -- 49
end -- 39
local function runWorldCycle() -- 52
	local world = PhysicsWorld3D() -- 53
	Director.entry:addChild(world) -- 54
	local firstNode = Node3D() -- 55
	local secondNode = Node3D() -- 56
	local characterNode = Node3D() -- 57
	Director.entry:addChild(firstNode) -- 58
	Director.entry:addChild(secondNode) -- 59
	Director.entry:addChild(characterNode) -- 60
	local first = makeBoxBody3D( -- 62
		world, -- 62
		firstNode, -- 62
		Vec3(0.2, 0.2, 0.2), -- 62
		PhysicsWorld3D.Static -- 62
	) -- 62
	local second = makeSphereBody3D(world, secondNode, 0.2) -- 63
	local constraint = Constraint3D:fixed( -- 64
		first, -- 64
		second, -- 64
		Vec3(0, 0, 0) -- 64
	) -- 64
	local character = world:createCharacter(characterNode, 0.45, 0.25) -- 65
	world:removeFromParent(true) -- 67
	local valid = first.world == nil and second.world == nil and constraint.world == nil and constraint.firstBody == nil and constraint.secondBody == nil and character.world == nil and character.node == nil -- 68
	first:removeFromParent(true) -- 75
	second:removeFromParent(true) -- 76
	characterNode:removeFromParent(true) -- 77
	if not valid then -- 77
		finish( -- 78
			"FAIL", -- 78
			"world_cleanup_" .. tostring(lifecycleCompleted) -- 78
		) -- 78
	else -- 78
		lifecycleCompleted = lifecycleCompleted + 1 -- 79
	end -- 79
end -- 52
local function startAsyncCycle() -- 82
	local testCase = asyncCases[asyncCompleted + 1] -- 83
	pendingHandlers = handlersPerCycle -- 84
	pendingShape = nil -- 85
	pendingFailed = false -- 86
	asyncReady = false -- 87
	local function handler(shape) -- 88
		if not shape.built then -- 88
			pendingFailed = true -- 89
		end -- 89
		if pendingShape == nil then -- 89
			pendingShape = shape -- 90
		elseif pendingShape ~= shape then -- 90
			pendingFailed = true -- 91
		end -- 91
		pendingHandlers = pendingHandlers - 1 -- 92
		if pendingHandlers == 0 then -- 92
			asyncReady = true -- 93
		end -- 93
	end -- 88
	do -- 88
		local i = 0 -- 95
		while i < handlersPerCycle do -- 95
			if testCase.hull then -- 95
				FixtureDef3D:loadConvexHullAsync(testCase.path, handler) -- 96
			else -- 96
				FixtureDef3D:loadMeshAsync(testCase.path, handler) -- 97
			end -- 97
			i = i + 1 -- 95
		end -- 95
	end -- 95
end -- 82
local function consumeAsyncCycle() -- 101
	asyncReady = false -- 102
	local shape = pendingShape -- 103
	if pendingFailed or shape == nil or not shape.built then -- 103
		finish( -- 105
			"FAIL", -- 105
			"async_load_" .. tostring(asyncCompleted) -- 105
		) -- 105
		return -- 106
	end -- 106
	local world = PhysicsWorld3D() -- 109
	Director.entry:addChild(world) -- 110
	local node = Node3D() -- 111
	Director.entry:addChild(node) -- 112
	local motion = asyncCases[asyncCompleted + 1].hull and PhysicsWorld3D.Dynamic or PhysicsWorld3D.Static -- 113
	local body = makeBody3D(world, node, shape, motion) -- 114
	if body == nil or body.world ~= world then -- 114
		finish( -- 116
			"FAIL", -- 116
			"async_body_" .. tostring(asyncCompleted) -- 116
		) -- 116
		return -- 117
	end -- 117
	world:removeFromParent(true) -- 119
	if body.world ~= nil then -- 119
		finish( -- 121
			"FAIL", -- 121
			"async_world_cleanup_" .. tostring(asyncCompleted) -- 121
		) -- 121
		return -- 122
	end -- 122
	body:removeFromParent(true) -- 124
	asyncCompleted = asyncCompleted + 1 -- 125
	if asyncCompleted < asyncCycles then -- 125
		startAsyncCycle() -- 126
	else -- 126
		finish("PASS") -- 127
	end -- 127
end -- 101
Content:remove(resultPath) -- 130
print("JOLT_LIFECYCLE_REGRESSION_READY") -- 131
threadLoop(function() -- 133
	if finished then -- 133
		return true -- 134
	end -- 134
	if lifecycleCompleted < worldCycles then -- 134
		do -- 134
			local i = 0 -- 136
			while i < 10 and lifecycleCompleted < worldCycles and not finished do -- 136
				runWorldCycle() -- 136
				i = i + 1 -- 136
			end -- 136
		end -- 136
		if lifecycleCompleted == worldCycles then -- 136
			startAsyncCycle() -- 137
		end -- 137
		return false -- 138
	end -- 138
	if asyncReady then -- 138
		consumeAsyncCycle() -- 140
	end -- 140
	return false -- 141
end) -- 133
return ____exports -- 133