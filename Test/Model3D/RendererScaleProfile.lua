-- [ts]: RendererScaleProfile.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayPush = ____lualib.__TS__ArrayPush -- 1
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
local file = "Test/Model3D/Assets/Model/Duck.glb" -- 31
local outputDir = "/tmp/dora-3d-renderer-profile" -- 32
local resultPath = outputDir .. "/result.txt" -- 33
local counts = {100, 250, 500} -- 34
local warmupFrames = 20 -- 35
local sampleFrames = 90 -- 36
local results = {} -- 37
local samples = {} -- 38
local view = Director.entry -- 39
local function emit(message) -- 41
	print(message) -- 42
	results[#results + 1] = message -- 43
end -- 41
local function fail(reason) -- 46
	emit("RENDERER_PROFILE_SUMMARY status=FAIL reason=" .. reason) -- 47
	Content:save( -- 48
		resultPath, -- 48
		table.concat(results, "\n") .. "\n" -- 48
	) -- 48
	App.devMode = false -- 49
	App:shutdown() -- 50
	error(reason) -- 51
end -- 46
local function percentile(values, p) -- 54
	__TS__ArraySort( -- 55
		values, -- 55
		function(____, a, b) return a - b end -- 55
	) -- 55
	local index = math.floor((#values - 1) * p) -- 56
	return values[index + 1] or 0 -- 57
end -- 54
local function waitFrames(count) -- 60
	do -- 60
		local index = 0 -- 61
		while index < count do -- 61
			sleep() -- 61
			index = index + 1 -- 61
		end -- 61
	end -- 61
end -- 60
local camera = Camera3D() -- 64
Director:pushCamera(camera) -- 65
camera:lookAt( -- 66
	Vec3(0, 0, 68), -- 66
	Vec3(0, 0, 0) -- 66
) -- 66
View.frustumCulling = false -- 67
view:setEnvironmentMap("") -- 68
view:setEnvironmentIntensity(0, 0, 1) -- 69
local light = DirectionalLight3D() -- 70
light.color = Color3(16777215) -- 71
light.intensity = 3 -- 72
light.angleX = -25 -- 73
light.angleY = 30 -- 74
view:addChild(light) -- 75
local function runPhase(mode, count) -- 77
	Cache:unload(file) -- 78
	waitFrames(2) -- 79
	local ____temp_0 -- 80
	if mode == "static" then -- 80
		____temp_0 = Cache:load(file) -- 80
	else -- 80
		____temp_0 = Cache:loadAsync(file) -- 80
	end -- 80
	local loaded = ____temp_0 -- 80
	if not loaded then -- 80
		fail(((mode .. "_") .. tostring(count)) .. "_load_failed") -- 81
	end -- 81
	local side = math.ceil(math.sqrt(count)) -- 83
	local spacing = 1.45 -- 84
	local models = {} -- 85
	do -- 85
		local index = 0 -- 86
		while index < count do -- 86
			local model = Model3D(file) -- 87
			if not model then -- 87
				fail(((((mode .. "_") .. tostring(count)) .. "_instance_") .. tostring(index)) .. "_failed") -- 88
			end -- 88
			local x = (index % side - (side - 1) * 0.5) * spacing -- 89
			local y = (math.floor(index / side) - (side - 1) * 0.5) * spacing -- 90
			model.position = Vec3(x, y, 0) -- 91
			model.scale = Vec3(0.55, 0.55, 0.55) -- 92
			view:addChild(model) -- 93
			models[#models + 1] = model -- 94
			index = index + 1 -- 86
		end -- 86
	end -- 86
	waitFrames(warmupFrames) -- 96
	local before = view.stats -- 98
	if mode == "static" and (before.staticMeshCount == 0 or before.dynamicMeshCount ~= 0) then -- 98
		fail((("static_buffer_identity_" .. tostring(before.staticMeshCount)) .. "_") .. tostring(before.dynamicMeshCount)) -- 100
	end -- 100
	if mode == "dynamic" and (before.dynamicMeshCount == 0 or before.staticMeshCount ~= 0) then -- 100
		fail((("dynamic_buffer_identity_" .. tostring(before.staticMeshCount)) .. "_") .. tostring(before.dynamicMeshCount)) -- 103
	end -- 103
	if before.drawCalls < count then -- 103
		fail((((mode .. "_") .. tostring(count)) .. "_draw_calls_") .. tostring(before.drawCalls)) -- 105
	end -- 105
	local frame = {} -- 107
	local collect = {} -- 108
	local sort = {} -- 109
	local submit = {} -- 110
	do -- 110
		local index = 0 -- 111
		while index < sampleFrames do -- 111
			sleep() -- 112
			local stats = view.stats -- 113
			frame[#frame + 1] = App.deltaTime * 1000 -- 114
			collect[#collect + 1] = stats.collectMicros -- 115
			sort[#sort + 1] = stats.sortMicros -- 116
			submit[#submit + 1] = stats.submitMicros -- 117
			index = index + 1 -- 111
		end -- 111
	end -- 111
	local sample = { -- 119
		mode = mode, -- 120
		count = count, -- 121
		frameP50 = percentile(frame, 0.5), -- 122
		frameP95 = percentile(frame, 0.95), -- 123
		collectP50 = percentile(collect, 0.5), -- 124
		collectP95 = percentile(collect, 0.95), -- 125
		sortP50 = percentile(sort, 0.5), -- 126
		sortP95 = percentile(sort, 0.95), -- 127
		submitP50 = percentile(submit, 0.5), -- 128
		submitP95 = percentile(submit, 0.95) -- 129
	} -- 129
	emit(((((((("RENDERER_PROFILE mode=" .. mode) .. " count=") .. tostring(count)) .. " ") .. ((("frameP50Ms=" .. __TS__NumberToFixed(sample.frameP50, 3)) .. " frameP95Ms=") .. __TS__NumberToFixed(sample.frameP95, 3)) .. " ") .. ((("collectP50Us=" .. tostring(sample.collectP50)) .. " collectP95Us=") .. tostring(sample.collectP95)) .. " ") .. ((("sortP50Us=" .. tostring(sample.sortP50)) .. " sortP95Us=") .. tostring(sample.sortP95)) .. " ") .. (("submitP50Us=" .. tostring(sample.submitP50)) .. " submitP95Us=") .. tostring(sample.submitP95)) -- 131
	for ____, model in ipairs(models) do -- 139
		model:removeFromParent(true) -- 139
	end -- 139
	waitFrames(2) -- 140
	Cache:unload(file) -- 141
	waitFrames(2) -- 142
	return sample -- 143
end -- 77
Content:remove(resultPath) -- 146
Cache:unload() -- 147
Cache.model3DBudget = 0 -- 148
thread(function() -- 150
	for ____, count in ipairs(counts) do -- 151
		local staticSample = runPhase("static", count) -- 152
		local dynamicSample = runPhase("dynamic", count) -- 153
		__TS__ArrayPush(samples, staticSample, dynamicSample) -- 154
		local submitRatio = staticSample.submitP95 > 0 and dynamicSample.submitP95 / staticSample.submitP95 or 0 -- 155
		local frameRatio = staticSample.frameP95 > 0 and dynamicSample.frameP95 / staticSample.frameP95 or 0 -- 158
		emit((((("RENDERER_COMPARE count=" .. tostring(count)) .. " dynamicToStaticSubmitP95=") .. __TS__NumberToFixed(submitRatio, 3)) .. " ") .. "dynamicToStaticFrameP95=" .. __TS__NumberToFixed(frameRatio, 3)) -- 161
	end -- 161
	emit("RENDERER_PROFILE_SUMMARY status=PASS") -- 166
	Content:save( -- 167
		resultPath, -- 167
		table.concat(results, "\n") .. "\n" -- 167
	) -- 167
	App.devMode = false -- 168
	App:shutdown() -- 169
end) -- 150
return ____exports -- 150