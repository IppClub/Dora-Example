-- [ts]: ModelQuery3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
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
local Node3D = ____Dora.Node3D -- 10
local Vec2 = ____Dora.Vec2 -- 11
local Vec3 = ____Dora.Vec3 -- 12
local threadLoop = ____Dora.threadLoop -- 13
local ImGui = require("ImGui") -- 16
local view = Director.entry -- 18
local camera = Camera3D() -- 19
camera:lookAt( -- 20
	Vec3(3.5, 2.5, 7), -- 20
	Vec3(0, 1.2, 0) -- 20
) -- 20
Director:pushCamera(camera) -- 21
view:setEnvironmentMap("") -- 22
view:setEnvironmentIntensity(0.2, 0, 1) -- 23
view.showAABB = true -- 24
local light = DirectionalLight3D() -- 26
light.color = Color3(16777215) -- 27
light.intensity = 4 -- 28
light.angleX = -35 -- 29
light.angleY = 25 -- 30
view:addChild(light) -- 31
local fox = Model3D("Test/Model3D/Assets/Model/Fox.glb") -- 33
fox.scale = Vec3(0.02, 0.02, 0.02) -- 34
view:addChild(fox) -- 35
local animationNames = {} -- 37
do -- 37
	local i = 0 -- 38
	while i < fox.animationCount do -- 38
		animationNames[#animationNames + 1] = fox:getAnimationName(i) -- 39
		i = i + 1 -- 38
	end -- 38
end -- 38
local attachment = Node3D() -- 42
local nodeName = "b_Head_05" -- 43
local hasHead = fox:hasNode(nodeName) -- 44
local attached = fox:attachToNode(nodeName, attachment) -- 45
local attachmentStart = attachment:convertToWorldSpace(Vec3(0, 0, 0)) -- 46
local localMin = fox:getLocalBoundsMin() -- 48
local localMax = fox:getLocalBoundsMax() -- 49
local worldMin = fox:getWorldBoundsMin() -- 50
local worldMax = fox:getWorldBoundsMax() -- 51
local boundsValid = localMax.x > localMin.x and localMax.y > localMin.y and localMax.z > localMin.z and worldMax.x > worldMin.x and worldMax.y > worldMin.y and worldMax.z > worldMin.z -- 52
fox:play("Run", true) -- 59
local elapsed = 0 -- 61
local status = "Pending" -- 62
local attachmentDelta = 0 -- 63
local verified = false -- 64
threadLoop(function() -- 65
	elapsed = elapsed + App.deltaTime -- 66
	if not verified and elapsed >= 2 then -- 66
		verified = true -- 68
		local current = attachment:convertToWorldSpace(Vec3(0, 0, 0)) -- 69
		local dx = current.x - attachmentStart.x -- 70
		local dy = current.y - attachmentStart.y -- 71
		local dz = current.z - attachmentStart.z -- 72
		attachmentDelta = math.sqrt(dx * dx + dy * dy + dz * dz) -- 73
		local passed = #animationNames == 3 and __TS__ArrayIndexOf(animationNames, "Run") >= 0 and hasHead and attached and boundsValid and attachmentDelta > 0.001 -- 74
		status = passed and "PASS" or "FAIL" -- 80
		local screenshot = App:saveScreenshot("/tmp/dora-3d-model-query/model-query-runtime") -- 81
		local summary = (((((((((((((((((((((((("MODEL_QUERY_SUMMARY status=" .. status) .. " animations=") .. table.concat(animationNames, ",")) .. " hasHead=") .. tostring(hasHead)) .. " attached=") .. tostring(attached)) .. " bounds=") .. tostring(boundsValid)) .. " attachmentDelta=") .. __TS__NumberToFixed(attachmentDelta, 4)) .. " localMin=") .. __TS__NumberToFixed(localMin.x, 2)) .. ",") .. __TS__NumberToFixed(localMin.y, 2)) .. ",") .. __TS__NumberToFixed(localMin.z, 2)) .. " localMax=") .. __TS__NumberToFixed(localMax.x, 2)) .. ",") .. __TS__NumberToFixed(localMax.y, 2)) .. ",") .. __TS__NumberToFixed(localMax.z, 2)) .. " screenshot=") .. screenshot -- 82
		Content:save("/tmp/dora-3d-model-query/summary.txt", summary) -- 83
		print(summary) -- 84
	end -- 84
	ImGui.SetNextWindowPos( -- 87
		Vec2(12, 12), -- 87
		"Always" -- 87
	) -- 87
	ImGui.SetNextWindowSize( -- 88
		Vec2(440, 0), -- 88
		"Always" -- 88
	) -- 88
	ImGui.SetNextWindowBgAlpha(0.8) -- 89
	ImGui.Begin( -- 90
		"Model3D Query", -- 90
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 90
		function() -- 90
			ImGui.Text((("Animations (" .. tostring(#animationNames)) .. "): ") .. table.concat(animationNames, ", ")) -- 91
			ImGui.Text((("Node " .. nodeName) .. ": ") .. (hasHead and "Found" or "Missing")) -- 92
			ImGui.Text("Attachment: " .. (attached and "Attached" or "Failed")) -- 93
			ImGui.Text("Attachment delta: " .. __TS__NumberToFixed(attachmentDelta, 4)) -- 94
			ImGui.Text("Local bounds valid: " .. (boundsValid and "true" or "false")) -- 95
			ImGui.Text("Verification: " .. status) -- 96
		end -- 90
	) -- 90
	return false -- 98
end) -- 65
return ____exports -- 65