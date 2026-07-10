-- [ts]: SpecialMaterialAsyncRegression.ts
local ____lualib = require("lualib_bundle") -- 1
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
local thread = ____Dora.thread -- 12
local threadLoop = ____Dora.threadLoop -- 13
local cases = {{name = "anisotropy-packed", file = "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb", scale = 1.2, camera = { -- 23
	0, -- 28
	0.35, -- 28
	3.6, -- 28
	0, -- 28
	0.1, -- 28
	0 -- 28
}}, {name = "thickness-sheen-packed", file = "Test/Model3D/Assets/Model/SheenVolume/SheenVolume.gltf", scale = 25, camera = { -- 28
	0, -- 34
	0.35, -- 34
	3.4, -- 34
	0, -- 34
	0.2, -- 34
	0 -- 34
}}} -- 34
local outputDir = "/tmp/dora-3d-special-async" -- 38
local resultPath = outputDir .. "/result.txt" -- 39
local view = Director.entry -- 40
local camera = Camera3D() -- 41
Director:pushCamera(camera) -- 42
view:setEnvironmentMap("") -- 43
view:setEnvironmentIntensity(0, 0, 1.1) -- 44
local light = DirectionalLight3D() -- 45
light.color = Color3(16773596) -- 46
light.intensity = 4 -- 47
light.angleX = -20 -- 48
light.angleY = 25 -- 49
view:addChild(light) -- 50
local frame = 0 -- 52
local caseIndex = -1 -- 53
local state = "warmup" -- 54
local stateFrames = 0 -- 55
local loadStart = 0 -- 56
local maxDeltaMs = 0 -- 57
local maxDeltaFrame = 0 -- 58
local screenshotPath = "" -- 59
local model -- 60
local results = {} -- 61
local function emit(message) -- 63
	print(message) -- 64
	results[#results + 1] = message -- 65
end -- 63
local function finish(status, reason) -- 68
	if reason == nil then -- 68
		reason = "" -- 68
	end -- 68
	state = "done" -- 69
	emit(("SPECIAL_ASYNC_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 70
	Content:save( -- 71
		resultPath, -- 71
		table.concat(results, "\n") .. "\n" -- 71
	) -- 71
	App.devMode = false -- 72
	App:shutdown() -- 73
end -- 68
local function startNextCase() -- 76
	if model then -- 76
		model:removeFromParent(true) -- 78
		model = nil -- 79
	end -- 79
	caseIndex = caseIndex + 1 -- 81
	if caseIndex >= #cases then -- 81
		finish("PASS") -- 83
		return -- 84
	end -- 84
	local item = cases[caseIndex + 1] -- 86
	Cache:unload(item.file) -- 87
	local ex, ey, ez, tx, ty, tz = table.unpack(item.camera, 1, 6) -- 88
	camera:lookAt( -- 89
		Vec3(ex, ey, ez), -- 89
		Vec3(tx, ty, tz) -- 89
	) -- 89
	maxDeltaMs = 0 -- 90
	maxDeltaFrame = 0 -- 91
	loadStart = App.runningTime -- 92
	state = "loading" -- 93
	emit("SPECIAL_ASYNC_BEGIN case=" .. item.name) -- 94
	thread(function() -- 95
		if not Cache:loadAsync(item.file) then -- 95
			finish("FAIL", item.name .. "_load_failed") -- 97
			return -- 98
		end -- 98
		model = Model3D(item.file) -- 100
		if not model then -- 100
			finish("FAIL", item.name .. "_instantiate_failed") -- 102
			return -- 103
		end -- 103
		model.scale = Vec3(item.scale, item.scale, item.scale) -- 105
		view:addChild(model) -- 106
		state = "measure" -- 107
		stateFrames = 120 -- 108
		emit((("SPECIAL_ASYNC_READY case=" .. item.name) .. " total=") .. __TS__NumberToFixed(App.runningTime - loadStart, 3)) -- 109
	end) -- 95
end -- 76
Content:remove(resultPath) -- 115
threadLoop(function() -- 117
	frame = frame + 1 -- 118
	if state == "done" then -- 118
		return true -- 119
	end -- 119
	if state == "warmup" then -- 119
		stateFrames = stateFrames + 1 -- 121
		if stateFrames >= 60 then -- 121
			startNextCase() -- 122
		end -- 122
		return false -- 123
	end -- 123
	if state == "loading" or state == "measure" then -- 123
		local deltaMs = App.deltaTime * 1000 -- 126
		if deltaMs > maxDeltaMs then -- 126
			maxDeltaMs = deltaMs -- 128
			maxDeltaFrame = frame -- 129
		end -- 129
	end -- 129
	if state == "measure" then -- 129
		stateFrames = stateFrames - 1 -- 133
		if stateFrames <= 0 then -- 133
			local item = cases[caseIndex + 1] -- 135
			emit((((("SPECIAL_ASYNC_FRAME case=" .. item.name) .. " maxDeltaMs=") .. __TS__NumberToFixed(maxDeltaMs, 1)) .. " frame=") .. tostring(maxDeltaFrame)) -- 136
			if maxDeltaMs > 250 then -- 136
				finish("FAIL", item.name .. "_frame_budget_exceeded") -- 140
				return true -- 141
			end -- 141
			local prefix = caseIndex == 0 and "01" or "02" -- 143
			screenshotPath = App:saveScreenshot((((outputDir .. "/") .. prefix) .. "-") .. item.name) -- 144
			state = "screenshot" -- 145
			stateFrames = 0 -- 146
		end -- 146
	end -- 146
	if state == "screenshot" then -- 146
		stateFrames = stateFrames + 1 -- 150
		if Content:exist(screenshotPath) then -- 150
			emit((("SPECIAL_ASYNC_SCREENSHOT case=" .. cases[caseIndex + 1].name) .. " path=") .. screenshotPath) -- 152
			state = "warmup" -- 153
			stateFrames = 0 -- 154
		elseif stateFrames > 180 then -- 154
			finish("FAIL", cases[caseIndex + 1].name .. "_screenshot_timeout") -- 156
			return true -- 157
		end -- 157
	end -- 157
	return false -- 160
end) -- 117
return ____exports -- 117