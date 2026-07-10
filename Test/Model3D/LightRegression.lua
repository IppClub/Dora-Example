-- [ts]: LightRegression.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 5
local Content = ____Dora.Content -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local PointLight3D = ____Dora.PointLight3D -- 10
local Vec3 = ____Dora.Vec3 -- 11
local threadLoop = ____Dora.threadLoop -- 12
local outputDir = "/tmp/dora-3d-light" -- 15
local resultPath = outputDir .. "/result.txt" -- 16
local view = Director.entry -- 17
local camera = Camera3D() -- 18
Director:pushCamera(camera) -- 19
camera:lookAt( -- 20
	Vec3(0, 0.25, 3.2), -- 20
	Vec3(0, 0, 0) -- 20
) -- 20
local phase = "directional-setup" -- 22
local frames = 0 -- 23
local screenshotPath = "" -- 24
local results = {} -- 25
local function emit(message) -- 27
	print(message) -- 28
	results[#results + 1] = message -- 29
end -- 27
local function clearScene() -- 32
	view.scene:removeAllChildren(true) -- 33
end -- 32
local function loadHelmet() -- 36
	local model = Model3D("Test/Model3D/Assets/Model/DamagedHelmet.glb") -- 37
	model.scale = Vec3(0.95, 0.95, 0.95) -- 38
	model.angleY = 180 -- 39
	view:addChild(model) -- 40
end -- 36
local function setupDirectional() -- 43
	clearScene() -- 44
	view:setEnvironmentMap("") -- 45
	view:setEnvironmentIntensity(0, 0, 1.1) -- 46
	loadHelmet() -- 47
	local light = DirectionalLight3D() -- 48
	light.color = Color3(16773596) -- 49
	light.intensity = 4 -- 50
	light.angleX = -20 -- 51
	light.angleY = 25 -- 52
	view:addChild(light) -- 53
end -- 43
local function addPoint(position, color, intensity, range) -- 56
	local light = PointLight3D() -- 57
	light.position = position -- 58
	light.color = Color3(color) -- 59
	light.intensity = intensity -- 60
	light.range = range -- 61
	view:addChild(light) -- 62
end -- 56
local function setupPointLights() -- 65
	clearScene() -- 66
	view:setEnvironmentMap("") -- 67
	view:setEnvironmentIntensity(0, 0, 1) -- 68
	loadHelmet() -- 69
	addPoint( -- 70
		Vec3(-1.4, 1.1, 1.5), -- 70
		16731196, -- 70
		10, -- 70
		4.5 -- 70
	) -- 70
	addPoint( -- 71
		Vec3(1.4, 1, 1.2), -- 71
		3961087, -- 71
		10, -- 71
		4.5 -- 71
	) -- 71
	addPoint( -- 72
		Vec3(-1.2, -0.8, 0.8), -- 72
		4718454, -- 72
		7, -- 72
		4 -- 72
	) -- 72
	addPoint( -- 73
		Vec3(1.2, -0.7, 0.7), -- 73
		16757052, -- 73
		7, -- 73
		4 -- 73
	) -- 73
	addPoint( -- 74
		Vec3(0, 1.8, -1), -- 74
		16729567, -- 74
		5, -- 74
		4.5 -- 74
	) -- 74
	addPoint( -- 75
		Vec3(0, -1.5, -0.5), -- 75
		4778751, -- 75
		5, -- 75
		4.5 -- 75
	) -- 75
end -- 65
local function requestScreenshot(name) -- 78
	local base = (outputDir .. "/") .. name -- 79
	Content:remove(base .. ".tga") -- 80
	screenshotPath = App:saveScreenshot(base) -- 81
	frames = 0 -- 82
end -- 78
local function finish(status, reason) -- 85
	if reason == nil then -- 85
		reason = "" -- 85
	end -- 85
	emit(("LIGHT_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 86
	Content:save( -- 87
		resultPath, -- 87
		table.concat(results, "\n") .. "\n" -- 87
	) -- 87
	App.devMode = false -- 88
	App:shutdown() -- 89
end -- 85
Content:remove(resultPath) -- 92
threadLoop(function() -- 94
	repeat -- 94
		local ____switch11 = phase -- 94
		local ____cond11 = ____switch11 == "directional-setup" -- 94
		if ____cond11 then -- 94
			setupDirectional() -- 97
			frames = 0 -- 98
			phase = "directional-settle" -- 99
			break -- 100
		end -- 100
		____cond11 = ____cond11 or ____switch11 == "directional-settle" -- 100
		if ____cond11 then -- 100
			frames = frames + 1 -- 102
			if frames >= 30 then -- 102
				if view.stats.drawCalls <= 0 then -- 102
					finish("FAIL", "directional_no_draws") -- 103
					return true -- 103
				end -- 103
				requestScreenshot("01-directional-none") -- 104
				phase = "directional-wait" -- 105
			end -- 105
			break -- 107
		end -- 107
		____cond11 = ____cond11 or ____switch11 == "directional-wait" -- 107
		if ____cond11 then -- 107
			if Content:exist(screenshotPath) then -- 107
				emit("LIGHT_RESULT case=directional-none screenshot=" .. screenshotPath) -- 110
				phase = "points-setup" -- 111
			else -- 111
				frames = frames + 1 -- 112
				if frames > 180 then -- 112
					finish("FAIL", "directional_screenshot_timeout") -- 113
					return true -- 114
				end -- 114
			end -- 114
			break -- 116
		end -- 116
		____cond11 = ____cond11 or ____switch11 == "points-setup" -- 116
		if ____cond11 then -- 116
			setupPointLights() -- 118
			frames = 0 -- 119
			phase = "points-settle" -- 120
			break -- 121
		end -- 121
		____cond11 = ____cond11 or ____switch11 == "points-settle" -- 121
		if ____cond11 then -- 121
			frames = frames + 1 -- 123
			if frames >= 30 then -- 123
				if view.stats.drawCalls <= 0 then -- 123
					finish("FAIL", "points_no_draws") -- 124
					return true -- 124
				end -- 124
				requestScreenshot("02-six-points") -- 125
				phase = "points-wait" -- 126
			end -- 126
			break -- 128
		end -- 128
		____cond11 = ____cond11 or ____switch11 == "points-wait" -- 128
		if ____cond11 then -- 128
			if Content:exist(screenshotPath) then -- 128
				emit("LIGHT_RESULT case=six-points screenshot=" .. screenshotPath) -- 131
				finish("PASS") -- 132
				return true -- 133
			else -- 133
				frames = frames + 1 -- 134
				if frames > 180 then -- 134
					finish("FAIL", "points_screenshot_timeout") -- 135
					return true -- 136
				end -- 136
			end -- 136
			break -- 138
		end -- 138
	until true -- 138
	return false -- 140
end) -- 94
return ____exports -- 94