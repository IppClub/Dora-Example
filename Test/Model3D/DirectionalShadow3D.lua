-- [ts]: DirectionalShadow3D.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 5
local Content = ____Dora.Content -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Vec3 = ____Dora.Vec3 -- 10
local threadLoop = ____Dora.threadLoop -- 11
local outputDir = "/tmp/dora-3d-shadow" -- 14
local resultPath = outputDir .. "/result.txt" -- 15
local view = Director.entry -- 16
local camera = Camera3D() -- 17
Director:pushCamera(camera) -- 18
camera:lookAt( -- 19
	Vec3(4.8, 3.7, 6.5), -- 19
	Vec3(0, 0.25, 0) -- 19
) -- 19
view.shadowMapSize = 2048 -- 20
view:setEnvironmentMap("") -- 21
view:setEnvironmentIntensity(0.18, 0.05, 1) -- 22
local ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 24
ground.position = Vec3(0, -0.72, 0) -- 25
view:addChild(ground) -- 26
local alphaCaster = Model3D("Test/Model3D/Assets/Model/AlphaMaskCaster.gltf") -- 28
alphaCaster.position = Vec3(2.2, -0.06, -1.15) -- 31
alphaCaster.scale = Vec3(0.22, 0.22, 0.22) -- 32
alphaCaster.angleX = 90 -- 33
view:addChild(alphaCaster) -- 34
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 36
duck.position = Vec3(-1.15, -0.7, 0) -- 37
duck.scale = Vec3(0.8, 0.8, 0.8) -- 38
duck.angleY = -25 -- 39
view:addChild(duck) -- 40
local fox = Model3D("Test/Model3D/Assets/Model/Fox.glb") -- 42
fox.position = Vec3(1, -0.7, 0.2) -- 43
fox.scale = Vec3(0.018, 0.018, 0.018) -- 44
fox.angleY = 145 -- 45
fox:play("Walk", true) -- 46
view:addChild(fox) -- 47
local light = DirectionalLight3D() -- 49
light.color = Color3(16773336) -- 50
light.intensity = 4.5 -- 51
light.angleX = -48 -- 52
light.angleY = -35 -- 53
light.shadowBias = 0.004 -- 54
light.shadowNormalBias = 0.02 -- 55
light.shadowSoftness = 2 -- 56
view:addChild(light) -- 57
local phase = "without-shadow" -- 59
local frames = 0 -- 60
local screenshotPath = "" -- 61
local results = {} -- 62
local function capture(name) -- 64
	local base = (outputDir .. "/") .. name -- 65
	Content:remove(base .. ".tga") -- 66
	screenshotPath = App:saveScreenshot(base) -- 67
	frames = 0 -- 68
end -- 64
local function finish(status, reason) -- 71
	if reason == nil then -- 71
		reason = "" -- 71
	end -- 71
	local summary = ("SHADOW_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason) -- 72
	print(summary) -- 73
	results[#results + 1] = summary -- 74
	Content:save( -- 75
		resultPath, -- 75
		table.concat(results, "\n") .. "\n" -- 75
	) -- 75
	App.devMode = false -- 76
	App:shutdown() -- 77
end -- 71
Content:remove(resultPath) -- 80
threadLoop(function() -- 81
	repeat -- 81
		local ____switch5 = phase -- 81
		local ____cond5 = ____switch5 == "without-shadow" -- 81
		if ____cond5 then -- 81
			frames = frames + 1 -- 84
			if frames >= 45 then -- 84
				fox:pause() -- 85
				capture("01-disabled") -- 86
				phase = "wait-disabled" -- 87
			end -- 87
			break -- 89
		end -- 89
		____cond5 = ____cond5 or ____switch5 == "wait-disabled" -- 89
		if ____cond5 then -- 89
			if Content:exist(screenshotPath) then -- 89
				results[#results + 1] = "SHADOW_RESULT case=disabled screenshot=" .. screenshotPath -- 92
				light.castShadow = true -- 93
				frames = 0 -- 94
				phase = "with-shadow" -- 95
			else -- 95
				frames = frames + 1 -- 96
				if frames > 180 then -- 96
					finish("FAIL", "disabled_screenshot_timeout") -- 97
					return true -- 98
				end -- 98
			end -- 98
			break -- 100
		end -- 100
		____cond5 = ____cond5 or ____switch5 == "with-shadow" -- 100
		if ____cond5 then -- 100
			frames = frames + 1 -- 102
			if frames >= 45 then -- 102
				capture("02-enabled") -- 103
				phase = "wait-enabled" -- 104
			end -- 104
			break -- 106
		end -- 106
		____cond5 = ____cond5 or ____switch5 == "wait-enabled" -- 106
		if ____cond5 then -- 106
			if Content:exist(screenshotPath) then -- 106
				results[#results + 1] = "SHADOW_RESULT case=enabled screenshot=" .. screenshotPath -- 109
				if view.stats.drawCalls > 0 then -- 109
					finish("PASS") -- 110
				else -- 110
					finish("FAIL", "no_draws") -- 111
				end -- 111
				return true -- 112
			else -- 112
				frames = frames + 1 -- 113
				if frames > 180 then -- 113
					finish("FAIL", "enabled_screenshot_timeout") -- 114
					return true -- 115
				end -- 115
			end -- 115
			break -- 117
		end -- 117
	until true -- 117
	return false -- 119
end) -- 81
return ____exports -- 81