-- [ts]: AsyncLoadVisual.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Cache = ____Dora.Cache -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Vec2 = ____Dora.Vec2 -- 10
local Vec3 = ____Dora.Vec3 -- 11
local thread = ____Dora.thread -- 12
local threadLoop = ____Dora.threadLoop -- 13
local ImGui = require("ImGui") -- 16
local file = "Test/Model3D/Assets/Model/DamagedHelmet.glb" -- 18
local view = Director.entry -- 19
local camera = Camera3D() -- 20
Director:pushCamera(camera) -- 21
camera:lookAt( -- 22
	Vec3(0, 0.2, 3.2), -- 22
	Vec3(0, 0, 0) -- 22
) -- 22
view:setEnvironmentMap("") -- 24
view:setEnvironmentIntensity(0, 0, 1.1) -- 25
local light = DirectionalLight3D() -- 26
light.color = Color3(16773596) -- 27
light.intensity = 4 -- 28
light.angleX = -20 -- 29
light.angleY = 25 -- 30
view:addChild(light) -- 31
local state = "Waiting" -- 35
local frame = 0 -- 36
local autoStartFrames = 60 -- 37
local loadStart = 0 -- 38
local loadSeconds = 0 -- 39
local callbackFrame = 0 -- 40
local instantiateSeconds = 0 -- 41
local currentDeltaMs = 0 -- 42
local maxDeltaMs = 0 -- 43
local maxDeltaFrame = 0 -- 44
local freezeCount = 0 -- 45
local postReadyFrames = 0 -- 46
local model -- 47
local function clearModel() -- 49
	if model then -- 49
		model:removeFromParent(true) -- 51
		model = nil -- 52
	end -- 52
end -- 49
local function startAsyncLoad() -- 56
	if state == "Loading" then -- 56
		return -- 57
	end -- 57
	clearModel() -- 58
	Cache:unload(file) -- 59
	state = "Loading" -- 60
	loadStart = App.runningTime -- 61
	loadSeconds = 0 -- 62
	callbackFrame = 0 -- 63
	instantiateSeconds = 0 -- 64
	maxDeltaMs = 0 -- 65
	maxDeltaFrame = 0 -- 66
	freezeCount = 0 -- 67
	postReadyFrames = 0 -- 68
	print((("ASYNC_VISUAL_BEGIN frame=" .. tostring(frame)) .. " file=") .. file) -- 69
	thread(function() -- 71
		local loaded = Cache:loadAsync(file) -- 72
		callbackFrame = frame -- 73
		loadSeconds = App.runningTime - loadStart -- 74
		if not loaded then -- 74
			state = "Failed" -- 76
			print("ASYNC_VISUAL_FAILED frame=" .. tostring(frame)) -- 77
			return -- 78
		end -- 78
		local instantiateStart = App.runningTime -- 81
		model = Model3D(file) -- 82
		instantiateSeconds = App.runningTime - instantiateStart -- 83
		if not model then -- 83
			state = "Failed" -- 85
			print("ASYNC_VISUAL_INSTANTIATE_FAILED frame=" .. tostring(frame)) -- 86
			return -- 87
		end -- 87
		model.scale = Vec3(0.95, 0.95, 0.95) -- 89
		model.angleY = 180 -- 90
		view:addChild(model) -- 91
		state = "Ready" -- 92
		postReadyFrames = 120 -- 93
		print((((("ASYNC_VISUAL_READY callbackFrame=" .. tostring(callbackFrame)) .. " total=") .. __TS__NumberToFixed(loadSeconds, 3)) .. " ") .. (("instantiate=" .. __TS__NumberToFixed(instantiateSeconds, 6)) .. " maxDeltaMs=") .. __TS__NumberToFixed(maxDeltaMs, 1)) -- 94
	end) -- 71
end -- 56
local spinner = {"|", "/", "-", "\\"} -- 101
local windowFlags = {"NoSavedSettings", "NoFocusOnAppearing"} -- 102
threadLoop(function() -- 104
	frame = frame + 1 -- 105
	currentDeltaMs = App.deltaTime * 1000 -- 106
	if state == "Loading" or postReadyFrames > 0 then -- 106
		if currentDeltaMs > maxDeltaMs then -- 106
			maxDeltaMs = currentDeltaMs -- 109
			maxDeltaFrame = frame -- 110
		end -- 110
		if currentDeltaMs > 100 then -- 110
			freezeCount = freezeCount + 1 -- 112
		end -- 112
		if state == "Ready" then -- 112
			postReadyFrames = postReadyFrames - 1 -- 113
		end -- 113
	end -- 113
	if state == "Waiting" then -- 113
		autoStartFrames = autoStartFrames - 1 -- 116
		if autoStartFrames <= 0 then -- 116
			startAsyncLoad() -- 117
		end -- 117
	end -- 117
	if model then -- 117
		model.angleY = model.angleY + App.deltaTime * 20 -- 119
	end -- 119
	local ____App_visualSize_0 = App.visualSize -- 121
	local width = ____App_visualSize_0.width -- 121
	ImGui.SetNextWindowPos( -- 122
		Vec2(width - 16, 16), -- 122
		"FirstUseEver", -- 122
		Vec2(1, 0) -- 122
	) -- 122
	ImGui.SetNextWindowSize( -- 123
		Vec2(430, 0), -- 123
		"FirstUseEver" -- 123
	) -- 123
	ImGui.SetNextWindowBgAlpha(0.88) -- 124
	ImGui.Begin( -- 125
		"Model3D Async Load Probe", -- 125
		windowFlags, -- 125
		function() -- 125
			ImGui.Text((("Heartbeat: " .. spinner[math.floor(frame / 8) % #spinner + 1]) .. "  frame=") .. tostring(frame)) -- 126
			ImGui.Text("State: " .. state) -- 127
			ImGui.Separator() -- 128
			ImGui.Text(("Current frame: " .. __TS__NumberToFixed(currentDeltaMs, 1)) .. " ms") -- 129
			ImGui.Text(("Max load + 2s: " .. __TS__NumberToFixed(maxDeltaMs, 1)) .. " ms") -- 130
			ImGui.Text("Max frame: " .. tostring(maxDeltaFrame)) -- 131
			ImGui.Text("Frames over 100 ms: " .. tostring(freezeCount)) -- 132
			ImGui.Text(("Async total: " .. __TS__NumberToFixed(loadSeconds, 3)) .. " s") -- 133
			ImGui.Text("Callback frame: " .. tostring(callbackFrame)) -- 134
			ImGui.Text(("Cached Model3D(): " .. __TS__NumberToFixed(instantiateSeconds, 6)) .. " s") -- 135
			ImGui.Separator() -- 136
			ImGui.TextWrapped("The heartbeat must keep moving during CPU parsing. A pause immediately before Ready is GPU finalize on the main thread.") -- 137
			if ImGui.Button( -- 137
				state == "Loading" and "Loading..." or "Unload + Load Async", -- 138
				Vec2(210, 32) -- 138
			) then -- 138
				startAsyncLoad() -- 139
			end -- 139
		end -- 125
	) -- 125
	return false -- 142
end) -- 104
return ____exports -- 104