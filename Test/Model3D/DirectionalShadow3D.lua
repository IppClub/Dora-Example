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
alphaCaster.position = Vec3(2.2, -0.06, -1.15) -- 30
alphaCaster.scale = Vec3(0.22, 0.22, 0.22) -- 31
alphaCaster.angleX = 90 -- 32
view:addChild(alphaCaster) -- 33
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 35
duck.position = Vec3(-1.15, -0.7, 0) -- 36
duck.scale = Vec3(0.8, 0.8, 0.8) -- 37
duck.angleY = -25 -- 38
view:addChild(duck) -- 39
local fox = Model3D("Test/Model3D/Assets/Model/Fox.glb") -- 41
fox.position = Vec3(1, -0.7, 0.2) -- 42
fox.scale = Vec3(0.018, 0.018, 0.018) -- 43
fox.angleY = 145 -- 44
fox:play("Walk", true) -- 45
view:addChild(fox) -- 46
local light = DirectionalLight3D() -- 48
light.color = Color3(16773336) -- 49
light.intensity = 4.5 -- 50
light.angleX = -48 -- 51
light.angleY = -35 -- 52
light.shadowBias = 0.004 -- 53
light.shadowNormalBias = 0.02 -- 54
view:addChild(light) -- 55
local phase = "without-shadow" -- 57
local frames = 0 -- 58
local screenshotPath = "" -- 59
local results = {} -- 60
local function capture(name) -- 62
	local base = (outputDir .. "/") .. name -- 63
	Content:remove(base .. ".tga") -- 64
	screenshotPath = App:saveScreenshot(base) -- 65
	frames = 0 -- 66
end -- 62
local function finish(status, reason) -- 69
	if reason == nil then -- 69
		reason = "" -- 69
	end -- 69
	local summary = ("SHADOW_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason) -- 70
	print(summary) -- 71
	results[#results + 1] = summary -- 72
	Content:save( -- 73
		resultPath, -- 73
		table.concat(results, "\n") .. "\n" -- 73
	) -- 73
	App.devMode = false -- 74
	App:shutdown() -- 75
end -- 69
Content:remove(resultPath) -- 78
threadLoop(function() -- 79
	repeat -- 79
		local ____switch5 = phase -- 79
		local ____cond5 = ____switch5 == "without-shadow" -- 79
		if ____cond5 then -- 79
			frames = frames + 1 -- 82
			if frames >= 45 then -- 82
				fox:pause() -- 83
				capture("01-disabled") -- 84
				phase = "wait-disabled" -- 85
			end -- 85
			break -- 87
		end -- 87
		____cond5 = ____cond5 or ____switch5 == "wait-disabled" -- 87
		if ____cond5 then -- 87
			if Content:exist(screenshotPath) then -- 87
				results[#results + 1] = "SHADOW_RESULT case=disabled screenshot=" .. screenshotPath -- 90
				light.castShadow = true -- 91
				frames = 0 -- 92
				phase = "with-shadow" -- 93
			else -- 93
				frames = frames + 1 -- 94
				if frames > 180 then -- 94
					finish("FAIL", "disabled_screenshot_timeout") -- 95
					return true -- 96
				end -- 96
			end -- 96
			break -- 98
		end -- 98
		____cond5 = ____cond5 or ____switch5 == "with-shadow" -- 98
		if ____cond5 then -- 98
			frames = frames + 1 -- 100
			if frames >= 45 then -- 100
				capture("02-enabled") -- 101
				phase = "wait-enabled" -- 102
			end -- 102
			break -- 104
		end -- 104
		____cond5 = ____cond5 or ____switch5 == "wait-enabled" -- 104
		if ____cond5 then -- 104
			if Content:exist(screenshotPath) then -- 104
				results[#results + 1] = "SHADOW_RESULT case=enabled screenshot=" .. screenshotPath -- 107
				if view.stats.drawCalls > 0 then -- 107
					finish("PASS") -- 108
				else -- 108
					finish("FAIL", "no_draws") -- 109
				end -- 109
				return true -- 110
			else -- 110
				frames = frames + 1 -- 111
				if frames > 180 then -- 111
					finish("FAIL", "enabled_screenshot_timeout") -- 112
					return true -- 113
				end -- 113
			end -- 113
			break -- 115
		end -- 115
	until true -- 115
	return false -- 117
end) -- 79
return ____exports -- 79