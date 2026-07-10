-- [ts]: PBRViewer.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Vec2 = ____Dora.Vec2 -- 2
local Vec3 = ____Dora.Vec3 -- 2
local View = ____Dora.View -- 2
local threadLoop = ____Dora.threadLoop -- 2
local ImGui = require("ImGui") -- 4
local cases = { -- 23
	{ -- 24
		name = "Specular", -- 25
		file = "Test/Model3D/Assets/Model/SpecularTest.glb", -- 26
		description = "KHR_materials_specular and color/factor response.", -- 27
		scale = 1, -- 28
		camera = { -- 29
			0, -- 29
			0.55, -- 29
			3.8, -- 29
			0, -- 29
			0.25, -- 29
			0 -- 29
		} -- 29
	}, -- 29
	{ -- 31
		name = "Metal Rough", -- 32
		file = "Test/Model3D/Assets/Model/MetalRoughSpheres.glb", -- 33
		description = "Metallic-roughness grid with texture-driven material values.", -- 34
		scale = 0.7, -- 35
		camera = { -- 36
			0, -- 36
			0.4, -- 36
			4.2, -- 36
			0, -- 36
			0.1, -- 36
			0 -- 36
		}, -- 36
		angleX = 15 -- 37
	}, -- 37
	{ -- 39
		name = "Clearcoat", -- 40
		file = "Test/Model3D/Assets/Model/ClearCoatTest.glb", -- 41
		description = "KHR_materials_clearcoat factor, roughness, and normal texture.", -- 42
		scale = 1, -- 43
		camera = { -- 44
			0, -- 44
			0.45, -- 44
			3.8, -- 44
			0, -- 44
			0.1, -- 44
			0 -- 44
		}, -- 44
		angleY = -20 -- 45
	}, -- 45
	{ -- 47
		name = "Transmission", -- 48
		file = "Test/Model3D/Assets/Model/TransmissionTest.glb", -- 49
		description = "KHR_materials_transmission with environment refraction approximation.", -- 50
		scale = 1, -- 51
		camera = { -- 52
			0, -- 52
			0.5, -- 52
			4.2, -- 52
			0, -- 52
			0.15, -- 52
			0 -- 52
		} -- 52
	}, -- 52
	{ -- 54
		name = "Volume", -- 55
		file = "Test/Model3D/Assets/Model/CompareVolume.glb", -- 56
		description = "KHR_materials_volume attenuation and thickness.", -- 57
		scale = 1, -- 58
		camera = { -- 59
			0, -- 59
			0.45, -- 59
			4.2, -- 59
			0, -- 59
			0.1, -- 59
			0 -- 59
		} -- 59
	}, -- 59
	{ -- 61
		name = "Sheen", -- 62
		file = "Test/Model3D/Assets/Model/SheenCloth/SheenCloth.gltf", -- 63
		description = "KHR_materials_sheen color and roughness texture.", -- 64
		scale = 1.2, -- 65
		camera = { -- 66
			0, -- 66
			0.35, -- 66
			3.2, -- 66
			0, -- 66
			0.2, -- 66
			0 -- 66
		}, -- 66
		angleY = -20 -- 67
	}, -- 67
	{ -- 69
		name = "Anisotropy Strength", -- 70
		file = "Test/Model3D/Assets/Model/AnisotropyStrengthTest.glb", -- 71
		description = "KHR_materials_anisotropy strength sweep.", -- 72
		scale = 1.2, -- 73
		camera = { -- 74
			0, -- 74
			0.35, -- 74
			3.6, -- 74
			0, -- 74
			0.1, -- 74
			0 -- 74
		}, -- 74
		angleX = 15 -- 75
	}, -- 75
	{ -- 77
		name = "Anisotropy Texture", -- 78
		file = "Test/Model3D/Assets/Model/AnisotropyRotationTest.glb", -- 79
		description = "KHR_materials_anisotropy rotation and texture channels.", -- 80
		scale = 1.2, -- 81
		camera = { -- 82
			0, -- 82
			0.35, -- 82
			3.6, -- 82
			0, -- 82
			0.1, -- 82
			0 -- 82
		}, -- 82
		angleX = 15 -- 83
	}, -- 83
	{ -- 85
		name = "Emissive Strength", -- 86
		file = "Test/Model3D/Assets/Model/EmissiveStrengthTest.glb", -- 87
		description = "KHR_materials_emissive_strength.", -- 88
		scale = 1.4, -- 89
		camera = { -- 90
			0, -- 90
			0.15, -- 90
			3, -- 90
			0, -- 90
			0, -- 90
			0 -- 90
		} -- 90
	}, -- 90
	{ -- 92
		name = "Unlit", -- 93
		file = "Test/Model3D/Assets/Model/UnlitTest.glb", -- 94
		description = "KHR_materials_unlit bypass path.", -- 95
		scale = 1.4, -- 96
		camera = { -- 97
			0, -- 97
			0.1, -- 97
			2.8, -- 97
			0, -- 97
			0, -- 97
			0 -- 97
		} -- 97
	}, -- 97
	{ -- 99
		name = "Damaged Helmet", -- 100
		file = "Test/Model3D/Assets/Model/DamagedHelmet.glb", -- 101
		description = "Real-world baseline asset using core PBR maps.", -- 102
		scale = 1.8, -- 103
		camera = { -- 104
			0, -- 104
			0.2, -- 104
			3.2, -- 104
			0, -- 104
			0, -- 104
			0 -- 104
		}, -- 104
		angleY = 180 -- 105
	}, -- 105
	{ -- 107
		name = "Fox Animation", -- 108
		file = "Test/Model3D/Assets/Model/Fox.glb", -- 109
		description = "Skinned model and glTF animation playback.", -- 110
		scale = 0.015, -- 111
		camera = { -- 112
			0, -- 112
			0.75, -- 112
			3.2, -- 112
			0, -- 112
			0.45, -- 112
			0 -- 112
		}, -- 112
		animation = "Run" -- 113
	}, -- 113
	{ -- 115
		name = "Frustum Culling", -- 116
		file = "Test/Model3D/Assets/Model/Duck.glb", -- 117
		description = "Render queue culling check using View.frustumCulling.", -- 118
		scale = 0.8, -- 119
		camera = { -- 120
			0, -- 120
			0.65, -- 120
			3, -- 120
			0, -- 120
			0.25, -- 120
			0 -- 120
		}, -- 120
		angleY = 25 -- 121
	} -- 121
} -- 121
local testNames = __TS__ArrayMap( -- 125
	cases, -- 125
	function(____, item) return item.name end -- 125
) -- 125
local windowFlags = {"NoSavedSettings", "NoFocusOnAppearing"} -- 126
local view = Director.entry -- 131
local camera = Camera3D() -- 133
Director:pushCamera(camera) -- 134
local currentCase = 1 -- 136
local loadedCase = 0 -- 137
local currentModel -- 138
local autoRotate = true -- 139
local envIndex = 1 -- 140
local environmentLoaded = false -- 141
local diffuseIntensity = 1 -- 142
local specularIntensity = 1.8 -- 143
local exposure = 1.2 -- 144
local noneLighting = {diffuse = 1, specular = 1, exposure = 1.2} -- 145
local environmentLighting = {diffuse = 1, specular = 1.8, exposure = 1.2} -- 146
local loadSeconds = 0 -- 147
local elapsed = 0 -- 148
local cameraDistance = 0 -- 149
local cameraHeight = 0 -- 150
local yaw = 0 -- 151
local animationSpeed = 1 -- 152
local pendingCase = 0 -- 153
local pendingFrames = 0 -- 154
local loadState = "Ready" -- 155
local frustumCulling = View.frustumCulling -- 156
local environmentNames = {"None", "Studio", "Warm"} -- 158
local environmentFiles = {"Test/Model3D/Assets/Env/studio.png", "Test/Model3D/Assets/Env/warm.png"} -- 159
local function lightingProfile(index) -- 164
	return index == 1 and noneLighting or environmentLighting -- 165
end -- 164
local function saveLighting(index) -- 168
	local lighting = lightingProfile(index) -- 169
	lighting.diffuse = diffuseIntensity -- 170
	lighting.specular = specularIntensity -- 171
	lighting.exposure = exposure -- 172
end -- 168
local function loadLighting(index) -- 175
	local lighting = lightingProfile(index) -- 176
	diffuseIntensity = lighting.diffuse -- 177
	specularIntensity = lighting.specular -- 178
	exposure = lighting.exposure -- 179
end -- 175
local function applyEnvironment() -- 182
	local start = App.runningTime -- 183
	if envIndex == 1 then -- 183
		environmentLoaded = view:setEnvironmentMap("") -- 185
	else -- 185
		environmentLoaded = view:setEnvironmentMap(environmentFiles[envIndex - 2 + 1]) -- 187
	end -- 187
	view:setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure) -- 189
	print((((("PBRViewer environment " .. environmentNames[envIndex]) .. " loaded=") .. tostring(environmentLoaded)) .. " time=") .. tostring(App.runningTime - start)) -- 190
end -- 182
local function applyCamera(item) -- 193
	local eyeX, eyeY, eyeZ, atX, atY, atZ = table.unpack(item.camera, 1, 6) -- 194
	local orbitX = math.sin(yaw) * cameraDistance -- 195
	local orbitZ = math.cos(yaw) * cameraDistance -- 196
	camera:lookAt( -- 197
		Vec3(eyeX + orbitX, eyeY + cameraHeight, eyeZ + orbitZ), -- 197
		Vec3(atX, atY, atZ) -- 197
	) -- 197
end -- 193
local function unloadModel() -- 200
	if currentModel then -- 200
		currentModel:removeFromParent(true) -- 202
		currentModel = nil -- 203
	end -- 203
end -- 200
local function requestLoadCase(index) -- 207
	if pendingCase == index and pendingFrames > 0 then -- 207
		return -- 209
	end -- 209
	unloadModel() -- 211
	pendingCase = index -- 212
	pendingFrames = 2 -- 213
	loadState = "Preparing " .. cases[index].name -- 214
end -- 207
local function loadCaseNow(index) -- 217
	local item = cases[index] -- 218
	local start = App.runningTime -- 219
	loadState = "Loading " .. item.name -- 220
	currentModel = Model3D(item.file) -- 221
	loadSeconds = App.runningTime - start -- 222
	loadedCase = index -- 223
	elapsed = 0 -- 224
	yaw = 0 -- 225
	cameraDistance = 0 -- 226
	cameraHeight = 0 -- 227
	if not currentModel then -- 227
		loadState = "Failed" -- 229
		print("PBRViewer failed to load " .. item.file) -- 230
		return -- 231
	end -- 231
	view.scene:addChild(currentModel) -- 233
	currentModel.scaleX = item.scale -- 234
	currentModel.scaleY = item.scale -- 235
	currentModel.scaleZ = item.scale -- 236
	currentModel.angleX = item.angleX or 0 -- 237
	currentModel.angleY = item.angleY or 0 -- 238
	if item.animation and currentModel.play then -- 238
		currentModel.speed = animationSpeed -- 240
		currentModel:play(item.animation, true) -- 241
	end -- 241
	applyCamera(item) -- 243
	loadState = "Ready" -- 244
	print((((("PBRViewer case " .. item.name) .. " load=") .. tostring(loadSeconds)) .. " file=") .. item.file) -- 245
end -- 217
applyEnvironment() -- 248
requestLoadCase(currentCase) -- 249
threadLoop(function() -- 251
	local deltaTime = App.deltaTime -- 252
	if pendingCase > 0 then -- 252
		pendingFrames = pendingFrames - 1 -- 254
		if pendingFrames <= 0 then -- 254
			local index = pendingCase -- 256
			pendingCase = 0 -- 257
			loadCaseNow(index) -- 258
		end -- 258
	end -- 258
	elapsed = elapsed + deltaTime -- 261
	local item = cases[(loadedCase > 0 and loadedCase - 1 or currentCase - 1) + 1] -- 262
	if currentModel and autoRotate then -- 262
		currentModel.angleY = (item.angleY or 0) + elapsed * 22.5 -- 264
	end -- 264
	if loadedCase > 0 then -- 264
		applyCamera(item) -- 267
	end -- 267
	local ____App_visualSize_0 = App.visualSize -- 270
	local width = ____App_visualSize_0.width -- 270
	ImGui.SetNextWindowPos( -- 271
		Vec2(width - 10, 10), -- 271
		"FirstUseEver", -- 271
		Vec2(1, 0) -- 271
	) -- 271
	ImGui.SetNextWindowSize( -- 272
		Vec2(330, 0), -- 272
		"FirstUseEver" -- 272
	) -- 272
	ImGui.SetNextWindowBgAlpha(0.42) -- 273
	ImGui.Begin( -- 274
		"glTF PBR", -- 274
		windowFlags, -- 274
		function() -- 274
			ImGui.Text("Model3D glTF PBR") -- 275
			ImGui.Separator() -- 276
			local changed = false -- 277
			changed, currentCase = ImGui.Combo("Case", currentCase, testNames) -- 278
			if changed then -- 278
				requestLoadCase(currentCase) -- 280
			end -- 280
			local selected = cases[currentCase] -- 283
			ImGui.TextWrapped(selected.description) -- 284
			ImGui.Text("State: " .. loadState) -- 285
			ImGui.Text(("Load: " .. __TS__NumberToFixed(loadSeconds, 3)) .. "s") -- 286
			ImGui.Text("File: " .. selected.file) -- 287
			ImGui.Separator() -- 288
			changed, autoRotate = ImGui.Checkbox("Auto Rotate", autoRotate) -- 290
			changed, frustumCulling = ImGui.Checkbox("Frustum Culling", frustumCulling) -- 291
			if changed then -- 291
				View.frustumCulling = frustumCulling -- 293
			end -- 293
			ImGui.PushItemWidth( -- 296
				-80, -- 296
				function() -- 296
					changed, cameraDistance = ImGui.DragFloat( -- 297
						"Orbit", -- 297
						cameraDistance, -- 297
						0.02, -- 297
						-8, -- 297
						8, -- 297
						"%.2f" -- 297
					) -- 297
					changed, cameraHeight = ImGui.DragFloat( -- 298
						"Height", -- 298
						cameraHeight, -- 298
						0.02, -- 298
						-2, -- 298
						2, -- 298
						"%.2f" -- 298
					) -- 298
					changed, yaw = ImGui.DragFloat( -- 299
						"Yaw", -- 299
						yaw, -- 299
						0.01, -- 299
						-3.14, -- 299
						3.14, -- 299
						"%.2f" -- 299
					) -- 299
				end -- 296
			) -- 296
			if selected.animation and currentModel then -- 296
				ImGui.Separator() -- 303
				ImGui.Text("Animation: " .. selected.animation) -- 304
				ImGui.Text((("Time: " .. __TS__NumberToFixed(currentModel.elapsed, 2)) .. " / ") .. __TS__NumberToFixed(currentModel.duration, 2)) -- 305
				ImGui.Text("State: " .. (currentModel.playing and (currentModel.paused and "Paused" or "Playing") or "Stopped")) -- 306
				ImGui.PushItemWidth( -- 307
					-80, -- 307
					function() -- 307
						local speedChanged = false -- 308
						speedChanged, animationSpeed = ImGui.DragFloat( -- 309
							"Anim Speed", -- 309
							animationSpeed, -- 309
							0.05, -- 309
							0, -- 309
							3, -- 309
							"%.2f" -- 309
						) -- 309
						if speedChanged then -- 309
							currentModel.speed = animationSpeed -- 311
						end -- 311
					end -- 307
				) -- 307
				if ImGui.Button( -- 307
					currentModel.paused and "Resume Anim" or "Pause Anim", -- 314
					Vec2(120, 30) -- 314
				) then -- 314
					if currentModel.paused then -- 314
						currentModel:resume() -- 316
					else -- 316
						currentModel:pause() -- 318
					end -- 318
				end -- 318
				ImGui.SameLine() -- 321
				if ImGui.Button( -- 321
					"Restart Anim", -- 322
					Vec2(120, 30) -- 322
				) then -- 322
					currentModel:play(selected.animation, true) -- 323
				end -- 323
			end -- 323
			ImGui.Separator() -- 327
			local previousEnvIndex = envIndex -- 328
			changed, envIndex = ImGui.Combo("Env", envIndex, environmentNames) -- 329
			if changed then -- 329
				saveLighting(previousEnvIndex) -- 331
				loadLighting(envIndex) -- 332
				applyEnvironment() -- 333
			end -- 333
			ImGui.PushItemWidth( -- 335
				-80, -- 335
				function() -- 335
					local envChanged = false -- 336
					envChanged, diffuseIntensity = ImGui.DragFloat( -- 337
						"Diffuse", -- 337
						diffuseIntensity, -- 337
						0.05, -- 337
						0, -- 337
						4, -- 337
						"%.2f" -- 337
					) -- 337
					if envChanged then -- 337
						changed = true -- 338
					end -- 338
					envChanged, specularIntensity = ImGui.DragFloat( -- 339
						"Specular", -- 339
						specularIntensity, -- 339
						0.05, -- 339
						0, -- 339
						4, -- 339
						"%.2f" -- 339
					) -- 339
					if envChanged then -- 339
						changed = true -- 340
					end -- 340
					envChanged, exposure = ImGui.DragFloat( -- 341
						"Exposure", -- 341
						exposure, -- 341
						0.05, -- 341
						0.1, -- 341
						4, -- 341
						"%.2f" -- 341
					) -- 341
					if envChanged then -- 341
						changed = true -- 342
					end -- 342
				end -- 335
			) -- 335
			if changed then -- 335
				saveLighting(envIndex) -- 345
				view:setEnvironmentIntensity(diffuseIntensity, specularIntensity, exposure) -- 346
			end -- 346
			if ImGui.Button( -- 346
				loadedCase == currentCase and "Reload" or "Load", -- 348
				Vec2(120, 30) -- 348
			) then -- 348
				requestLoadCase(currentCase) -- 349
			end -- 349
			ImGui.SameLine() -- 351
			if ImGui.Button( -- 351
				"Reset View", -- 352
				Vec2(120, 30) -- 352
			) then -- 352
				cameraDistance = 0 -- 353
				cameraHeight = 0 -- 354
				yaw = 0 -- 355
				applyCamera(item) -- 356
			end -- 356
			ImGui.Separator() -- 359
			local stats = view.stats -- 360
			ImGui.Text((("Draws: " .. tostring(stats.drawCalls)) .. "  Triangles: ") .. tostring(stats.triangles)) -- 361
			ImGui.Text((("Visible: " .. tostring(stats.visibleVisuals)) .. "  Culled: ") .. tostring(stats.culledVisuals)) -- 362
			ImGui.Text((("Opaque: " .. tostring(stats.opaqueItems)) .. "  Transparent: ") .. tostring(stats.transparentItems)) -- 363
			ImGui.Text((("Program/Material: " .. tostring(stats.programSwitches)) .. "/") .. tostring(stats.materialSwitches)) -- 364
			ImGui.Text((("Texture/Mesh: " .. tostring(stats.textureSwitches)) .. "/") .. tostring(stats.meshSwitches)) -- 365
		end -- 274
	) -- 274
	return false -- 368
end) -- 251
return ____exports -- 251