-- [ts]: AnimationRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Content = ____Dora.Content -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Vec3 = ____Dora.Vec3 -- 2
local threadLoop = ____Dora.threadLoop -- 2
local outputDir = "/tmp/dora-3d-animation" -- 12
local resultPath = outputDir .. "/result.txt" -- 13
local cases = { -- 14
	{ -- 15
		name = "ordinary-node", -- 16
		file = "Test/Model3D/Assets/Model/AnimatedTriangle/AnimatedTriangle.gltf", -- 17
		camera = { -- 18
			Vec3(0, 0, 3), -- 18
			Vec3(0, 0, 0) -- 18
		}, -- 18
		scale = 1.5, -- 19
		sampleTime = 0.6 -- 20
	}, -- 20
	{ -- 22
		name = "interpolation", -- 23
		file = "Test/Model3D/Assets/Model/InterpolationTest/InterpolationTest.glb", -- 24
		camera = { -- 25
			Vec3(0, 0, 9), -- 25
			Vec3(0, 0, 0) -- 25
		}, -- 25
		scale = 0.65, -- 26
		sampleTime = 1.25 -- 27
	}, -- 27
	{ -- 29
		name = "multi-skin", -- 30
		file = "Test/Model3D/Assets/Model/SimpleSkin/MultiSkin.gltf", -- 31
		camera = { -- 32
			Vec3(0, 1, 5), -- 32
			Vec3(0, 1, 0) -- 32
		}, -- 32
		scale = 1.2, -- 33
		sampleTime = 1.5 -- 34
	} -- 34
} -- 34
local view = Director.entry -- 38
local camera = Camera3D() -- 39
Director:pushCamera(camera) -- 40
view:setEnvironmentMap("Test/Model3D/Assets/Env/studio.png") -- 41
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 42
local current -- 44
local index = 0 -- 45
local phase = "setup" -- 46
local frames = 0 -- 47
local screenshotPath = "" -- 48
local results = {} -- 49
local function emit(message) -- 51
	print(message) -- 52
	results[#results + 1] = message -- 53
end -- 51
local function finish(status, reason) -- 56
	if reason == nil then -- 56
		reason = "" -- 56
	end -- 56
	emit(("ANIMATION_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 57
	Content:save( -- 58
		resultPath, -- 58
		table.concat(results, "\n") .. "\n" -- 58
	) -- 58
	App.devMode = false -- 59
	App:shutdown() -- 60
end -- 56
local function setup(item) -- 63
	view.scene:removeAllChildren(true) -- 64
	current = Model3D(item.file) -- 65
	view:addChild(current) -- 66
	current.scale = Vec3(item.scale, item.scale, item.scale) -- 67
	local duration = current:play("", true) -- 68
	if duration <= 0 then -- 68
		finish("FAIL", item.name .. "_missing_animation") -- 70
		return false -- 71
	end -- 71
	camera:lookAt(item.camera[1], item.camera[2]) -- 73
	emit((("ANIMATION_BEGIN case=" .. item.name) .. " duration=") .. __TS__NumberToFixed(duration, 3)) -- 74
	return true -- 75
end -- 63
Content:remove(resultPath) -- 78
threadLoop(function() -- 80
	local item = cases[index + 1] -- 81
	repeat -- 81
		local ____switch7 = phase -- 81
		local ____cond7 = ____switch7 == "setup" -- 81
		if ____cond7 then -- 81
			if not setup(item) then -- 81
				return true -- 84
			end -- 84
			phase = "sample" -- 85
			break -- 86
		end -- 86
		____cond7 = ____cond7 or ____switch7 == "sample" -- 86
		if ____cond7 then -- 86
			if current and current.elapsed >= item.sampleTime then -- 86
				current:pause() -- 89
				frames = 0 -- 90
				phase = "settle" -- 91
			end -- 91
			break -- 93
		end -- 93
		____cond7 = ____cond7 or ____switch7 == "settle" -- 93
		if ____cond7 then -- 93
			frames = frames + 1 -- 95
			if frames >= 8 then -- 95
				if not current or not current.paused or view.stats.drawCalls <= 0 then -- 95
					finish("FAIL", item.name .. "_not_sampled") -- 97
					return true -- 98
				end -- 98
				local output = (((outputDir .. "/0") .. tostring(index + 1)) .. "-") .. item.name -- 100
				Content:remove(output .. ".tga") -- 101
				screenshotPath = App:saveScreenshot(output) -- 102
				frames = 0 -- 103
				phase = "wait" -- 104
			end -- 104
			break -- 106
		end -- 106
		____cond7 = ____cond7 or ____switch7 == "wait" -- 106
		if ____cond7 then -- 106
			if Content:exist(screenshotPath) then -- 106
				local ____emit_5 = emit -- 109
				local ____item_name_4 = item.name -- 109
				local ____opt_0 = current -- 109
				____emit_5((((("ANIMATION_RESULT case=" .. ____item_name_4) .. " elapsed=") .. tostring(____opt_0 and __TS__NumberToFixed(current and current.elapsed, 3))) .. " screenshot=") .. screenshotPath) -- 109
				index = index + 1 -- 110
				if index >= #cases then -- 110
					finish("PASS") -- 112
					return true -- 113
				end -- 113
				phase = "setup" -- 115
			else -- 115
				frames = frames + 1 -- 116
				if frames > 180 then -- 116
					finish("FAIL", item.name .. "_screenshot_timeout") -- 117
					return true -- 118
				end -- 118
			end -- 118
			break -- 120
		end -- 120
	until true -- 120
	return false -- 122
end) -- 80
return ____exports -- 80