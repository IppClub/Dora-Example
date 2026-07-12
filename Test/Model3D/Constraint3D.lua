-- [ts]: Constraint3D.ts
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
local Node3D = ____Dora.Node3D -- 10
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 11
local Vec2 = ____Dora.Vec2 -- 12
local Vec3 = ____Dora.Vec3 -- 13
local threadLoop = ____Dora.threadLoop -- 14
local ImGui = require("ImGui") -- 17
local output = "/tmp/dora-3d-constraint" -- 19
local view = Director.entry -- 20
local camera = Camera3D() -- 21
camera:lookAt( -- 22
	Vec3(8, 5.5, 10), -- 22
	Vec3(0, 2.5, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("") -- 24
view:setEnvironmentIntensity(0, 0, 1) -- 25
local light = DirectionalLight3D() -- 27
light.color = Color3(16777215) -- 28
light.intensity = 6 -- 29
light.angleX = -45 -- 30
light.angleY = 25 -- 31
view:addChild(light) -- 32
local world = PhysicsWorld3D() -- 34
view:addChild(world) -- 35
local function vecDistance(a, b) -- 37
	local x = a.x - b.x -- 38
	local y = a.y - b.y -- 39
	local z = a.z - b.z -- 40
	return math.sqrt(x * x + y * y + z * z) -- 41
end -- 37
local function addDuck(position, scale) -- 44
	if scale == nil then -- 44
		scale = 0.55 -- 44
	end -- 44
	local node = Node3D() -- 45
	node.position = position -- 46
	view:addChild(node) -- 47
	local model = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 48
	model.scale = Vec3(scale, scale, scale) -- 49
	model.position = Vec3(0, -0.25, 0) -- 50
	node:addChild(model) -- 51
	return node -- 52
end -- 44
local fixedAnchorNode = addDuck( -- 55
	Vec3(-4, 3.4, 0), -- 55
	0.3 -- 55
) -- 55
local fixedNode = addDuck(Vec3(-4, 2, 0)) -- 56
local fixedAnchorBody = world:createBox( -- 57
	fixedAnchorNode, -- 57
	Vec3(0.2, 0.2, 0.2), -- 57
	PhysicsWorld3D.Static -- 57
) -- 57
local fixedBody = world:createBox( -- 58
	fixedNode, -- 58
	Vec3(0.45, 0.45, 0.45) -- 58
) -- 58
local fixed = world:createFixedConstraint( -- 59
	fixedAnchorBody, -- 59
	fixedBody, -- 59
	Vec3(-4, 2.7, 0) -- 59
) -- 59
local distanceAnchorNode = addDuck( -- 61
	Vec3(0, 4.2, 0), -- 61
	0.3 -- 61
) -- 61
local distanceNode = addDuck(Vec3(0, 2.2, 0)) -- 62
local distanceAnchorBody = world:createBox( -- 63
	distanceAnchorNode, -- 63
	Vec3(0.2, 0.2, 0.2), -- 63
	PhysicsWorld3D.Static -- 63
) -- 63
local distanceBody = world:createSphere(distanceNode, 0.45) -- 64
local distance = world:createDistanceConstraint( -- 65
	distanceAnchorBody, -- 66
	distanceBody, -- 67
	distanceAnchorNode.position, -- 68
	distanceNode.position, -- 69
	2, -- 70
	2 -- 71
) -- 71
local hingeAnchorNode = addDuck( -- 74
	Vec3(4, 4.2, 0), -- 74
	0.3 -- 74
) -- 74
local hingeStart = Vec3(4.7, 3.25, 0) -- 75
local hingeNode = addDuck(hingeStart) -- 76
local hingeAnchorBody = world:createBox( -- 77
	hingeAnchorNode, -- 77
	Vec3(0.2, 0.2, 0.2), -- 77
	PhysicsWorld3D.Static -- 77
) -- 77
local hingeBody = world:createBox( -- 78
	hingeNode, -- 78
	Vec3(0.45, 0.45, 0.45) -- 78
) -- 78
local hinge = world:createHingeConstraint( -- 79
	hingeAnchorBody, -- 80
	hingeBody, -- 81
	hingeAnchorNode.position, -- 82
	Vec3(0, 0, 1), -- 83
	-80, -- 83
	80 -- 85
) -- 85
local disposableFirstNode = Node3D() -- 88
disposableFirstNode.position = Vec3(0, -10, 0) -- 89
view:addChild(disposableFirstNode) -- 90
local disposableSecondNode = Node3D() -- 91
disposableSecondNode.position = Vec3(1, -10, 0) -- 92
view:addChild(disposableSecondNode) -- 93
local disposableFirstBody = world:createBox( -- 94
	disposableFirstNode, -- 94
	Vec3(0.1, 0.1, 0.1), -- 94
	PhysicsWorld3D.Static -- 94
) -- 94
local disposableSecondBody = world:createBox( -- 95
	disposableSecondNode, -- 95
	Vec3(0.1, 0.1, 0.1), -- 95
	PhysicsWorld3D.Static -- 95
) -- 95
local disposable = world:createFixedConstraint( -- 96
	disposableFirstBody, -- 96
	disposableSecondBody, -- 96
	Vec3(0.5, -10, 0) -- 96
) -- 96
disposable:destroy() -- 97
local destroyPass = disposable.world == nil and disposable.firstBody == nil -- 98
local elapsed = 0 -- 100
local maxHingeMovement = 0 -- 101
local phase = "Simulating" -- 102
local completed = false -- 103
local captureDelay = -1 -- 104
local screenshot = "" -- 105
local measuredFixedDistance = 0 -- 106
local measuredRopeDistance = 0 -- 107
local endpointRefs = fixed.world == world and fixed.firstBody == fixedAnchorBody and fixed.secondBody == fixedBody -- 108
print("CONSTRAINT3D_READY") -- 111
threadLoop(function() -- 112
	elapsed = elapsed + App.deltaTime -- 113
	maxHingeMovement = math.max( -- 114
		maxHingeMovement, -- 114
		vecDistance(hingeNode.position, hingeStart) -- 114
	) -- 114
	if not completed and elapsed >= 3 then -- 114
		local fixedDistance = vecDistance(fixedNode.position, fixedAnchorNode.position) -- 117
		local ropeDistance = vecDistance(distanceNode.position, distanceAnchorNode.position) -- 118
		measuredFixedDistance = fixedDistance -- 119
		measuredRopeDistance = ropeDistance -- 120
		local hingeRadius = vecDistance(hingeNode.position, hingeAnchorNode.position) -- 121
		local expectedHingeRadius = vecDistance(hingeStart, hingeAnchorNode.position) -- 122
		local fixedPass = math.abs(fixedDistance - 1.4) < 0.12 -- 123
		local distancePass = math.abs(ropeDistance - 2) < 0.08 -- 124
		local hingePass = math.abs(hingeRadius - expectedHingeRadius) < 0.1 and math.abs(hingeNode.position.z) < 0.03 and maxHingeMovement > 0.15 -- 125
		phase = fixedPass and distancePass and hingePass and endpointRefs and destroyPass and "PASS" or "FAIL" -- 130
		completed = true -- 131
		screenshot = App:saveScreenshot(output .. "/constraint-3d") -- 132
		captureDelay = 0 -- 133
	end -- 133
	if captureDelay >= 0 then -- 133
		captureDelay = captureDelay + App.deltaTime -- 137
		if captureDelay >= 2 then -- 137
			captureDelay = -1 -- 139
			local summary = (((((((((("CONSTRAINT3D_SUMMARY status=" .. phase) .. " fixed=") .. __TS__NumberToFixed(measuredFixedDistance, 3)) .. " distance=") .. __TS__NumberToFixed(measuredRopeDistance, 3)) .. " hingeMove=") .. __TS__NumberToFixed(maxHingeMovement, 3)) .. " refs=") .. tostring(endpointRefs)) .. " screenshot=") .. screenshot -- 140
			Content:save(output .. "/result.txt", summary) -- 141
			print(summary) -- 142
		end -- 142
	end -- 142
	ImGui.SetNextWindowPos( -- 146
		Vec2(12, 12), -- 146
		"Always" -- 146
	) -- 146
	ImGui.SetNextWindowSize( -- 147
		Vec2(390, 0), -- 147
		"Always" -- 147
	) -- 147
	ImGui.SetNextWindowBgAlpha(0.8) -- 148
	ImGui.Begin( -- 149
		"JOLT-C Constraints", -- 149
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 149
		function() -- 149
			ImGui.Text("Phase: " .. phase) -- 150
			ImGui.Text("Fixed distance: " .. __TS__NumberToFixed( -- 151
				vecDistance(fixedNode.position, fixedAnchorNode.position), -- 151
				3 -- 151
			)) -- 151
			ImGui.Text("Rope distance: " .. __TS__NumberToFixed( -- 152
				vecDistance(distanceNode.position, distanceAnchorNode.position), -- 152
				3 -- 152
			)) -- 152
			ImGui.Text("Hinge movement: " .. __TS__NumberToFixed(maxHingeMovement, 3)) -- 153
			ImGui.Text("Endpoint refs: " .. tostring(endpointRefs)) -- 154
		end -- 149
	) -- 149
	return false -- 156
end) -- 112
return ____exports -- 112