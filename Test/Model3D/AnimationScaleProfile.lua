-- [ts]: AnimationScaleProfile.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Cache = ____Dora.Cache -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local Content = ____Dora.Content -- 7
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Director = ____Dora.Director -- 9
local Model3D = ____Dora.Model3D -- 10
local Vec3 = ____Dora.Vec3 -- 11
local View = ____Dora.View -- 12
local sleep = ____Dora.sleep -- 13
local thread = ____Dora.thread -- 14
local file = "Test/Model3D/Assets/Model/Fox.glb" -- 29
local outputDir = "/tmp/dora-3d-animation-profile" -- 30
local resultPath = outputDir .. "/result.txt" -- 31
local counts = {1, 10, 25, 50} -- 32
local warmupFrames = 30 -- 33
local sampleFrames = 120 -- 34
local results = {} -- 35
local view = Director.entry -- 36
local function emit(message) -- 38
	print(message) -- 39
	results[#results + 1] = message -- 40
end -- 38
local function fail(reason) -- 43
	emit("ANIMATION_PROFILE_SUMMARY status=FAIL reason=" .. reason) -- 44
	Content:save( -- 45
		resultPath, -- 45
		table.concat(results, "\n") .. "\n" -- 45
	) -- 45
	App.devMode = false -- 46
	App:shutdown() -- 47
	error(reason) -- 48
end -- 43
local function percentile(values, p) -- 51
	__TS__ArraySort( -- 52
		values, -- 52
		function(____, a, b) return a - b end -- 52
	) -- 52
	local index = math.floor((#values - 1) * p) -- 53
	return values[index + 1] or 0 -- 54
end -- 51
local function waitFrames(count) -- 57
	do -- 57
		local index = 0 -- 58
		while index < count do -- 58
			sleep() -- 58
			index = index + 1 -- 58
		end -- 58
	end -- 58
end -- 57
local camera = Camera3D() -- 61
Director:pushCamera(camera) -- 62
View.frustumCulling = false -- 63
view:setEnvironmentMap("") -- 64
view:setEnvironmentIntensity(0, 0, 1) -- 65
local light = DirectionalLight3D() -- 66
light.color = Color3(16777215) -- 67
light.intensity = 3 -- 68
light.angleX = -25 -- 69
light.angleY = 30 -- 70
view:addChild(light) -- 71
local function runPhase(count) -- 73
	if not Cache:load(file) then -- 73
		fail(tostring(count) .. "_load_failed") -- 74
	end -- 74
	local side = math.ceil(math.sqrt(count)) -- 75
	local spacing = 1.8 -- 76
	local models = {} -- 77
	do -- 77
		local index = 0 -- 78
		while index < count do -- 78
			local model = Model3D(file) -- 79
			if not model then -- 79
				fail(((tostring(count) .. "_instance_") .. tostring(index)) .. "_failed") -- 80
			end -- 80
			local x = (index % side - (side - 1) * 0.5) * spacing -- 81
			local y = (math.floor(index / side) - (side - 1) * 0.5) * spacing -- 82
			model.position = Vec3(x, y, 0) -- 83
			model.scale = Vec3(0.015, 0.015, 0.015) -- 84
			view:addChild(model) -- 85
			if model:play("Run", true) <= 0 then -- 85
				fail(((tostring(count) .. "_animation_") .. tostring(index)) .. "_failed") -- 86
			end -- 86
			models[#models + 1] = model -- 87
			index = index + 1 -- 78
		end -- 78
	end -- 78
	camera:lookAt( -- 89
		Vec3( -- 89
			0, -- 89
			0, -- 89
			math.max(12, side * 2.3) -- 89
		), -- 89
		Vec3(0, 0, 0) -- 89
	) -- 89
	waitFrames(warmupFrames) -- 90
	local before = view.stats -- 92
	if before.modelInstanceCount ~= count then -- 92
		fail((tostring(count) .. "_instance_count_") .. tostring(before.modelInstanceCount)) -- 94
	end -- 94
	if before.drawCalls < count then -- 94
		fail((tostring(count) .. "_draw_calls_") .. tostring(before.drawCalls)) -- 96
	end -- 96
	local frame = {} -- 98
	local collect = {} -- 99
	local sort = {} -- 100
	local submit = {} -- 101
	do -- 101
		local index = 0 -- 102
		while index < sampleFrames do -- 102
			sleep() -- 103
			local stats = view.stats -- 104
			frame[#frame + 1] = App.deltaTime * 1000 -- 105
			collect[#collect + 1] = stats.collectMicros -- 106
			sort[#sort + 1] = stats.sortMicros -- 107
			submit[#submit + 1] = stats.submitMicros -- 108
			index = index + 1 -- 102
		end -- 102
	end -- 102
	local sample = { -- 110
		count = count, -- 111
		frameP50 = percentile(frame, 0.5), -- 112
		frameP95 = percentile(frame, 0.95), -- 113
		collectP50 = percentile(collect, 0.5), -- 114
		collectP95 = percentile(collect, 0.95), -- 115
		sortP50 = percentile(sort, 0.5), -- 116
		sortP95 = percentile(sort, 0.95), -- 117
		submitP50 = percentile(submit, 0.5), -- 118
		submitP95 = percentile(submit, 0.95) -- 119
	} -- 119
	emit(((((("ANIMATION_PROFILE count=" .. tostring(count)) .. " ") .. ((("frameP50Ms=" .. __TS__NumberToFixed(sample.frameP50, 3)) .. " frameP95Ms=") .. __TS__NumberToFixed(sample.frameP95, 3)) .. " ") .. ((("collectP50Us=" .. tostring(sample.collectP50)) .. " collectP95Us=") .. tostring(sample.collectP95)) .. " ") .. ((("sortP50Us=" .. tostring(sample.sortP50)) .. " sortP95Us=") .. tostring(sample.sortP95)) .. " ") .. (("submitP50Us=" .. tostring(sample.submitP50)) .. " submitP95Us=") .. tostring(sample.submitP95)) -- 121
	for ____, model in ipairs(models) do -- 129
		model:removeFromParent(true) -- 129
	end -- 129
	waitFrames(3) -- 130
	if view.stats.modelInstanceCount ~= 0 then -- 130
		fail((tostring(count) .. "_cleanup_instances_") .. tostring(view.stats.modelInstanceCount)) -- 132
	end -- 132
	return sample -- 134
end -- 73
Content:remove(resultPath) -- 137
Cache:unload() -- 138
Cache.model3DBudget = 0 -- 139
thread(function() -- 141
	for ____, count in ipairs(counts) do -- 142
		runPhase(count) -- 142
	end -- 142
	Cache:unload(file) -- 143
	waitFrames(3) -- 144
	emit("ANIMATION_PROFILE_SUMMARY status=PASS") -- 145
	Content:save( -- 146
		resultPath, -- 146
		table.concat(results, "\n") .. "\n" -- 146
	) -- 146
	App.devMode = false -- 147
	App:shutdown() -- 148
end) -- 141
return ____exports -- 141