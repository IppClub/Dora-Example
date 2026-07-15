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
					body = makeSphereBody3D(world, node, 0.42) -- 88
					break -- 89
				end -- 89
				____cond12 = ____cond12 or ____switch12 == 2 -- 89
				if ____cond12 then -- 89
					body = makeCapsuleBody3D(world, node, 0.32, 0.3) -- 91
					break -- 92
				end -- 92
				do -- 92
					body = makeBoxBody3D( -- 94
						world, -- 94
						node, -- 94
						Vec3(0.4, 0.4, 0.4) -- 94
					) -- 94
					break -- 95
				end -- 95
			until true -- 95
			bodies[#bodies + 1] = body -- 97
			index = index + 1 -- 75
		end -- 75
	end -- 75
	world.showDebug = ____debug -- 100
	Content:save( -- 101
		phasePath, -- 101
		(tostring(count) .. ":") .. (____debug and "debug" or "plain") -- 101
	) -- 101
	waitFrames(warmupFrames) -- 102
	local frame = {} -- 104
	local collect = {} -- 105
	local submit = {} -- 106
	do -- 106
		local index = 0 -- 107
		while index < sampleFrames do -- 107
			sleep() -- 108
			local stats = view.stats -- 109
			frame[#frame + 1] = App.deltaTime * 1000 -- 110
			collect[#collect + 1] = stats.collectMicros -- 111
			submit[#submit + 1] = stats.submitMicros -- 112
			index = index + 1 -- 107
		end -- 107
	end -- 107
	local sample = { -- 115
		count = count, -- 116
		debug = ____debug, -- 117
		frameP50 = percentile(frame, 0.5), -- 118
		frameP95 = percentile(frame, 0.95), -- 119
		collectP95 = percentile(collect, 0.95), -- 120
		submitP95 = percentile(submit, 0.95) -- 121
	} -- 121
	emit(((((("JOLT_PROFILE count=" .. tostring(count)) .. " debug=") .. tostring(____debug)) .. " ") .. ((("frameP50Ms=" .. __TS__NumberToFixed(sample.frameP50, 3)) .. " frameP95Ms=") .. __TS__NumberToFixed(sample.frameP95, 3)) .. " ") .. (("collectP95Us=" .. tostring(sample.collectP95)) .. " submitP95Us=") .. tostring(sample.submitP95)) -- 123
	world.showDebug = false -- 129
	for ____, body in ipairs(bodies) do -- 130
		body:removeFromParent(true) -- 130
	end -- 130
	waitFrames(5) -- 131
	return sample -- 132
end -- 72
Content:remove(resultPath) -- 135
Content:remove(phasePath) -- 136
thread(function() -- 137
	for ____, count in ipairs(counts) do -- 138
		runPhase(count, false) -- 139
		runPhase(count, true) -- 140
	end -- 140
	Content:save(phasePath, "cleanup") -- 142
	waitFrames(5) -- 143
	local stats = view.stats -- 144
	if stats.modelInstanceCount ~= 0 or stats.visualCount ~= 0 then -- 144
		fail((("cleanup_registry_models_" .. tostring(stats.modelInstanceCount)) .. "_visuals_") .. tostring(stats.visualCount)) -- 146
	end -- 146
	emit("JOLT_PROFILE_SUMMARY status=PASS") -- 148
	Content:save( -- 149
		resultPath, -- 149
		table.concat(results, "\n") .. "\n" -- 149
	) -- 149
	App.devMode = false -- 150
	App:shutdown() -- 151
end) -- 137
return ____exports -- 137