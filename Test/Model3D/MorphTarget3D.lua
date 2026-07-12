-- [ts]: MorphTarget3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 5
local Content = ____Dora.Content -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Vec2 = ____Dora.Vec2 -- 10
local Vec3 = ____Dora.Vec3 -- 11
local threadLoop = ____Dora.threadLoop -- 12
local ImGui = require("ImGui") -- 15
local output = "/tmp/dora-3d-morph-target" -- 17
local view = Director.entry -- 18
local camera = Camera3D() -- 19
camera:lookAt( -- 20
	Vec3(2.5, 2, 5), -- 20
	Vec3(0.5, 0.5, 0) -- 20
) -- 20
Director:pushCamera(camera) -- 21
view:setEnvironmentMap("") -- 22
view:setEnvironmentIntensity(0.15, 0, 1) -- 23
view.showAABB = true -- 24
local light = DirectionalLight3D() -- 26
light.color = Color3(16777215) -- 27
light.intensity = 4 -- 28
light.angleX = -40 -- 29
light.angleY = 30 -- 30
view:addChild(light) -- 31
local model = Model3D("Test/Model3D/Assets/Model/SimpleMorph/SimpleMorph.gltf") -- 33
view:addChild(model) -- 34
local animationCount = model.animationCount -- 35
local duration = model:play("", true) -- 36
local elapsed = 0 -- 38
local minWidth = math.huge -- 39
local maxWidth = 0 -- 40
local minHeight = math.huge -- 41
local maxHeight = 0 -- 42
local samples = 0 -- 43
local status = "Sampling" -- 44
local screenshot = "" -- 45
local completed = false -- 46
local captureDelay = -1 -- 47
print("MORPH_TARGET3D_READY") -- 49
threadLoop(function() -- 50
	elapsed = elapsed + App.deltaTime -- 51
	local min = model:getLocalBoundsMin() -- 52
	local max = model:getLocalBoundsMax() -- 53
	local width = max.x - min.x -- 54
	local height = max.y - min.y -- 55
	if width > 0 and height > 0 then -- 55
		minWidth = math.min(minWidth, width) -- 57
		maxWidth = math.max(maxWidth, width) -- 58
		minHeight = math.min(minHeight, height) -- 59
		maxHeight = math.max(maxHeight, height) -- 60
		samples = samples + 1 -- 61
	end -- 61
	if not completed and elapsed >= math.max(3, duration * 1.25) then -- 61
		completed = true -- 65
		local widthDelta = maxWidth - minWidth -- 66
		local heightDelta = maxHeight - minHeight -- 67
		status = animationCount > 0 and duration > 0 and samples > 30 and (widthDelta > 0.05 or heightDelta > 0.05) and "PASS" or "FAIL" -- 68
		screenshot = App:saveScreenshot(output .. "/morph-target") -- 71
		captureDelay = 0 -- 72
	end -- 72
	if not completed and elapsed > 12 then -- 72
		completed = true -- 76
		status = "FAIL" -- 77
		screenshot = App:saveScreenshot(output .. "/morph-target") -- 78
		captureDelay = 0 -- 79
	end -- 79
	if captureDelay >= 0 then -- 79
		captureDelay = captureDelay + App.deltaTime -- 83
		if captureDelay >= 2 then -- 83
			captureDelay = -1 -- 85
			local summary = (((((((((((((((("MORPH_TARGET3D_SUMMARY status=" .. status) .. " animations=") .. tostring(animationCount)) .. " duration=") .. __TS__NumberToFixed(duration, 3)) .. " samples=") .. tostring(samples)) .. " width=") .. __TS__NumberToFixed(minWidth, 3)) .. "..") .. __TS__NumberToFixed(maxWidth, 3)) .. " height=") .. __TS__NumberToFixed(minHeight, 3)) .. "..") .. __TS__NumberToFixed(maxHeight, 3)) .. " screenshot=") .. screenshot -- 86
			Content:save(output .. "/result.txt", summary) -- 87
			print(summary) -- 88
		end -- 88
	end -- 88
	ImGui.SetNextWindowPos( -- 92
		Vec2(12, 12), -- 92
		"Always" -- 92
	) -- 92
	ImGui.SetNextWindowSize( -- 93
		Vec2(390, 0), -- 93
		"Always" -- 93
	) -- 93
	ImGui.SetNextWindowBgAlpha(0.78) -- 94
	ImGui.Begin( -- 95
		"glTF Morph Target", -- 95
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 95
		function() -- 95
			ImGui.Text("State: " .. status) -- 96
			ImGui.Text("Animations: " .. tostring(animationCount)) -- 97
			ImGui.Text(("Duration: " .. __TS__NumberToFixed(duration, 3)) .. "s") -- 98
			ImGui.Text((("Width range: " .. __TS__NumberToFixed(minWidth, 3)) .. " .. ") .. __TS__NumberToFixed(maxWidth, 3)) -- 99
			ImGui.Text((("Height range: " .. __TS__NumberToFixed(minHeight, 3)) .. " .. ") .. __TS__NumberToFixed(maxHeight, 3)) -- 100
			ImGui.Text("Samples: " .. tostring(samples)) -- 101
		end -- 95
	) -- 95
	return false -- 103
end) -- 50
return ____exports -- 50