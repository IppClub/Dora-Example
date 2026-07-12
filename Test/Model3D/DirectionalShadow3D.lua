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
view:setEnvironmentMap("") -- 20
view:setEnvironmentIntensity(0.18, 0.05, 1) -- 21
local ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 23
ground.position = Vec3(0, -0.72, 0) -- 24
view:addChild(ground) -- 25
local alphaCaster = Model3D("Test/Model3D/Assets/Model/AlphaMaskCaster.gltf") -- 27
alphaCaster.position = Vec3(0.15, 0.35, -1.15) -- 28
alphaCaster.scale = Vec3(0.22, 0.22, 0.22) -- 29
alphaCaster.angleX = 90 -- 30
view:addChild(alphaCaster) -- 31
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 33
duck.position = Vec3(-1.15, -0.7, 0) -- 34
duck.scale = Vec3(0.8, 0.8, 0.8) -- 35
duck.angleY = -25 -- 36
view:addChild(duck) -- 37
local fox = Model3D("Test/Model3D/Assets/Model/Fox.glb") -- 39
fox.position = Vec3(1, -0.7, 0.2) -- 40
fox.scale = Vec3(0.018, 0.018, 0.018) -- 41
fox.angleY = 145 -- 42
fox:play("Walk", true) -- 43
view:addChild(fox) -- 44
local light = DirectionalLight3D() -- 46
light.color = Color3(16773336) -- 47
light.intensity = 4.5 -- 48
light.angleX = -48 -- 49
light.angleY = -35 -- 50
light.shadowBias = 0.004 -- 51
light.shadowNormalBias = 0.02 -- 52
view:addChild(light) -- 53
local phase = "without-shadow" -- 55
local frames = 0 -- 56
local screenshotPath = "" -- 57
local results = {} -- 58
local function capture(name) -- 60
	local base = (outputDir .. "/") .. name -- 61
	Content:remove(base .. ".tga") -- 62
	screenshotPath = App:saveScreenshot(base) -- 63
	frames = 0 -- 64
end -- 60
local function finish(status, reason) -- 67
	if reason == nil then -- 67
		reason = "" -- 67
	end -- 67
	local summary = ("SHADOW_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason) -- 68
	print(summary) -- 69
	results[#results + 1] = summary -- 70
	Content:save( -- 71
		resultPath, -- 71
		table.concat(results, "\n") .. "\n" -- 71
	) -- 71
	App.devMode = false -- 72
	App:shutdown() -- 73
end -- 67
Content:remove(resultPath) -- 76
threadLoop(function() -- 77
	repeat -- 77
		local ____switch5 = phase -- 77
		local ____cond5 = ____switch5 == "without-shadow" -- 77
		if ____cond5 then -- 77
			frames = frames + 1 -- 80
			if frames >= 45 then -- 80
				fox:pause() -- 81
				capture("01-disabled") -- 82
				phase = "wait-disabled" -- 83
			end -- 83
			break -- 85
		end -- 85
		____cond5 = ____cond5 or ____switch5 == "wait-disabled" -- 85
		if ____cond5 then -- 85
			if Content:exist(screenshotPath) then -- 85
				results[#results + 1] = "SHADOW_RESULT case=disabled screenshot=" .. screenshotPath -- 88
				light.castShadow = true -- 89
				frames = 0 -- 90
				phase = "with-shadow" -- 91
			else -- 91
				frames = frames + 1 -- 92
				if frames > 180 then -- 92
					finish("FAIL", "disabled_screenshot_timeout") -- 93
					return true -- 94
				end -- 94
			end -- 94
			break -- 96
		end -- 96
		____cond5 = ____cond5 or ____switch5 == "with-shadow" -- 96
		if ____cond5 then -- 96
			frames = frames + 1 -- 98
			if frames >= 45 then -- 98
				capture("02-enabled") -- 99
				phase = "wait-enabled" -- 100
			end -- 100
			break -- 102
		end -- 102
		____cond5 = ____cond5 or ____switch5 == "wait-enabled" -- 102
		if ____cond5 then -- 102
			if Content:exist(screenshotPath) then -- 102
				results[#results + 1] = "SHADOW_RESULT case=enabled screenshot=" .. screenshotPath -- 105
				if view.stats.drawCalls > 0 then -- 105
					finish("PASS") -- 106
				else -- 106
					finish("FAIL", "no_draws") -- 107
				end -- 107
				return true -- 108
			else -- 108
				frames = frames + 1 -- 109
				if frames > 180 then -- 109
					finish("FAIL", "enabled_screenshot_timeout") -- 110
					return true -- 111
				end -- 111
			end -- 111
			break -- 113
		end -- 113
	until true -- 113
	return false -- 115
end) -- 77
return ____exports -- 77