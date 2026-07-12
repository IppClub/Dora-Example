-- [ts]: JoltScaleProfile.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 5
local Content = ____Dora.Content -- 6
local Director = ____Dora.Director -- 7
local Node3D = ____Dora.Node3D -- 8
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 9
local Vec3 = ____Dora.Vec3 -- 10
local View = ____Dora.View -- 11
local sleep = ____Dora.sleep -- 12
local thread = ____Dora.thread -- 13
local outputDir = "/tmp/dora-3d-jolt-profile" -- 25
local resultPath = outputDir .. "/result.txt" -- 26
local phasePath = outputDir .. "/phase.txt" -- 27
local counts = {100, 250, 500} -- 28
local warmupFrames = 90 -- 29
local sampleFrames = 120 -- 30
local results = {} -- 31
local view = Director.entry -- 32
local function emit(message) -- 34
	print(message) -- 35
	results[#results + 1] = message -- 36
end -- 34
local function fail(reason) -- 39
	emit("JOLT_PROFILE_SUMMARY status=FAIL reason=" .. reason) -- 40
	Content:save( -- 41
		resultPath, -- 41
		table.concat(results, "\n") .. "\n" -- 41
	) -- 41
	App.devMode = false -- 42
	App:shutdown() -- 43
	error(reason) -- 44
end -- 39
local function percentile(values, p) -- 47
	__TS__ArraySort( -- 48
		values, -- 48
		function(____, a, b) return a - b end -- 48
	) -- 48
	return values[math.floor((#values - 1) * p) + 1] or 0 -- 49
end -- 47
local function waitFrames(count) -- 52
	do -- 52
		local index = 0 -- 53
		while index < count do -- 53
			sleep() -- 53
			index = index + 1 -- 53
		end -- 53
	end -- 53
end -- 52
local camera = Camera3D() -- 56
camera:lookAt( -- 57
	Vec3(22, 18, 28), -- 57
	Vec3(0, 4, 0) -- 57
) -- 57
Director:pushCamera(camera) -- 58
View.frustumCulling = false -- 59
view:setEnvironmentMap("") -- 60
view:setEnvironmentIntensity(0, 0, 1) -- 61
local world = PhysicsWorld3D() -- 63
view:addChild(world) -- 64
local floor = Node3D() -- 66
floor.position = Vec3(0, -0.5, 0) -- 67
view:addChild(floor) -- 68
world:createBox( -- 69
	floor, -- 69
	Vec3(30, 0.5, 30), -- 69
	PhysicsWorld3D.Static -- 69
) -- 69
local function runPhase(count, ____debug) -- 71
	local nodes = {} -- 72
	local bodies = {} -- 73
	local side = math.ceil(math.sqrt(count)) -- 74
	do -- 74
		local index = 0 -- 75
		while index < count do -- 75
			local node = Node3D() -- 76
			local column = index % side -- 77
			local row = math.floor(index / side) -- 78
			node.position = Vec3((column - (side - 1) * 0.5) * 1.15, 1.2 + index % 7 * 1.05, (row - (side - 1) * 0.5) * 1.15) -- 79
			view:addChild(node) -- 84
			local body -- 85
			repeat -- 85
				local ____switch12 = index % 3 -- 85
				local ____cond12 = ____switch12 == 1 -- 85
				if ____cond12 then -- 85
					body = world:createSphere(node, 0.42) -- 88
					break -- 89
				end -- 89
				____cond12 = ____cond12 or ____switch12 == 2 -- 89
				if ____cond12 then -- 89
					body = world:createCapsule(node, 0.32, 0.3) -- 91
					break -- 92
				end -- 92
				do -- 92
					body = world:createBox( -- 94
						node, -- 94
						Vec3(0.4, 0.4, 0.4) -- 94
					) -- 94
					break -- 95
				end -- 95
			until true -- 95
			nodes[#nodes + 1] = node -- 97
			bodies[#bodies + 1] = body -- 98
			index = index + 1 -- 75
		end -- 75
	end -- 75
	world.showDebug = ____debug -- 101
	Content:save( -- 102
		phasePath, -- 102
		(tostring(count) .. ":") .. (____debug and "debug" or "plain") -- 102
	) -- 102
	waitFrames(warmupFrames) -- 103
	local frame = {} -- 105
	local collect = {} -- 106
	local submit = {} -- 107
	do -- 107
		local index = 0 -- 108
		while index < sampleFrames do -- 108
			sleep() -- 109
			local stats = view.stats -- 110
			frame[#frame + 1] = App.deltaTime * 1000 -- 111
			collect[#collect + 1] = stats.collectMicros -- 112
			submit[#submit + 1] = stats.submitMicros -- 113
			index = index + 1 -- 108
		end -- 108
	end -- 108
	local sample = { -- 116
		count = count, -- 117
		debug = ____debug, -- 118
		frameP50 = percentile(frame, 0.5), -- 119
		frameP95 = percentile(frame, 0.95), -- 120
		collectP95 = percentile(collect, 0.95), -- 121
		submitP95 = percentile(submit, 0.95) -- 122
	} -- 122
	emit(((((("JOLT_PROFILE count=" .. tostring(count)) .. " debug=") .. tostring(____debug)) .. " ") .. ((("frameP50Ms=" .. __TS__NumberToFixed(sample.frameP50, 3)) .. " frameP95Ms=") .. __TS__NumberToFixed(sample.frameP95, 3)) .. " ") .. (("collectP95Us=" .. tostring(sample.collectP95)) .. " submitP95Us=") .. tostring(sample.submitP95)) -- 124
	world.showDebug = false -- 130
	for ____, body in ipairs(bodies) do -- 131
		body:destroy() -- 131
	end -- 131
	for ____, node in ipairs(nodes) do -- 132
		node:removeFromParent(true) -- 132
	end -- 132
	waitFrames(5) -- 133
	return sample -- 134
end -- 71
Content:remove(resultPath) -- 137
Content:remove(phasePath) -- 138
thread(function() -- 139
	for ____, count in ipairs(counts) do -- 140
		runPhase(count, false) -- 141
		runPhase(count, true) -- 142
	end -- 142
	Content:save(phasePath, "cleanup") -- 144
	waitFrames(5) -- 145
	local stats = view.stats -- 146
	if stats.modelInstanceCount ~= 0 or stats.visualCount ~= 0 then -- 146
		fail((("cleanup_registry_models_" .. tostring(stats.modelInstanceCount)) .. "_visuals_") .. tostring(stats.visualCount)) -- 148
	end -- 148
	emit("JOLT_PROFILE_SUMMARY status=PASS") -- 150
	Content:save( -- 151
		resultPath, -- 151
		table.concat(results, "\n") .. "\n" -- 151
	) -- 151
	App.devMode = false -- 152
	App:shutdown() -- 153
end) -- 139
return ____exports -- 139