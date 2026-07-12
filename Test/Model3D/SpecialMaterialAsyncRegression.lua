-- [ts]: SpecialMaterialAsyncRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local __TS__ArrayFilter = ____lualib.__TS__ArrayFilter -- 1
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
local cases = {{name = "anisotropy-packed", file = "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb", scale = 1.2, camera = { -- 33
	0, -- 38
	0.35, -- 38
	3.6, -- 38
	0, -- 38
	0.1, -- 38
	0 -- 38
}}, {name = "thickness-sheen-packed", file = "Test/Model3D/Assets/Model/SheenVolume/SheenVolume.gltf", scale = 25, camera = { -- 38
	0, -- 44
	0.35, -- 44
	3.4, -- 44
	0, -- 44
	0.2, -- 44
	0 -- 44
}}} -- 44
local outputDir = "/tmp/dora-3d-special-async" -- 48
local resultPath = outputDir .. "/result.txt" -- 49
local view = Director.entry -- 50
local camera = Camera3D() -- 51
Director:pushCamera(camera) -- 52
view:setEnvironmentMap("") -- 53
view:setEnvironmentIntensity(0, 0, 1.1) -- 54
local light = DirectionalLight3D() -- 55
light.color = Color3(16773596) -- 56
light.intensity = 4 -- 57
light.angleX = -20 -- 58
light.angleY = 25 -- 59
view:addChild(light) -- 60
local frame = 0 -- 62
local caseIndex = -1 -- 63
local state = "warmup" -- 64
local stateFrames = 0 -- 65
local loadStart = 0 -- 66
local maxDeltaMs = 0 -- 67
local maxDeltaFrame = 0 -- 68
local maxDeltaState = "" -- 69
local maxDeltaUploadCommands = 0 -- 70
local maxDeltaUploadBytes = 0 -- 71
local maxDeltaUploadMaxUs = 0 -- 72
local previousUploadCommands = 0 -- 73
local previousUploadBytes = 0 -- 74
local previousUploadUs = 0 -- 75
local frameSamples = {} -- 76
local screenshotPath = "" -- 77
local model -- 78
local results = {} -- 79
local function emit(message) -- 81
	print(message) -- 82
	results[#results + 1] = message -- 83
end -- 81
local function finish(status, reason) -- 86
	if reason == nil then -- 86
		reason = "" -- 86
	end -- 86
	state = "done" -- 87
	emit(("SPECIAL_ASYNC_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 88
	Content:save( -- 89
		resultPath, -- 89
		table.concat(results, "\n") .. "\n" -- 89
	) -- 89
	App.devMode = false -- 90
	App:shutdown() -- 91
end -- 86
local function startNextCase() -- 94
	if model then -- 94
		model:removeFromParent(true) -- 96
		model = nil -- 97
	end -- 97
	caseIndex = caseIndex + 1 -- 99
	if caseIndex >= #cases then -- 99
		finish("PASS") -- 101
		return -- 102
	end -- 102
	local item = cases[caseIndex + 1] -- 104
	Cache:unload(item.file) -- 105
	local ex, ey, ez, tx, ty, tz = table.unpack(item.camera, 1, 6) -- 106
	camera:lookAt( -- 107
		Vec3(ex, ey, ez), -- 107
		Vec3(tx, ty, tz) -- 107
	) -- 107
	maxDeltaMs = 0 -- 108
	maxDeltaFrame = 0 -- 109
	maxDeltaState = "" -- 110
	maxDeltaUploadCommands = 0 -- 111
	maxDeltaUploadBytes = 0 -- 112
	maxDeltaUploadMaxUs = 0 -- 113
	local stats = view.stats -- 114
	previousUploadCommands = stats.uploadCommands -- 115
	previousUploadBytes = stats.uploadBytes -- 116
	previousUploadUs = stats.uploadMicros -- 117
	frameSamples = {} -- 118
	loadStart = App.runningTime -- 119
	state = "loading" -- 120
	emit("SPECIAL_ASYNC_BEGIN case=" .. item.name) -- 121
	thread(function() -- 122
		if not Cache:loadAsync(item.file) then -- 122
			finish("FAIL", item.name .. "_load_failed") -- 124
			return -- 125
		end -- 125
		model = Model3D(item.file) -- 127
		if not model then -- 127
			finish("FAIL", item.name .. "_instantiate_failed") -- 129
			return -- 130
		end -- 130
		model.scale = Vec3(item.scale, item.scale, item.scale) -- 132
		view:addChild(model) -- 133
		state = "measure" -- 134
		stateFrames = 120 -- 135
		emit((("SPECIAL_ASYNC_READY case=" .. item.name) .. " total=") .. __TS__NumberToFixed(App.runningTime - loadStart, 3)) -- 136
	end) -- 122
end -- 94
Content:remove(resultPath) -- 142
threadLoop(function() -- 144
	frame = frame + 1 -- 145
	if state == "done" then -- 145
		return true -- 146
	end -- 146
	if state == "warmup" then -- 146
		stateFrames = stateFrames + 1 -- 148
		if stateFrames >= 60 then -- 148
			startNextCase() -- 149
		end -- 149
		return false -- 150
	end -- 150
	if state == "loading" or state == "measure" then -- 150
		local deltaMs = App.deltaTime * 1000 -- 153
		local stats = view.stats -- 154
		local sample = { -- 155
			frame = frame, -- 156
			state = state, -- 157
			deltaMs = deltaMs, -- 158
			uploadCommands = stats.uploadCommands - previousUploadCommands, -- 159
			uploadBytes = stats.uploadBytes - previousUploadBytes, -- 160
			uploadUs = stats.uploadMicros - previousUploadUs, -- 161
			uploadMaxUs = stats.uploadMaxCommandMicros -- 162
		} -- 162
		previousUploadCommands = stats.uploadCommands -- 164
		previousUploadBytes = stats.uploadBytes -- 165
		previousUploadUs = stats.uploadMicros -- 166
		frameSamples[#frameSamples + 1] = sample -- 167
		if deltaMs > maxDeltaMs then -- 167
			maxDeltaMs = deltaMs -- 169
			maxDeltaFrame = frame -- 170
			maxDeltaState = state -- 171
			maxDeltaUploadCommands = stats.uploadCommands -- 172
			maxDeltaUploadBytes = stats.uploadBytes -- 173
			maxDeltaUploadMaxUs = stats.uploadMaxCommandMicros -- 174
		end -- 174
	end -- 174
	if state == "measure" then -- 174
		stateFrames = stateFrames - 1 -- 178
		if stateFrames <= 0 then -- 178
			local item = cases[caseIndex + 1] -- 180
			local slowest = __TS__ArraySlice( -- 181
				__TS__ArraySort( -- 181
					__TS__ArraySlice(frameSamples), -- 181
					function(____, a, b) return b.deltaMs - a.deltaMs end -- 183
				), -- 183
				0, -- 184
				5 -- 184
			) -- 184
			for ____, sample in ipairs(slowest) do -- 185
				emit(((((((("SPECIAL_ASYNC_SAMPLE case=" .. item.name) .. " frame=") .. tostring(sample.frame)) .. " state=") .. sample.state) .. " ") .. ((("deltaMs=" .. __TS__NumberToFixed(sample.deltaMs, 1)) .. " uploadCommands=") .. tostring(sample.uploadCommands)) .. " ") .. (((("uploadBytes=" .. tostring(sample.uploadBytes)) .. " uploadUs=") .. tostring(sample.uploadUs)) .. " uploadMaxUs=") .. tostring(sample.uploadMaxUs)) -- 186
			end -- 186
			local largestUploads = __TS__ArraySlice( -- 192
				__TS__ArraySort( -- 192
					__TS__ArrayFilter( -- 192
						frameSamples, -- 192
						function(____, sample) return sample.uploadCommands > 0 end -- 193
					), -- 193
					function(____, a, b) return b.uploadBytes - a.uploadBytes end -- 194
				), -- 194
				0, -- 195
				5 -- 195
			) -- 195
			for ____, sample in ipairs(largestUploads) do -- 196
				emit(((((((("SPECIAL_ASYNC_UPLOAD case=" .. item.name) .. " frame=") .. tostring(sample.frame)) .. " state=") .. sample.state) .. " ") .. ((("deltaMs=" .. __TS__NumberToFixed(sample.deltaMs, 1)) .. " uploadCommands=") .. tostring(sample.uploadCommands)) .. " ") .. (((("uploadBytes=" .. tostring(sample.uploadBytes)) .. " uploadUs=") .. tostring(sample.uploadUs)) .. " uploadMaxUs=") .. tostring(sample.uploadMaxUs)) -- 197
			end -- 197
			emit(((((("SPECIAL_ASYNC_FRAME case=" .. item.name) .. " maxDeltaMs=") .. __TS__NumberToFixed(maxDeltaMs, 1)) .. " ") .. ((((("frame=" .. tostring(maxDeltaFrame)) .. " state=") .. maxDeltaState) .. " uploadCommands=") .. tostring(maxDeltaUploadCommands)) .. " ") .. (("uploadBytes=" .. tostring(maxDeltaUploadBytes)) .. " uploadMaxUs=") .. tostring(maxDeltaUploadMaxUs)) -- 203
			if maxDeltaMs > 250 then -- 203
				finish("FAIL", item.name .. "_frame_budget_exceeded") -- 209
				return true -- 210
			end -- 210
			local prefix = caseIndex == 0 and "01" or "02" -- 212
			screenshotPath = App:saveScreenshot((((outputDir .. "/") .. prefix) .. "-") .. item.name) -- 213
			state = "screenshot" -- 214
			stateFrames = 0 -- 215
		end -- 215
	end -- 215
	if state == "screenshot" then -- 215
		stateFrames = stateFrames + 1 -- 219
		if Content:exist(screenshotPath) then -- 219
			emit((("SPECIAL_ASYNC_SCREENSHOT case=" .. cases[caseIndex + 1].name) .. " path=") .. screenshotPath) -- 221
			state = "warmup" -- 222
			stateFrames = 0 -- 223
		elseif stateFrames > 180 then -- 223
			finish("FAIL", cases[caseIndex + 1].name .. "_screenshot_timeout") -- 225
			return true -- 226
		end -- 226
	end -- 226
	return false -- 229
end) -- 144
return ____exports -- 144