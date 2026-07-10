-- [ts]: P0Regression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Cache = ____Dora.Cache -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Content = ____Dora.Content -- 6
local Director = ____Dora.Director -- 7
local Model3D = ____Dora.Model3D -- 8
local Object = ____Dora.Object -- 9
local Vec3 = ____Dora.Vec3 -- 11
local View = ____Dora.View -- 12
local View3D = ____Dora.View3D -- 13
local threadLoop = ____Dora.threadLoop -- 14
local outputDir = "/tmp/dora-3d-p0" -- 22
local resultPath = outputDir .. "/result.txt" -- 23
local stressStartPath = outputDir .. "/stress-start" -- 24
local stressEndPath = outputDir .. "/stress-end" -- 25
local studioEnv = "Test/Model3D/Assets/Env/studio.png" -- 26
local warmEnv = "Test/Model3D/Assets/Env/warm.png" -- 27
local cases = { -- 28
	{name = "duck", screenshot = "01-duck"}, -- 29
	{name = "damaged-helmet", screenshot = "02-damaged-helmet"}, -- 30
	{name = "specular", screenshot = "03-specular"}, -- 31
	{name = "fox-animation", screenshot = "04-fox-animation"}, -- 32
	{name = "alpha-mask-blend", screenshot = "05-alpha-mask-blend"}, -- 33
	{name = "dual-view", screenshot = "06-dual-view"}, -- 34
	{name = "frustum-culling", screenshot = "07-frustum-culling"} -- 35
} -- 35
local mainView = Director.entry -- 37
local camera = Camera3D() -- 38
Director:pushCamera(camera) -- 39
local activeModels = {} -- 41
local auxiliaryViews = {} -- 42
local fox -- 43
local primaryStatsView = mainView -- 44
local secondaryStatsView -- 45
local caseIndex = 0 -- 46
local frameCount = 0 -- 47
local screenshotPath = "" -- 48
local screenshotWait = 0 -- 49
local phase = "setup" -- 50
local stressCycle = 0 -- 51
local stressBaseline -- 52
local stressPeakInstances = 0 -- 53
local stressPeakNodes = 0 -- 54
local stressPeakVisuals = 0 -- 55
local stressBaselineObjects = 0 -- 56
local stressBaselineLuaKB = 0 -- 57
local failures = {} -- 58
local reportLines = {} -- 59
local function emit(line) -- 61
	print(line) -- 62
	reportLines[#reportLines + 1] = line -- 63
end -- 61
local function fail(message) -- 66
	failures[#failures + 1] = message -- 67
	emit("P0_FAIL " .. message) -- 68
end -- 66
local function loadModel(view, file, scale, position, angleY) -- 71
	if position == nil then -- 71
		position = Vec3(0, 0, 0) -- 75
	end -- 75
	if angleY == nil then -- 75
		angleY = 0 -- 76
	end -- 76
	local model = Model3D(file) -- 78
	view:addChild(model) -- 79
	model.scale = Vec3(scale, scale, scale) -- 80
	model.position = position -- 81
	model.angleY = angleY -- 82
	activeModels[#activeModels + 1] = model -- 83
	return model -- 84
end -- 71
local function setCamera(eye, target) -- 87
	camera:lookAt(eye, target) -- 88
end -- 87
local function cleanupCase() -- 91
	mainView.scene:removeAllChildren(true) -- 92
	for ____, view in ipairs(auxiliaryViews) do -- 93
		view:removeFromParent(true) -- 94
	end -- 94
	activeModels = {} -- 96
	auxiliaryViews = {} -- 97
	fox = nil -- 98
	secondaryStatsView = nil -- 99
	primaryStatsView = mainView -- 100
	View.frustumCulling = true -- 101
end -- 91
local function setupCase(index) -- 104
	cleanupCase() -- 105
	local item = cases[index + 1] -- 106
	emit("P0_CASE_BEGIN case=" .. item.name) -- 107
	mainView:setEnvironmentMap(studioEnv) -- 108
	mainView:setEnvironmentIntensity(1, 1.8, 1.2) -- 109
	repeat -- 109
		local ____switch10 = item.name -- 109
		local ____cond10 = ____switch10 == "duck" -- 109
		if ____cond10 then -- 109
			setCamera( -- 113
				Vec3(0, 0.65, 3), -- 113
				Vec3(0, 0.25, 0) -- 113
			) -- 113
			loadModel( -- 114
				mainView, -- 114
				"Test/Model3D/Assets/Model/Duck.glb", -- 114
				0.8, -- 114
				Vec3(0, 0, 0), -- 114
				25 -- 114
			) -- 114
			break -- 115
		end -- 115
		____cond10 = ____cond10 or ____switch10 == "damaged-helmet" -- 115
		if ____cond10 then -- 115
			setCamera( -- 117
				Vec3(0, 0.2, 3.2), -- 117
				Vec3(0, 0, 0) -- 117
			) -- 117
			loadModel( -- 118
				mainView, -- 118
				"Test/Model3D/Assets/Model/DamagedHelmet.glb", -- 118
				0.95, -- 118
				Vec3(0, 0, 0), -- 118
				180 -- 118
			) -- 118
			break -- 119
		end -- 119
		____cond10 = ____cond10 or ____switch10 == "specular" -- 119
		if ____cond10 then -- 119
			setCamera( -- 121
				Vec3(0, 0.55, 3.8), -- 121
				Vec3(0, 0.25, 0) -- 121
			) -- 121
			loadModel(mainView, "Test/Model3D/Assets/Model/SpecularTest.glb", 2.5) -- 122
			break -- 123
		end -- 123
		____cond10 = ____cond10 or ____switch10 == "fox-animation" -- 123
		if ____cond10 then -- 123
			setCamera( -- 125
				Vec3(0, 0.75, 3.2), -- 125
				Vec3(0, 0.45, 0) -- 125
			) -- 125
			fox = loadModel( -- 126
				mainView, -- 126
				"Test/Model3D/Assets/Model/Fox.glb", -- 126
				0.022, -- 126
				Vec3(0, 0, 0), -- 126
				-30 -- 126
			) -- 126
			fox:play("Run", true) -- 127
			break -- 128
		end -- 128
		____cond10 = ____cond10 or ____switch10 == "alpha-mask-blend" -- 128
		if ____cond10 then -- 128
			setCamera( -- 130
				Vec3(0, 0.45, 4.6), -- 130
				Vec3(0, 0.15, 0) -- 130
			) -- 130
			loadModel( -- 131
				mainView, -- 131
				"Test/Model3D/Assets/Model/TransmissionTest.glb", -- 131
				1.2, -- 131
				Vec3(-1.15, 0, 0) -- 131
			) -- 131
			loadModel( -- 132
				mainView, -- 132
				"Test/Model3D/Assets/Model/ClearCoatTest.glb", -- 132
				0.12, -- 132
				Vec3(1.15, 0, 0) -- 132
			) -- 132
			break -- 133
		end -- 133
		____cond10 = ____cond10 or ____switch10 == "dual-view" -- 133
		if ____cond10 then -- 133
			do -- 133
				mainView.scene:removeAllChildren(true) -- 135
				setCamera( -- 136
					Vec3(0, 0.65, 4.2), -- 136
					Vec3(0, 0.25, 0) -- 136
				) -- 136
				local studioView = View3D() -- 137
				local warmView = View3D() -- 138
				Director.entry:addChild(studioView) -- 139
				Director.entry:addChild(warmView) -- 140
				studioView:setEnvironmentMap(studioEnv) -- 141
				studioView:setEnvironmentIntensity(1, 1.8, 1.2) -- 142
				warmView:setEnvironmentMap(warmEnv) -- 143
				warmView:setEnvironmentIntensity(1, 1.8, 1.2) -- 144
				loadModel( -- 145
					studioView, -- 145
					"Test/Model3D/Assets/Model/Duck.glb", -- 145
					0.65, -- 145
					Vec3(-0.9, 0, 0), -- 145
					25 -- 145
				) -- 145
				loadModel( -- 146
					warmView, -- 146
					"Test/Model3D/Assets/Model/Duck.glb", -- 146
					0.65, -- 146
					Vec3(0.9, 0, 0), -- 146
					-25 -- 146
				) -- 146
				auxiliaryViews = {studioView, warmView} -- 147
				primaryStatsView = studioView -- 148
				secondaryStatsView = warmView -- 149
				break -- 150
			end -- 150
		end -- 150
		____cond10 = ____cond10 or ____switch10 == "frustum-culling" -- 150
		if ____cond10 then -- 150
			setCamera( -- 153
				Vec3(0, 0.65, 3), -- 153
				Vec3(0, 0.25, 0) -- 153
			) -- 153
			loadModel( -- 154
				mainView, -- 154
				"Test/Model3D/Assets/Model/Duck.glb", -- 154
				0.8, -- 154
				Vec3(0, 0, 0), -- 154
				25 -- 154
			) -- 154
			loadModel( -- 155
				mainView, -- 155
				"Test/Model3D/Assets/Model/Duck.glb", -- 155
				0.8, -- 155
				Vec3(100, 0, 0), -- 155
				25 -- 155
			) -- 155
			View.frustumCulling = true -- 156
			break -- 157
		end -- 157
	until true -- 157
end -- 104
local function caseReady() -- 161
	local expectedEnvironments = cases[caseIndex + 1].name == "dual-view" and 2 or 1 -- 162
	if primaryStatsView.stats.environmentCount < expectedEnvironments then -- 162
		return false -- 163
	end -- 163
	if cases[caseIndex + 1].name ~= "fox-animation" then -- 163
		return true -- 164
	end -- 164
	if not fox or fox.elapsed < 0.5 then -- 164
		return false -- 165
	end -- 165
	fox:pause() -- 166
	return fox.paused -- 167
end -- 161
local function validateCurrentCase() -- 170
	local item = cases[caseIndex + 1] -- 171
	local stats = primaryStatsView.stats -- 172
	if stats.drawCalls <= 0 then -- 172
		fail(("case=" .. item.name) .. " reason=no_draw_calls") -- 173
	end -- 173
	if stats.visibleVisuals <= 0 then -- 173
		fail(("case=" .. item.name) .. " reason=no_visible_visuals") -- 174
	end -- 174
	if stats.triangles <= 0 then -- 174
		fail(("case=" .. item.name) .. " reason=no_triangles") -- 175
	end -- 175
	if item.name == "fox-animation" then -- 175
		if not fox or fox.elapsed < 0.5 or not fox.paused then -- 175
			fail(("case=" .. item.name) .. " reason=animation_not_sampled") -- 179
		end -- 179
	elseif item.name == "alpha-mask-blend" then -- 179
		if stats.opaqueItems <= 0 then -- 179
			fail(("case=" .. item.name) .. " reason=no_mask_items") -- 182
		end -- 182
		if stats.transparentItems <= 0 then -- 182
			fail(("case=" .. item.name) .. " reason=no_blend_items") -- 183
		end -- 183
	elseif item.name == "dual-view" then -- 183
		local second = secondaryStatsView and secondaryStatsView.stats -- 185
		if not second or second.drawCalls <= 0 then -- 185
			fail(("case=" .. item.name) .. " reason=second_view_not_rendered") -- 186
		end -- 186
		if stats.environmentCount < 2 then -- 186
			fail(("case=" .. item.name) .. " reason=environment_registry_not_isolated") -- 187
		end -- 187
	elseif item.name == "frustum-culling" then -- 187
		if stats.visibleVisuals <= 0 or stats.culledVisuals <= 0 then -- 187
			fail(("case=" .. item.name) .. " reason=expected_visible_and_culled_visuals") -- 190
		end -- 190
	end -- 190
	emit(((((((((((("P0_RESULT case=" .. item.name) .. " screenshot=") .. screenshotPath) .. " ") .. ((((("sceneNodes=" .. tostring(stats.sceneNodes)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " culled=") .. tostring(stats.culledVisuals)) .. " ") .. ((((("opaque=" .. tostring(stats.opaqueItems)) .. " transparent=") .. tostring(stats.transparentItems)) .. " draws=") .. tostring(stats.drawCalls)) .. " ") .. ((((("triangles=" .. tostring(stats.triangles)) .. " programs=") .. tostring(stats.programSwitches)) .. " materials=") .. tostring(stats.materialSwitches)) .. " ") .. ((((("textures=" .. tostring(stats.textureSwitches)) .. " meshes=") .. tostring(stats.meshSwitches)) .. " instances=") .. tostring(stats.modelInstanceCount)) .. " ") .. ((((("modelBytes=" .. tostring(stats.modelResidentBytes)) .. " meshBytes=") .. tostring(stats.meshResidentBytes)) .. " textureBytes=") .. tostring(stats.textureResidentBytes)) .. " ") .. ((((("collectUs=" .. tostring(stats.collectMicros)) .. " sortUs=") .. tostring(stats.sortMicros)) .. " submitUs=") .. tostring(stats.submitMicros)) .. " ") .. ((((("uploadCommands=" .. tostring(stats.uploadCommands)) .. " uploadBytes=") .. tostring(stats.uploadBytes)) .. " uploadUs=") .. tostring(stats.uploadMicros)) .. " ") .. "uploadMaxUs=" .. tostring(stats.uploadMaxCommandMicros)) -- 194
end -- 170
local function updateStressPeaks() -- 207
	local stats = mainView.stats -- 208
	stressPeakInstances = math.max(stressPeakInstances, stats.modelInstanceCount) -- 209
	stressPeakNodes = math.max(stressPeakNodes, stats.nodeCount) -- 210
	stressPeakVisuals = math.max(stressPeakVisuals, stats.visualCount) -- 211
end -- 207
local function setupStressScene(index) -- 214
	mainView:setEnvironmentMap(studioEnv) -- 215
	mainView:setEnvironmentIntensity(1, 1.8, 1.2) -- 216
	repeat -- 216
		local ____switch32 = cases[index + 1].name -- 216
		local ____cond32 = ____switch32 == "duck" -- 216
		if ____cond32 then -- 216
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8) -- 219
			break -- 220
		end -- 220
		____cond32 = ____cond32 or ____switch32 == "damaged-helmet" -- 220
		if ____cond32 then -- 220
			loadModel(mainView, "Test/Model3D/Assets/Model/DamagedHelmet.glb", 0.95) -- 222
			break -- 223
		end -- 223
		____cond32 = ____cond32 or ____switch32 == "specular" -- 223
		if ____cond32 then -- 223
			loadModel(mainView, "Test/Model3D/Assets/Model/SpecularTest.glb", 2.5) -- 225
			break -- 226
		end -- 226
		____cond32 = ____cond32 or ____switch32 == "fox-animation" -- 226
		if ____cond32 then -- 226
			do -- 226
				local model = loadModel(mainView, "Test/Model3D/Assets/Model/Fox.glb", 0.022) -- 228
				model:play("Run", true) -- 229
				break -- 230
			end -- 230
		end -- 230
		____cond32 = ____cond32 or ____switch32 == "alpha-mask-blend" -- 230
		if ____cond32 then -- 230
			loadModel(mainView, "Test/Model3D/Assets/Model/TransmissionTest.glb", 1.2) -- 233
			loadModel(mainView, "Test/Model3D/Assets/Model/ClearCoatTest.glb", 0.12) -- 234
			break -- 235
		end -- 235
		____cond32 = ____cond32 or ____switch32 == "dual-view" -- 235
		if ____cond32 then -- 235
			do -- 235
				local first = View3D() -- 237
				local second = View3D() -- 238
				Director.entry:addChild(first) -- 239
				Director.entry:addChild(second) -- 240
				first:setEnvironmentMap(studioEnv) -- 241
				second:setEnvironmentMap(warmEnv) -- 242
				loadModel(first, "Test/Model3D/Assets/Model/Duck.glb", 0.65) -- 243
				loadModel(second, "Test/Model3D/Assets/Model/Duck.glb", 0.65) -- 244
				auxiliaryViews = {first, second} -- 245
				break -- 246
			end -- 246
		end -- 246
		____cond32 = ____cond32 or ____switch32 == "frustum-culling" -- 246
		if ____cond32 then -- 246
			loadModel(mainView, "Test/Model3D/Assets/Model/Duck.glb", 0.8) -- 249
			loadModel( -- 250
				mainView, -- 250
				"Test/Model3D/Assets/Model/Duck.glb", -- 250
				0.8, -- 250
				Vec3(100, 0, 0) -- 250
			) -- 250
			break -- 251
		end -- 251
	until true -- 251
end -- 214
local function finish() -- 255
	local status = #failures == 0 and "PASS" or "FAIL" -- 256
	emit((((((("P0_SUMMARY status=" .. status) .. " cases=") .. tostring(#cases)) .. " stressCycles=") .. tostring(stressCycle)) .. " failures=") .. tostring(#failures)) -- 257
	Content:save( -- 258
		resultPath, -- 258
		table.concat(reportLines, "\n") .. "\n" -- 258
	) -- 258
	App.devMode = false -- 259
	App:shutdown() -- 260
end -- 255
Content:remove(resultPath) -- 263
Content:remove(stressStartPath) -- 264
Content:remove(stressEndPath) -- 265
threadLoop(function() -- 267
	repeat -- 267
		local ____switch37 = phase -- 267
		local ____cond37 = ____switch37 == "setup" -- 267
		if ____cond37 then -- 267
			setupCase(caseIndex) -- 270
			frameCount = 0 -- 271
			phase = "ready" -- 272
			break -- 273
		end -- 273
		____cond37 = ____cond37 or ____switch37 == "ready" -- 273
		if ____cond37 then -- 273
			if caseReady() then -- 273
				frameCount = 0 -- 276
				phase = "settle" -- 277
			end -- 277
			break -- 279
		end -- 279
		____cond37 = ____cond37 or ____switch37 == "settle" -- 279
		if ____cond37 then -- 279
			frameCount = frameCount + 1 -- 281
			if frameCount >= 20 then -- 281
				phase = "screenshot" -- 282
			end -- 282
			break -- 283
		end -- 283
		____cond37 = ____cond37 or ____switch37 == "screenshot" -- 283
		if ____cond37 then -- 283
			do -- 283
				local output = (outputDir .. "/") .. cases[caseIndex + 1].screenshot -- 285
				Content:remove(output .. ".tga") -- 286
				screenshotPath = App:saveScreenshot(output) -- 287
				if screenshotPath == "" then -- 287
					fail(("case=" .. cases[caseIndex + 1].name) .. " reason=screenshot_request_failed") -- 289
					phase = "next" -- 290
				else -- 290
					screenshotWait = 0 -- 292
					phase = "wait-screenshot" -- 293
				end -- 293
				break -- 295
			end -- 295
		end -- 295
		____cond37 = ____cond37 or ____switch37 == "wait-screenshot" -- 295
		if ____cond37 then -- 295
			screenshotWait = screenshotWait + 1 -- 298
			if Content:exist(screenshotPath) then -- 298
				validateCurrentCase() -- 300
				if cases[caseIndex + 1].name == "frustum-culling" then -- 300
					View.frustumCulling = false -- 302
					frameCount = 0 -- 303
					phase = "frustum-off" -- 304
				else -- 304
					phase = "next" -- 306
				end -- 306
			elseif screenshotWait > 180 then -- 306
				fail(("case=" .. cases[caseIndex + 1].name) .. " reason=screenshot_timeout") -- 309
				phase = "next" -- 310
			end -- 310
			break -- 312
		end -- 312
		____cond37 = ____cond37 or ____switch37 == "frustum-off" -- 312
		if ____cond37 then -- 312
			frameCount = frameCount + 1 -- 314
			if frameCount >= 4 then -- 314
				local stats = mainView.stats -- 316
				if stats.visibleVisuals ~= 2 or stats.culledVisuals ~= 0 then -- 316
					fail((("case=frustum-culling reason=disabled_switch visible=" .. tostring(stats.visibleVisuals)) .. " culled=") .. tostring(stats.culledVisuals)) -- 318
				end -- 318
				emit((("P0_CULLING_SWITCH enabled=false visible=" .. tostring(stats.visibleVisuals)) .. " culled=") .. tostring(stats.culledVisuals)) -- 320
				View.frustumCulling = true -- 321
				phase = "next" -- 322
			end -- 322
			break -- 324
		end -- 324
		____cond37 = ____cond37 or ____switch37 == "next" -- 324
		if ____cond37 then -- 324
			cleanupCase() -- 326
			caseIndex = caseIndex + 1 -- 327
			if caseIndex < #cases then -- 327
				phase = "setup" -- 329
			else -- 329
				frameCount = 0 -- 331
				phase = "stress-baseline" -- 332
			end -- 332
			break -- 334
		end -- 334
		____cond37 = ____cond37 or ____switch37 == "stress-baseline" -- 334
		if ____cond37 then -- 334
			frameCount = frameCount + 1 -- 336
			if frameCount >= 8 then -- 336
				collectgarbage("collect") -- 338
				stressBaseline = mainView.stats -- 339
				stressBaselineObjects = Object.count -- 340
				stressBaselineLuaKB = collectgarbage("count") -- 341
				Content:save(stressStartPath, "start\n") -- 342
				if stressBaseline.drawCalls ~= 0 then -- 342
					fail("empty-scene reason=unexpected_3d_draw_calls draws=" .. tostring(stressBaseline.drawCalls)) -- 344
				end -- 344
				emit(((((("P0_STRESS_BASELINE nodes=" .. tostring(stressBaseline.nodeCount)) .. " visuals=") .. tostring(stressBaseline.visualCount)) .. " ") .. ((("instances=" .. tostring(stressBaseline.modelInstanceCount)) .. " models=") .. tostring(stressBaseline.modelCount)) .. " ") .. (("objects=" .. tostring(stressBaselineObjects)) .. " luaKB=") .. __TS__NumberToFixed(stressBaselineLuaKB, 1)) -- 346
				phase = "stress-create" -- 351
			end -- 351
			break -- 353
		end -- 353
		____cond37 = ____cond37 or ____switch37 == "stress-create" -- 353
		if ____cond37 then -- 353
			setupStressScene(stressCycle % #cases) -- 355
			updateStressPeaks() -- 356
			phase = "stress-remove" -- 357
			break -- 358
		end -- 358
		____cond37 = ____cond37 or ____switch37 == "stress-remove" -- 358
		if ____cond37 then -- 358
			updateStressPeaks() -- 360
			cleanupCase() -- 361
			stressCycle = stressCycle + 1 -- 362
			if stressCycle < 300 then -- 362
				phase = "stress-create" -- 364
			else -- 364
				frameCount = 0 -- 366
				phase = "stress-verify" -- 367
			end -- 367
			break -- 369
		end -- 369
		____cond37 = ____cond37 or ____switch37 == "stress-verify" -- 369
		if ____cond37 then -- 369
			frameCount = frameCount + 1 -- 371
			if frameCount >= 12 and stressBaseline then -- 371
				collectgarbage("collect") -- 373
				local stats = mainView.stats -- 374
				local objectCount = Object.count -- 375
				local luaKB = collectgarbage("count") -- 376
				if stats.modelInstanceCount ~= stressBaseline.modelInstanceCount then -- 376
					fail((("stress reason=instance_leak baseline=" .. tostring(stressBaseline.modelInstanceCount)) .. " actual=") .. tostring(stats.modelInstanceCount)) -- 378
				end -- 378
				if stats.nodeCount ~= stressBaseline.nodeCount then -- 378
					fail((("stress reason=node_leak baseline=" .. tostring(stressBaseline.nodeCount)) .. " actual=") .. tostring(stats.nodeCount)) -- 381
				end -- 381
				if stats.visualCount ~= stressBaseline.visualCount then -- 381
					fail((("stress reason=visual_leak baseline=" .. tostring(stressBaseline.visualCount)) .. " actual=") .. tostring(stats.visualCount)) -- 384
				end -- 384
				if objectCount > stressBaselineObjects + 2 then -- 384
					fail((("stress reason=cpp_object_growth baseline=" .. tostring(stressBaselineObjects)) .. " actual=") .. tostring(objectCount)) -- 387
				end -- 387
				emit((((((((("P0_STRESS_RESULT cycles=" .. tostring(stressCycle)) .. " nodes=") .. tostring(stats.nodeCount)) .. " visuals=") .. tostring(stats.visualCount)) .. " ") .. ((((("instances=" .. tostring(stats.modelInstanceCount)) .. " models=") .. tostring(stats.modelCount)) .. " peakNodes=") .. tostring(stressPeakNodes)) .. " ") .. ((((("peakVisuals=" .. tostring(stressPeakVisuals)) .. " peakInstances=") .. tostring(stressPeakInstances)) .. " objects=") .. tostring(objectCount)) .. " ") .. (("luaKB=" .. __TS__NumberToFixed(luaKB, 1)) .. " luaDeltaKB=") .. __TS__NumberToFixed(luaKB - stressBaselineLuaKB, 1)) -- 389
				Content:save(stressEndPath, "end\n") -- 395
				Cache:removeUnused() -- 396
				frameCount = 0 -- 397
				phase = "cache-verify" -- 398
			end -- 398
			break -- 400
		end -- 400
		____cond37 = ____cond37 or ____switch37 == "cache-verify" -- 400
		if ____cond37 then -- 400
			frameCount = frameCount + 1 -- 402
			if frameCount >= 12 then -- 402
				local stats = mainView.stats -- 404
				if stats.nodeCount > 1 or stats.visualCount ~= 0 or stats.modelCount ~= 0 or stats.modelInstanceCount ~= 0 or stats.meshCount ~= 0 or stats.materialCount ~= 0 or stats.animationCount ~= 0 then -- 404
					fail(((((("cache reason=registry_not_empty nodes=" .. tostring(stats.nodeCount)) .. " visuals=") .. tostring(stats.visualCount)) .. " ") .. ((((("models=" .. tostring(stats.modelCount)) .. " instances=") .. tostring(stats.modelInstanceCount)) .. " meshes=") .. tostring(stats.meshCount)) .. " ") .. (("materials=" .. tostring(stats.materialCount)) .. " animations=") .. tostring(stats.animationCount)) -- 414
				end -- 414
				emit(((((((("P0_CACHE_RESULT nodes=" .. tostring(stats.nodeCount)) .. " visuals=") .. tostring(stats.visualCount)) .. " models=") .. tostring(stats.modelCount)) .. " ") .. ((((("meshes=" .. tostring(stats.meshCount)) .. " materials=") .. tostring(stats.materialCount)) .. " textures=") .. tostring(stats.textureCount)) .. " ") .. (("animations=" .. tostring(stats.animationCount)) .. " instances=") .. tostring(stats.modelInstanceCount)) -- 420
				finish() -- 425
				return true -- 426
			end -- 426
			break -- 428
		end -- 428
	until true -- 428
	return false -- 430
end) -- 267
return ____exports -- 267