-- [ts]: EnvironmentAsyncRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Content = ____Dora.Content -- 5
local Director = ____Dora.Director -- 6
local Model3D = ____Dora.Model3D -- 7
local Vec3 = ____Dora.Vec3 -- 8
local threadLoop = ____Dora.threadLoop -- 9
local outputDir = "/tmp/dora-3d-environment-async" -- 12
local resultPath = outputDir .. "/result.txt" -- 13
local environments = {"Test/Model3D/Assets/Env/studio.png", "Test/Model3D/Assets/Env/warm.png"} -- 14
local view = Director.entry -- 18
local camera = Camera3D() -- 19
Director:pushCamera(camera) -- 20
camera:lookAt( -- 21
	Vec3(0, 0.65, 3), -- 21
	Vec3(0, 0.25, 0) -- 21
) -- 21
view:setEnvironmentMap("") -- 22
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 23
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 25
view:addChild(duck) -- 26
duck.scale = Vec3(0.8, 0.8, 0.8) -- 27
duck.angleY = 25 -- 28
Content:remove(resultPath) -- 30
local results = {} -- 31
local frame = 0 -- 32
local environmentIndex = -1 -- 33
local expectedCount = 0 -- 34
local startedFrame = 0 -- 35
local startedTime = 0 -- 36
local maxDeltaMs = 0 -- 37
local maxDeltaFrame = 0 -- 38
local screenshotPath = "" -- 39
local screenshotWait = 0 -- 40
local function emit(message) -- 42
	print(message) -- 43
	results[#results + 1] = message -- 44
end -- 42
local function finish(status, reason) -- 47
	if reason == nil then -- 47
		reason = "" -- 47
	end -- 47
	emit(("ENV_ASYNC_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 48
	Content:save( -- 49
		resultPath, -- 49
		table.concat(results, "\n") .. "\n" -- 49
	) -- 49
	App.devMode = false -- 50
	App:shutdown() -- 51
end -- 47
local function beginEnvironment(index) -- 54
	environmentIndex = index -- 55
	expectedCount = index + 1 -- 56
	startedFrame = frame -- 57
	startedTime = App.runningTime -- 58
	maxDeltaMs = 0 -- 59
	maxDeltaFrame = frame -- 60
	screenshotPath = "" -- 61
	screenshotWait = 0 -- 62
	local accepted = view:setEnvironmentMap(environments[index + 1]) -- 63
	emit((((("ENV_ASYNC_BEGIN index=" .. tostring(index)) .. " accepted=") .. tostring(accepted)) .. " frame=") .. tostring(frame)) -- 64
	if not accepted then -- 64
		finish( -- 65
			"FAIL", -- 65
			"request_rejected_" .. tostring(index) -- 65
		) -- 65
	end -- 65
end -- 54
threadLoop(function() -- 68
	frame = frame + 1 -- 69
	if environmentIndex < 0 and frame >= 60 then -- 69
		beginEnvironment(0) -- 70
	end -- 70
	if environmentIndex >= 0 and screenshotPath == "" then -- 70
		local deltaMs = App.deltaTime * 1000 -- 73
		if deltaMs > maxDeltaMs then -- 73
			maxDeltaMs = deltaMs -- 75
			maxDeltaFrame = frame -- 76
		end -- 76
		if view.stats.environmentCount >= expectedCount then -- 76
			local stats = view.stats -- 79
			emit(((((((("ENV_ASYNC_READY index=" .. tostring(environmentIndex)) .. " frames=") .. tostring(frame - startedFrame)) .. " ") .. ((("total=" .. __TS__NumberToFixed(App.runningTime - startedTime, 3)) .. " maxDeltaMs=") .. __TS__NumberToFixed(maxDeltaMs, 1)) .. " ") .. ((("maxFrame=" .. tostring(maxDeltaFrame)) .. " environmentCount=") .. tostring(stats.environmentCount)) .. " ") .. ((("uploadCommands=" .. tostring(stats.uploadCommands)) .. " uploadBytes=") .. tostring(stats.uploadBytes)) .. " ") .. "uploadMaxUs=" .. tostring(stats.uploadMaxCommandMicros)) -- 80
			screenshotPath = App:saveScreenshot((outputDir .. "/") .. (environmentIndex == 0 and "01-studio" or "02-warm")) -- 87
		end -- 87
		if frame - startedFrame > 900 then -- 87
			finish( -- 92
				"FAIL", -- 92
				"environment_timeout_" .. tostring(environmentIndex) -- 92
			) -- 92
			return true -- 93
		end -- 93
	end -- 93
	if screenshotPath ~= "" then -- 93
		screenshotWait = screenshotWait + 1 -- 98
		if Content:exist(screenshotPath) then -- 98
			emit((("ENV_ASYNC_SCREENSHOT index=" .. tostring(environmentIndex)) .. " path=") .. screenshotPath) -- 100
			if maxDeltaMs > 250 then -- 100
				finish( -- 102
					"FAIL", -- 102
					"frame_budget_" .. tostring(environmentIndex) -- 102
				) -- 102
				return true -- 103
			end -- 103
			if environmentIndex == 0 then -- 103
				beginEnvironment(1) -- 106
			else -- 106
				finish("PASS") -- 108
				return true -- 109
			end -- 109
		elseif screenshotWait > 180 then -- 109
			finish( -- 112
				"FAIL", -- 112
				"screenshot_timeout_" .. tostring(environmentIndex) -- 112
			) -- 112
			return true -- 113
		end -- 113
	end -- 113
	return false -- 116
end) -- 68
return ____exports -- 68