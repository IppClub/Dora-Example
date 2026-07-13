-- [ts]: JoltScaleProfile.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local makeCapsuleBody3D = ____PhysicsBody3D.makeCapsuleBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Camera3D = ____Dora.Camera3D -- 6
local Content = ____Dora.Content -- 7
local Director = ____Dora.Director -- 8
local Node3D = ____Dora.Node3D -- 9
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 10
local Vec3 = ____Dora.Vec3 -- 11
local View = ____Dora.View -- 12
local sleep = ____Dora.sleep -- 13
local thread = ____Dora.thread -- 14
local outputDir = "/tmp/dora-3d-jolt-profile" -- 26
local resultPath = outputDir .. "/result.txt" -- 27
local phasePath = outputDir .. "/phase.txt" -- 28
local counts = {100, 250, 500} -- 29
local warmupFrames = 90 -- 30
local sampleFrames = 120 -- 31
local results = {} -- 32
local view = Director.entry -- 33
local function emit(message) -- 35
	print(message) -- 36
	results[#results + 1] = message -- 37
end -- 35
local function fail(reason) -- 40
	emit("JOLT_PROFILE_SUMMARY status=FAIL reason=" .. reason) -- 41
	Content:save( -- 42
		resultPath, -- 42
		table.concat(results, "\n") .. "\n" -- 42
	) -- 42
	App.devMode = false -- 43
	App:shutdown() -- 44
	error(reason) -- 45
end -- 40
local function percentile(values, p) -- 48
	__TS__ArraySort( -- 49
		values, -- 49
		function(____, a, b) return a - b end -- 49
	) -- 49
	return values[math.floor((#values - 1) * p) + 1] or 0 -- 50
end -- 48
local function waitFrames(count) -- 53
	do -- 53
		local index = 0 -- 54
		while index < count do -- 54
			sleep() -- 54
			index = index + 1 -- 54
		end -- 54
	end -- 54
end -- 53
local camera = Camera3D() -- 57
camera:lookAt( -- 58
	Vec3(22, 18, 28), -- 58
	Vec3(0, 4, 0) -- 58
) -- 58
Director:pushCamera(camera) -- 59
View.frustumCulling = false -- 60
view:setEnvironmentMap("") -- 61
view:setEnvironmentIntensity(0, 0, 1) -- 62
local world = PhysicsWorld3D() -- 64
view:addChild(world) -- 65
local floor = Node3D() -- 67
floor.position = Vec3(0, -0.5, 0) -- 68
view:addChild(floor) -- 69
makeBoxBody3D( -- 70
	world, -- 70
	floor, -- 70
	Vec3(30, 0.5, 30), -- 70
	PhysicsWorld3D.Static -- 70
) -- 70
local function runPhase(count, ____debug) -- 72
	local nodes = {} -- 73
	local bodies = {} -- 74
	local side = math.ceil(math.sqrt(count)) -- 75
	do -- 75
		local index = 0 -- 76
		while index < count do -- 76
			local node = Node3D() -- 77
			local column = index % side -- 78
			local row = math.floor(index / side) -- 79
			node.position = Vec3((column - (side - 1) * 0.5) * 1.15, 1.2 + index % 7 * 1.05, (row - (side - 1) * 0.5) * 1.15) -- 80
			view:addChild(node) -- 85
			local body -- 86
			repeat -- 86
				local ____switch12 = index % 3 -- 86
				local ____cond12 = ____switch12 == 1 -- 86
				if ____cond12 then -- 86
					body = makeSphereBody3D(world, node, 0.42) -- 89
					break -- 90
				end -- 90
				____cond12 = ____cond12 or ____switch12 == 2 -- 90
				if ____cond12 then -- 90
					body = makeCapsuleBody3D(world, node, 0.32, 0.3) -- 92
					break -- 93
				end -- 93
				do -- 93
					body = makeBoxBody3D( -- 95
						world, -- 95
						node, -- 95
						Vec3(0.4, 0.4, 0.4) -- 95
					) -- 95
					break -- 96
				end -- 96
			until true -- 96
			nodes[#nodes + 1] = node -- 98
			bodies[#bodies + 1] = body -- 99
			index = index + 1 -- 76
		end -- 76
	end -- 76
	world.showDebug = ____debug -- 102
	Content:save( -- 103
		phasePath, -- 103
		(tostring(count) .. ":") .. (____debug and "debug" or "plain") -- 103
	) -- 103
	waitFrames(warmupFrames) -- 104
	local frame = {} -- 106
	local collect = {} -- 107
	local submit = {} -- 108
	do -- 108
		local index = 0 -- 109
		while index < sampleFrames do -- 109
			sleep() -- 110
			local stats = view.stats -- 111
			frame[#frame + 1] = App.deltaTime * 1000 -- 112
			collect[#collect + 1] = stats.collectMicros -- 113
			submit[#submit + 1] = stats.submitMicros -- 114
			index = index + 1 -- 109
		end -- 109
	end -- 109
	local sample = { -- 117
		count = count, -- 118
		debug = ____debug, -- 119
		frameP50 = percentile(frame, 0.5), -- 120
		frameP95 = percentile(frame, 0.95), -- 121
		collectP95 = percentile(collect, 0.95), -- 122
		submitP95 = percentile(submit, 0.95) -- 123
	} -- 123
	emit(((((("JOLT_PROFILE count=" .. tostring(count)) .. " debug=") .. tostring(____debug)) .. " ") .. ((("frameP50Ms=" .. __TS__NumberToFixed(sample.frameP50, 3)) .. " frameP95Ms=") .. __TS__NumberToFixed(sample.frameP95, 3)) .. " ") .. (("collectP95Us=" .. tostring(sample.collectP95)) .. " submitP95Us=") .. tostring(sample.submitP95)) -- 125
	world.showDebug = false -- 131
	for ____, body in ipairs(bodies) do -- 132
		body:removeFromParent(true) -- 132
	end -- 132
	for ____, node in ipairs(nodes) do -- 133
		node:removeFromParent(true) -- 133
	end -- 133
	waitFrames(5) -- 134
	return sample -- 135
end -- 72
Content:remove(resultPath) -- 138
Content:remove(phasePath) -- 139
thread(function() -- 140
	for ____, count in ipairs(counts) do -- 141
		runPhase(count, false) -- 142
		runPhase(count, true) -- 143
	end -- 143
	Content:save(phasePath, "cleanup") -- 145
	waitFrames(5) -- 146
	local stats = view.stats -- 147
	if stats.modelInstanceCount ~= 0 or stats.visualCount ~= 0 then -- 147
		fail((("cleanup_registry_models_" .. tostring(stats.modelInstanceCount)) .. "_visuals_") .. tostring(stats.visualCount)) -- 149
	end -- 149
	emit("JOLT_PROFILE_SUMMARY status=PASS") -- 151
	Content:save( -- 152
		resultPath, -- 152
		table.concat(results, "\n") .. "\n" -- 152
	) -- 152
	App.devMode = false -- 153
	App:shutdown() -- 154
end) -- 140
return ____exports -- 140