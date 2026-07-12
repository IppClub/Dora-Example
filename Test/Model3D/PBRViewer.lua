-- [ts]: PBRViewer.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Content = ____Dora.Content -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Vec2 = ____Dora.Vec2 -- 2
local Vec3 = ____Dora.Vec3 -- 2
local View = ____Dora.View -- 2
local threadLoop = ____Dora.threadLoop -- 2
local ImGui = require("ImGui") -- 4
local metalRoughPackage = Content:getFullPath("Test/Model3D/Assets/Model/MetalRoughSpheres.glb.zip") -- 23
if __TS__ArrayIndexOf(Content.searchPaths, metalRoughPackage) < 0 then -- 23
	Content:addSearchPath(metalRoughPackage) -- 25
end -- 25
local cases = { -- 28
	{ -- 29
		name = "Specular", -- 30
		file = "Test/Model3D/Assets/Model/SpecularTest.glb", -- 31
		description = "KHR_materials_specular and color/factor response.", -- 32
		scale = 1, -- 33
		camera = { -- 34
			0, -- 34
			0.55, -- 34
			3.8, -- 34
			0, -- 34
			0.25, -- 34
			0 -- 34
		} -- 34
	}, -- 34
	{ -- 36
		name = "Metal Rough", -- 37
		file = "MetalRoughSpheres.glb", -- 38
		description = "Metallic-roughness grid with texture-driven material values.", -- 39
		scale = 0.7, -- 40
		camera = { -- 41
			0, -- 41
			0.4, -- 41
			4.2, -- 41
			0, -- 41
			0.1, -- 41
			0 -- 41
		}, -- 41
		angleX = 15 -- 42
	}, -- 42
	{ -- 44
		name = "Clearcoat", -- 45
		file = "Test/Model3D/Assets/Model/ClearCoatTest.glb", -- 46
		description = "KHR_materials_clearcoat factor, roughness, and normal texture.", -- 47
		scale = 1, -- 48
		camera = { -- 49
			0, -- 49
			0.45, -- 49
			3.8, -- 49
			0, -- 49
			0.1, -- 49
			0 -- 49
		}, -- 49
		angleY = -20 -- 50
	}, -- 50
	{ -- 52
		name = "Transmission", -- 53
		file = "Test/Model3D/Assets/Model/TransmissionTest.glb", -- 54
		description = "KHR_materials_transmission with environment refraction approximation.", -- 55
		scale = 1, -- 56
		camera = { -- 57
			0, -- 57
			0.5, -- 57
			4.2, -- 57
			0, -- 57
			0.15, -- 57
			0 -- 57
		} -- 57
	}, -- 57
	{ -- 59
		name = "Volume", -- 60
		file = "Test/Model3D/Assets/Model/CompareVolume.glb", -- 61
		description = "KHR_materials_volume attenuation and thickness.", -- 62
		scale = 1, -- 63
		camera = { -- 64
			0, -- 64
			0.45, -- 64
			4.2, -- 64
			0, -- 64
			0.1, -- 64
			0 -- 64
		} -- 64
	}, -- 64
	{ -- 66
		name = "Sheen", -- 67
		file = "Test/Model3D/Assets/Model/SheenCloth/SheenCloth.gltf", -- 68
		description = "KHR_materials_sheen color and roughness texture.", -- 69
		scale = 1.2, -- 70
		camera = { -- 71
			0, -- 71
			0.35, -- 71
			3.2, -- 71
			0, -- 71
			0.2, -- 71
			0 -- 71
		}, -- 71
		angleY = -20 -- 72
	}, -- 72
	{ -- 74
		name = "Anisotropy Strength", -- 75
		file = "Test/Model3D/Assets/Model/AnisotropyStrengthTest.glb", -- 76
		description = "KHR_materials_anisotropy strength sweep.", -- 77
		scale = 1.2, -- 78
		camera = { -- 79
			0, -- 79
			0.35, -- 79
			3.6, -- 79
			0, -- 79
			0.1, -- 79
			0 -- 79
		}, -- 79
		angleX = 15 -- 80
	}, -- 80
	{ -- 82
		name = "Anisotropy Texture", -- 83
		file = "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb", -- 84
		description = "KHR_materials_anisotropy rotation and texture channels.", -- 85
		scale = 1.2, -- 86
		camera = { -- 87
			0, -- 87
			0.35, -- 87
			3.6, -- 87
			0, -- 87
			0.1, -- 87
			0 -- 87
		}, -- 87
		angleX = 15 -- 88
	}, -- 88
	{ -- 90
		name = "Emissive Strength", -- 91
		file = "Test/Model3D/Assets/Model/EmissiveStrengthTest.glb", -- 92
		description = "KHR_materials_emissive_strength.", -- 93
		scale = 1.4, -- 94
		camera = { -- 95
			0, -- 95
			0.15, -- 95
			3, -- 95
			0, -- 95
			0, -- 95
			0 -- 95
		} -- 95
	}, -- 95
	{ -- 97
		name = "Unlit", -- 98
		file = "Test/Model3D/Assets/Model/UnlitTest.glb", -- 99
		description = "KHR_materials_unlit bypass path.", -- 100
		scale = 1.4, -- 101
		camera = { -- 102
			0, -- 102
			0.1, -- 102
			2.8, -- 102
			0, -- 102
			0, -- 102
			0 -- 102
		} -- 102
	}, -- 102
	{ -- 104
		name = "Damaged Helmet", -- 105
		file = "Test/Model3D/Assets/Model/DamagedHelmet.glb", -- 106
		description = "Real-world baseline asset using core PBR maps.", -- 107
		scale = 1.8, -- 108
		camera = { -- 109
			0, -- 109
			0.2, -- 109
			3.2, -- 109
			0, -- 109
			0, -- 109
			0 -- 109
		}, -- 109
		angleY = 180 -- 110
	}, -- 110
	{ -- 112
		name = "Fox Animation", -- 113
		file = "Test/Model3D/Assets/Model/Fox.glb", -- 114
		description = "Skinned model and glTF animation playback.", -- 115
		scale = 0.015, -- 116
		camera = { -- 117
			0, -- 117
			0.75, -- 117
			3.2, -- 117
			0, -- 117
			0.45, -- 117
			0 -- 117
		}, -- 117
		animation = "Run" -- 118
	}, -- 118
	{ -- 120
		name = "Frustum Culling", -- 121
		file = "Test/Model3D/Assets/Model/Duck.glb", -- 122
		description = "Render queue culling check using View.frustumCulling.", -- 123
		scale = 0.8, -- 124
		camera = { -- 125
			0, -- 125
			0.65, -- 125
			3, -- 125
			0, -- 125
			0.25, -- 125
			0 -- 125
		}, -- 125
		angleY = 25 -- 126
	} -- 126
} -- 126
local testNames = __TS__ArrayMap( -- 130
	cases, -- 130
	function(____, item) return item.name end -- 130
) -- 130
local windowFlags = {"NoSavedSettings", "NoFocusOnAppearing"} -- 131
local view = Director.entry -- 136
local camera = Camera3D() -- 138
Director:pushCamera(camera) -- 139
local currentCase = 1 -- 141
local loadedCase = 0 -- 142
local currentModel -- 143
local autoRotate = true -- 144
local envIndex = 1 -- 145
local environmentLoaded = false -- 146
local diffuseIntensity = 1 -- 147
local specularIntensity = 1.8 -- 148
local exposure = 1.2 -- 149
local noneLighting = {diffuse = 1, specular = 1, exposure = 1.2} -- 150
local environmentLighting = {diffuse = 1, specular = 1.8, exposure = 1.2} -- 151
local loadSeconds = 0 -- 152
local elapsed = 0 -- 153
local cameraDistance = 0 -- 154
local cameraHeight = 0 -- 155
local yaw = 0 -- 156
local animationSpeed = 1 -- 157
local pendingCase = 0 -- 158
local pendingFrames = 0 -- 159
local loadState = "Ready" -- 160
local frustumCulling = View.frustumCulling -- 161
local environmentNames = {"None", "Studio", "Warm"} -- 163
local environmentFiles = {"Test/Model3D/Assets/Env/studio.png", "Test/Model3D/Assets/Env/warm.png"} -- 164
local function lightingProfile(index) -- 169
	return index == 1 and noneLighting or environmentLighting -- 170
end -- 169
local function saveLighting(index) -- 173
	local lighting = lightingProfile(index) -- 174
	lighting.diffuse = diffuseIntensity -- 175
	lighting.specular = specularIntensity -- 176
	lighting.exposure = exposure -- 177
end -- 173
local function loadLighting(index) -- 180
	local lighting = lightingProfile(index) -- 181
	diffuseIntensity = lighting.diffuse -- 182
	specularIntensity = lighting.specular -- 183
	exposure = lighting.exposure -- 184
end -- 180
local function applyEnvironment() -- 187
	local start = App.runningTime -- 188
	if envIndex == 1 then -- 188
		environmentLoaded = view:setEnvironmentMap("") -- 190
	else -- 190
		environmentLoaded = view:setEnvironmentMap(environmentFiles[envIndex - 2 + 1]) -- 192
	end -- 192
	view:setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure) -- 194
	print((((("PBRViewer environment " .. environmentNames[envIndex]) .. " loaded=") .. tostring(environmentLoaded)) .. " time=") .. tostring(App.runningTime - start)) -- 195
end -- 187
local function applyCamera(item) -- 198
	local eyeX, eyeY, eyeZ, atX, atY, atZ = table.unpack(item.camera, 1, 6) -- 199
	local orbitX = math.sin(yaw) * cameraDistance -- 200
	local orbitZ = math.cos(yaw) * cameraDistance -- 201
	camera:lookAt( -- 202
		Vec3(eyeX + orbitX, eyeY + cameraHeight, eyeZ + orbitZ), -- 202
		Vec3(atX, atY, atZ) -- 202
	) -- 202
end -- 198
local function unloadModel() -- 205
	if currentModel then -- 205
		currentModel:removeFromParent(true) -- 207
		currentModel = nil -- 208
	end -- 208
end -- 205
local function requestLoadCase(index) -- 212
	if pendingCase == index and pendingFrames > 0 then -- 212
		return -- 214
	end -- 214
	unloadModel() -- 216
	pendingCase = index -- 217
	pendingFrames = 2 -- 218
	loadState = "Preparing " .. cases[index].name -- 219
end -- 212
local function loadCaseNow(index) -- 222
	local item = cases[index] -- 223
	local start = App.runningTime -- 224
	loadState = "Loading " .. item.name -- 225
	currentModel = Model3D(item.file) -- 226
	loadSeconds = App.runningTime - start -- 227
	loadedCase = index -- 228
	elapsed = 0 -- 229
	yaw = 0 -- 230
	cameraDistance = 0 -- 231
	cameraHeight = 0 -- 232
	if not currentModel then -- 232
		loadState = "Failed" -- 234
		print("PBRViewer failed to load " .. item.file) -- 235
		return -- 236
	end -- 236
	view.scene:addChild(currentModel) -- 238
	currentModel.scaleX = item.scale -- 239
	currentModel.scaleY = item.scale -- 240
	currentModel.scaleZ = item.scale -- 241
	currentModel.angleX = item.angleX or 0 -- 242
	currentModel.angleY = item.angleY or 0 -- 243
	if item.animation and currentModel.play then -- 243
		currentModel.speed = animationSpeed -- 245
		currentModel:play(item.animation, true) -- 246
	end -- 246
	applyCamera(item) -- 248
	loadState = "Ready" -- 249
	print((((("PBRViewer case " .. item.name) .. " load=") .. tostring(loadSeconds)) .. " file=") .. item.file) -- 250
end -- 222
applyEnvironment() -- 253
requestLoadCase(currentCase) -- 254
threadLoop(function() -- 256
	local deltaTime = App.deltaTime -- 257
	if pendingCase > 0 then -- 257
		pendingFrames = pendingFrames - 1 -- 259
		if pendingFrames <= 0 then -- 259
			local index = pendingCase -- 261
			pendingCase = 0 -- 262
			loadCaseNow(index) -- 263
		end -- 263
	end -- 263
	elapsed = elapsed + deltaTime -- 266
	local item = cases[(loadedCase > 0 and loadedCase - 1 or currentCase - 1) + 1] -- 267
	if currentModel and autoRotate then -- 267
		currentModel.angleY = (item.angleY or 0) + elapsed * 22.5 -- 269
	end -- 269
	if loadedCase > 0 then -- 269
		applyCamera(item) -- 272
	end -- 272
	local ____App_visualSize_0 = App.visualSize -- 275
	local width = ____App_visualSize_0.width -- 275
	ImGui.SetNextWindowPos( -- 276
		Vec2(width - 10, 10), -- 276
		"FirstUseEver", -- 276
		Vec2(1, 0) -- 276
	) -- 276
	ImGui.SetNextWindowSize( -- 277
		Vec2(330, 0), -- 277
		"FirstUseEver" -- 277
	) -- 277
	ImGui.SetNextWindowBgAlpha(0.42) -- 278
	ImGui.Begin( -- 279
		"glTF PBR", -- 279
		windowFlags, -- 279
		function() -- 279
			ImGui.Text("Model3D glTF PBR") -- 280
			ImGui.Separator() -- 281
			local changed = false -- 282
			changed, currentCase = ImGui.Combo("Case", currentCase, testNames) -- 283
			if changed then -- 283
				requestLoadCase(currentCase) -- 285
			end -- 285
			local selected = cases[currentCase] -- 288
			ImGui.TextWrapped(selected.description) -- 289
			ImGui.Text("State: " .. loadState) -- 290
			ImGui.Text(("Load: " .. __TS__NumberToFixed(loadSeconds, 3)) .. "s") -- 291
			ImGui.Text("File: " .. selected.file) -- 292
			ImGui.Separator() -- 293
			changed, autoRotate = ImGui.Checkbox("Auto Rotate", autoRotate) -- 295
			changed, frustumCulling = ImGui.Checkbox("Frustum Culling", frustumCulling) -- 296
			if changed then -- 296
				View.frustumCulling = frustumCulling -- 298
			end -- 298
			ImGui.PushItemWidth( -- 301
				-80, -- 301
				function() -- 301
					changed, cameraDistance = ImGui.DragFloat( -- 302
						"Orbit", -- 302
						cameraDistance, -- 302
						0.02, -- 302
						-8, -- 302
						8, -- 302
						"%.2f" -- 302
					) -- 302
					changed, cameraHeight = ImGui.DragFloat( -- 303
						"Height", -- 303
						cameraHeight, -- 303
						0.02, -- 303
						-2, -- 303
						2, -- 303
						"%.2f" -- 303
					) -- 303
					changed, yaw = ImGui.DragFloat( -- 304
						"Yaw", -- 304
						yaw, -- 304
						0.01, -- 304
						-3.14, -- 304
						3.14, -- 304
						"%.2f" -- 304
					) -- 304
				end -- 301
			) -- 301
			if selected.animation and currentModel then -- 301
				ImGui.Separator() -- 308
				ImGui.Text("Animation: " .. selected.animation) -- 309
				ImGui.Text((("Time: " .. __TS__NumberToFixed(currentModel.elapsed, 2)) .. " / ") .. __TS__NumberToFixed(currentModel.duration, 2)) -- 310
				ImGui.Text("State: " .. (currentModel.playing and (currentModel.paused and "Paused" or "Playing") or "Stopped")) -- 311
				ImGui.PushItemWidth( -- 312
					-80, -- 312
					function() -- 312
						local speedChanged = false -- 313
						speedChanged, animationSpeed = ImGui.DragFloat( -- 314
							"Anim Speed", -- 314
							animationSpeed, -- 314
							0.05, -- 314
							0, -- 314
							3, -- 314
							"%.2f" -- 314
						) -- 314
						if speedChanged then -- 314
							currentModel.speed = animationSpeed -- 316
						end -- 316
					end -- 312
				) -- 312
				if ImGui.Button( -- 312
					currentModel.paused and "Resume Anim" or "Pause Anim", -- 319
					Vec2(120, 30) -- 319
				) then -- 319
					if currentModel.paused then -- 319
						currentModel:resume() -- 321
					else -- 321
						currentModel:pause() -- 323
					end -- 323
				end -- 323
				ImGui.SameLine() -- 326
				if ImGui.Button( -- 326
					"Restart Anim", -- 327
					Vec2(120, 30) -- 327
				) then -- 327
					currentModel:play(selected.animation, true) -- 328
				end -- 328
			end -- 328
			ImGui.Separator() -- 332
			local previousEnvIndex = envIndex -- 333
			changed, envIndex = ImGui.Combo("Env", envIndex, environmentNames) -- 334
			if changed then -- 334
				saveLighting(previousEnvIndex) -- 336
				loadLighting(envIndex) -- 337
				applyEnvironment() -- 338
			end -- 338
			ImGui.PushItemWidth( -- 340
				-80, -- 340
				function() -- 340
					local envChanged = false -- 341
					envChanged, diffuseIntensity = ImGui.DragFloat( -- 342
						"Diffuse", -- 342
						diffuseIntensity, -- 342
						0.05, -- 342
						0, -- 342
						4, -- 342
						"%.2f" -- 342
					) -- 342
					if envChanged then -- 342
						changed = true -- 343
					end -- 343
					envChanged, specularIntensity = ImGui.DragFloat( -- 344
						"Specular", -- 344
						specularIntensity, -- 344
						0.05, -- 344
						0, -- 344
						4, -- 344
						"%.2f" -- 344
					) -- 344
					if envChanged then -- 344
						changed = true -- 345
					end -- 345
					envChanged, exposure = ImGui.DragFloat( -- 346
						"Exposure", -- 346
						exposure, -- 346
						0.05, -- 346
						0.1, -- 346
						4, -- 346
						"%.2f" -- 346
					) -- 346
					if envChanged then -- 346
						changed = true -- 347
					end -- 347
				end -- 340
			) -- 340
			if changed then -- 340
				saveLighting(envIndex) -- 350
				view:setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure) -- 351
			end -- 351
			if ImGui.Button( -- 351
				loadedCase == currentCase and "Reload" or "Load", -- 353
				Vec2(120, 30) -- 353
			) then -- 353
				requestLoadCase(currentCase) -- 354
			end -- 354
			ImGui.SameLine() -- 356
			if ImGui.Button( -- 356
				"Reset View", -- 357
				Vec2(120, 30) -- 357
			) then -- 357
				cameraDistance = 0 -- 358
				cameraHeight = 0 -- 359
				yaw = 0 -- 360
				applyCamera(item) -- 361
			end -- 361
			ImGui.Separator() -- 364
			local stats = view.stats -- 365
			ImGui.Text((("Draws: " .. tostring(stats.drawCalls)) .. "  Triangles: ") .. tostring(stats.triangles)) -- 366
			ImGui.Text((("Visible: " .. tostring(stats.visibleVisuals)) .. "  Culled: ") .. tostring(stats.culledVisuals)) -- 367
			ImGui.Text((("Opaque: " .. tostring(stats.opaqueItems)) .. "  Transparent: ") .. tostring(stats.transparentItems)) -- 368
			ImGui.Text((("Program/Material: " .. tostring(stats.programSwitches)) .. "/") .. tostring(stats.materialSwitches)) -- 369
			ImGui.Text((("Texture/Mesh: " .. tostring(stats.textureSwitches)) .. "/") .. tostring(stats.meshSwitches)) -- 370
		end -- 279
	) -- 279
	return false -- 373
end) -- 256
return ____exports -- 256