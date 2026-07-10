-- [ts]: AsyncLoadRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
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
local file = "Test/Model3D/Assets/Model/DamagedHelmet.glb" -- 16
local outputDir = "/tmp/dora-3d-async" -- 17
local resultPath = outputDir .. "/result.txt" -- 18
local view = Director.entry -- 19
local camera = Camera3D() -- 20
Director:pushCamera(camera) -- 21
camera:lookAt( -- 22
	Vec3(0, 0.2, 3.2), -- 22
	Vec3(0, 0, 0) -- 22
) -- 22
view:setEnvironmentMap("") -- 23
view:setEnvironmentIntensity(0, 0, 1.1) -- 24
local light = DirectionalLight3D() -- 25
light.color = Color3(16773596) -- 26
light.intensity = 4 -- 27
light.angleX = -20 -- 28
light.angleY = 25 -- 29
view:addChild(light) -- 30
Cache:unload(file) -- 32
Content:remove(resultPath) -- 33
local frame = 0 -- 35
local completed = 0 -- 36
local successes = 0 -- 37
local started = 0 -- 38
local startFrame = 0 -- 39
local requestsStarted = false -- 40
local instantiated = false -- 41
local model -- 42
local instantiateSeconds = 0 -- 43
local screenshotPath = "" -- 44
local screenshotFrames = 0 -- 45
local screenshotReady = false -- 46
local measureFrames = 0 -- 47
local maxDeltaMs = 0 -- 48
local maxDeltaFrame = 0 -- 49
local results = {} -- 50
local function emit(message) -- 52
	print(message) -- 53
	results[#results + 1] = message -- 54
end -- 52
local function finish(status, reason) -- 57
	if reason == nil then -- 57
		reason = "" -- 57
	end -- 57
	emit(("ASYNC_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 58
	Content:save( -- 59
		resultPath, -- 59
		table.concat(results, "\n") .. "\n" -- 59
	) -- 59
	App.devMode = false -- 60
	App:shutdown() -- 61
end -- 57
local function request(index) -- 64
	thread(function() -- 65
		local success = Cache:loadAsync(file) -- 66
		if success then -- 66
			successes = successes + 1 -- 67
		end -- 67
		completed = completed + 1 -- 68
		emit((((("ASYNC_CALLBACK index=" .. tostring(index)) .. " success=") .. tostring(success)) .. " frame=") .. tostring(frame)) -- 69
	end) -- 65
end -- 64
threadLoop(function() -- 73
	frame = frame + 1 -- 74
	if not requestsStarted and frame >= 60 then -- 74
		requestsStarted = true -- 76
		started = App.runningTime -- 77
		startFrame = frame -- 78
		maxDeltaMs = 0 -- 79
		maxDeltaFrame = 0 -- 80
		request(1) -- 81
		request(2) -- 82
	end -- 82
	if not instantiated and completed == 2 then -- 82
		if successes ~= 2 then -- 82
			finish("FAIL", "preload_failed") -- 86
			return true -- 87
		end -- 87
		local loadSeconds = App.runningTime - started -- 89
		local loadFrames = frame - startFrame -- 90
		local instantiateStart = App.runningTime -- 91
		model = Model3D(file) -- 92
		instantiateSeconds = App.runningTime - instantiateStart -- 93
		if not model then -- 93
			finish("FAIL", "cached_model_create_failed") -- 95
			return true -- 96
		end -- 96
		view:addChild(model) -- 98
		model.scale = Vec3(0.95, 0.95, 0.95) -- 99
		model.angleY = 180 -- 100
		instantiated = true -- 101
		measureFrames = 120 -- 102
		emit((((((("ASYNC_RESULT callbacks=" .. tostring(completed)) .. " frames=") .. tostring(loadFrames)) .. " total=") .. __TS__NumberToFixed(loadSeconds, 3)) .. " ") .. "instantiate=" .. __TS__NumberToFixed(instantiateSeconds, 6)) -- 103
		if loadFrames < 1 then -- 103
			finish("FAIL", "main_loop_did_not_advance") -- 108
			return true -- 109
		end -- 109
	end -- 109
	if instantiated and measureFrames == 0 and screenshotPath == "" and view.stats.drawCalls > 0 and frame - startFrame > 20 then -- 109
		screenshotPath = App:saveScreenshot(outputDir .. "/async-damaged-helmet") -- 119
	end -- 119
	if requestsStarted and (not instantiated or measureFrames > 0) then -- 119
		local deltaMs = App.deltaTime * 1000 -- 122
		if deltaMs > maxDeltaMs then -- 122
			maxDeltaMs = deltaMs -- 124
			maxDeltaFrame = frame -- 125
		end -- 125
	end -- 125
	if instantiated and measureFrames > 0 then -- 125
		measureFrames = measureFrames - 1 -- 129
	end -- 129
	if screenshotPath ~= "" then -- 129
		screenshotFrames = screenshotFrames + 1 -- 132
		if Content:exist(screenshotPath) then -- 132
			screenshotReady = true -- 134
		end -- 134
		if screenshotFrames > 180 then -- 134
			finish("FAIL", "screenshot_timeout") -- 137
			return true -- 138
		end -- 138
	end -- 138
	if screenshotReady and measureFrames == 0 then -- 138
		emit("ASYNC_SCREENSHOT path=" .. screenshotPath) -- 142
		emit((("ASYNC_FRAME_RESULT maxDeltaMs=" .. __TS__NumberToFixed(maxDeltaMs, 1)) .. " frame=") .. tostring(maxDeltaFrame)) -- 143
		if maxDeltaMs > 250 then -- 143
			finish("FAIL", "upload_frame_budget_exceeded") -- 145
		else -- 145
			finish("PASS") -- 147
		end -- 147
		return true -- 149
	end -- 149
	return false -- 151
end) -- 73
return ____exports -- 73