-- [ts]: Material3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color = ____Dora.Color -- 5
local Color3 = ____Dora.Color3 -- 6
local Content = ____Dora.Content -- 7
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Director = ____Dora.Director -- 9
local Model3D = ____Dora.Model3D -- 11
local Vec2 = ____Dora.Vec2 -- 12
local Vec3 = ____Dora.Vec3 -- 13
local threadLoop = ____Dora.threadLoop -- 14
local ImGui = require("ImGui") -- 17
local view = Director.entry -- 19
local camera = Camera3D() -- 20
camera:lookAt( -- 21
	Vec3(0, 2.2, 8), -- 21
	Vec3(0, 1, 0) -- 21
) -- 21
Director:pushCamera(camera) -- 22
view:setEnvironmentMap("") -- 23
view:setEnvironmentIntensity(0.2, 0, 1) -- 24
local light = DirectionalLight3D() -- 26
light.color = Color3(16777215) -- 27
light.intensity = 4 -- 28
light.angleX = -35 -- 29
light.angleY = 25 -- 30
view:addChild(light) -- 31
local file = "Test/Model3D/Assets/Model/Duck.glb" -- 33
local changed = Model3D(file) -- 34
changed.position = Vec3(-1.5, 0, 0) -- 35
view:addChild(changed) -- 36
local original = Model3D(file) -- 38
original.position = Vec3(1.5, 0, 0) -- 39
view:addChild(original) -- 40
local changedMaterial = changed:getMaterial(0) -- 42
local originalMaterial = original:getMaterial(0) -- 43
if not changedMaterial or not originalMaterial then -- 43
	error("Duck material slot 0 is missing") -- 45
end -- 45
local originalColor = originalMaterial.baseColor:toARGB() -- 48
local originalMetallic = originalMaterial.metallic -- 49
local originalRoughness = originalMaterial.roughness -- 50
changedMaterial.baseColor = Color(4294918208) -- 52
changedMaterial.emissive = Color3(2228224) -- 53
changedMaterial.metallic = 1 -- 54
changedMaterial.roughness = 0.15 -- 55
changedMaterial.alphaMode = 0 -- 56
changedMaterial.alphaCutoff = 0.45 -- 57
changedMaterial:clearNormalTexture() -- 58
local copyOnWriteValid = changed.materialCount == 1 and original.materialCount == 1 and changedMaterial.baseColor:toARGB() == 4294918208 and math.abs(changedMaterial.metallic - 1) < 0.001 and math.abs(changedMaterial.roughness - 0.15) < 0.001 and originalMaterial.baseColor:toARGB() == originalColor and math.abs(originalMaterial.metallic - originalMetallic) < 0.001 and math.abs(originalMaterial.roughness - originalRoughness) < 0.001 -- 60
local elapsed = 0 -- 69
local status = "Pending" -- 70
threadLoop(function() -- 71
	elapsed = elapsed + App.deltaTime -- 72
	if status == "Pending" and elapsed >= 1.5 then -- 72
		status = copyOnWriteValid and "PASS" or "FAIL" -- 74
		local screenshot = App:saveScreenshot("/tmp/dora-3d-material/material-runtime") -- 75
		local summary = (((((((((((((((("MATERIAL3D_SUMMARY status=" .. status) .. " slots=") .. tostring(changed.materialCount)) .. " changedColor=") .. tostring(changedMaterial.baseColor:toARGB())) .. " originalColor=") .. tostring(originalMaterial.baseColor:toARGB())) .. " changedMetallic=") .. __TS__NumberToFixed(changedMaterial.metallic, 2)) .. " originalMetallic=") .. __TS__NumberToFixed(originalMaterial.metallic, 2)) .. " changedRoughness=") .. __TS__NumberToFixed(changedMaterial.roughness, 2)) .. " originalRoughness=") .. __TS__NumberToFixed(originalMaterial.roughness, 2)) .. " screenshot=") .. screenshot -- 76
		Content:save("/tmp/dora-3d-material/summary.txt", summary) -- 77
		print(summary) -- 78
	end -- 78
	ImGui.SetNextWindowPos( -- 81
		Vec2(12, 12), -- 81
		"Always" -- 81
	) -- 81
	ImGui.SetNextWindowSize( -- 82
		Vec2(470, 0), -- 82
		"Always" -- 82
	) -- 82
	ImGui.SetNextWindowBgAlpha(0.8) -- 83
	ImGui.Begin( -- 84
		"Material3D Copy-on-write", -- 84
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 84
		function() -- 84
			ImGui.Text("Material slots: " .. tostring(changed.materialCount)) -- 85
			ImGui.Text((("Changed: metallic " .. __TS__NumberToFixed(changedMaterial.metallic, 2)) .. ", roughness ") .. __TS__NumberToFixed(changedMaterial.roughness, 2)) -- 86
			ImGui.Text((("Original: metallic " .. __TS__NumberToFixed(originalMaterial.metallic, 2)) .. ", roughness ") .. __TS__NumberToFixed(originalMaterial.roughness, 2)) -- 87
			ImGui.Text("Left instance changed, right instance unchanged") -- 88
			ImGui.Text("Verification: " .. status) -- 89
		end -- 84
	) -- 84
	return false -- 91
end) -- 71
return ____exports -- 71