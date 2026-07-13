-- [ts]: Constraint3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local Constraint3D = ____Dora.Constraint3D -- 7
local Content = ____Dora.Content -- 8
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 9
local Director = ____Dora.Director -- 10
local Model3D = ____Dora.Model3D -- 11
local Node3D = ____Dora.Node3D -- 12
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 13
local Vec2 = ____Dora.Vec2 -- 14
local Vec3 = ____Dora.Vec3 -- 15
local threadLoop = ____Dora.threadLoop -- 16
local ImGui = require("ImGui") -- 19
local output = "/tmp/dora-3d-constraint" -- 21
local view = Director.entry -- 22
local camera = Camera3D() -- 23
camera:lookAt( -- 24
	Vec3(8, 5.5, 10), -- 24
	Vec3(0, 2.5, 0) -- 24
) -- 24
Director:pushCamera(camera) -- 25
view:setEnvironmentMap("") -- 26
view:setEnvironmentIntensity(0, 0, 1) -- 27
local light = DirectionalLight3D() -- 29
light.color = Color3(16777215) -- 30
light.intensity = 6 -- 31
light.angleX = -45 -- 32
light.angleY = 25 -- 33
view:addChild(light) -- 34
local world = PhysicsWorld3D() -- 36
view:addChild(world) -- 37
local function vecDistance(a, b) -- 39
	local x = a.x - b.x -- 40
	local y = a.y - b.y -- 41
	local z = a.z - b.z -- 42
	return math.sqrt(x * x + y * y + z * z) -- 43
end -- 39
local function addDuck(position, scale) -- 46
	if scale == nil then -- 46
		scale = 0.55 -- 46
	end -- 46
	local node = Node3D() -- 47
	node.position = position -- 48
	view:addChild(node) -- 49
	local model = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 50
	model.scale = Vec3(scale, scale, scale) -- 51
	model.position = Vec3(0, -0.25, 0) -- 52
	node:addChild(model) -- 53
	return node -- 54
end -- 46
local fixedAnchorNode = addDuck( -- 57
	Vec3(-4, 3.4, 0), -- 57
	0.3 -- 57
) -- 57
local fixedNode = addDuck(Vec3(-4, 2, 0)) -- 58
local fixedAnchorBody = makeBoxBody3D( -- 59
	world, -- 59
	fixedAnchorNode, -- 59
	Vec3(0.2, 0.2, 0.2), -- 59
	PhysicsWorld3D.Static -- 59
) -- 59
local fixedBody = makeBoxBody3D( -- 60
	world, -- 60
	fixedNode, -- 60
	Vec3(0.45, 0.45, 0.45) -- 60
) -- 60
local fixed = Constraint3D:fixed( -- 61
	fixedAnchorBody, -- 61
	fixedBody, -- 61
	Vec3(-4, 2.7, 0) -- 61
) -- 61
local distanceAnchorNode = addDuck( -- 63
	Vec3(0, 4.2, 0), -- 63
	0.3 -- 63
) -- 63
local distanceNode = addDuck(Vec3(0, 2.2, 0)) -- 64
local distanceAnchorBody = makeBoxBody3D( -- 65
	world, -- 65
	distanceAnchorNode, -- 65
	Vec3(0.2, 0.2, 0.2), -- 65
	PhysicsWorld3D.Static -- 65
) -- 65
local distanceBody = makeSphereBody3D(world, distanceNode, 0.45) -- 66
local distance = Constraint3D:distance( -- 67
	distanceAnchorBody, -- 68
	distanceBody, -- 69
	distanceAnchorBody.position, -- 70
	distanceBody.position, -- 71
	2, -- 72
	2 -- 73
) -- 73
local hingeAnchorNode = addDuck( -- 76
	Vec3(4, 4.2, 0), -- 76
	0.3 -- 76
) -- 76
local hingeStart = Vec3(4.7, 3.25, 0) -- 77
local hingeNode = addDuck(hingeStart) -- 78
local hingeAnchorBody = makeBoxBody3D( -- 79
	world, -- 79
	hingeAnchorNode, -- 79
	Vec3(0.2, 0.2, 0.2), -- 79
	PhysicsWorld3D.Static -- 79
) -- 79
local hingeBody = makeBoxBody3D( -- 80
	world, -- 80
	hingeNode, -- 80
	Vec3(0.45, 0.45, 0.45) -- 80
) -- 80
local hinge = Constraint3D:hinge( -- 81
	hingeAnchorBody, -- 82
	hingeBody, -- 83
	hingeAnchorBody.position, -- 84
	Vec3(0, 0, 1), -- 85
	-80, -- 85
	80 -- 87
) -- 87
local disposableFirstNode = Node3D() -- 90
disposableFirstNode.position = Vec3(0, -10, 0) -- 91
view:addChild(disposableFirstNode) -- 92
local disposableSecondNode = Node3D() -- 93
disposableSecondNode.position = Vec3(1, -10, 0) -- 94
view:addChild(disposableSecondNode) -- 95
local disposableFirstBody = makeBoxBody3D( -- 96
	world, -- 96
	disposableFirstNode, -- 96
	Vec3(0.1, 0.1, 0.1), -- 96
	PhysicsWorld3D.Static -- 96
) -- 96
local disposableSecondBody = makeBoxBody3D( -- 97
	world, -- 97
	disposableSecondNode, -- 97
	Vec3(0.1, 0.1, 0.1), -- 97
	PhysicsWorld3D.Static -- 97
) -- 97
local disposable = Constraint3D:fixed( -- 98
	disposableFirstBody, -- 98
	disposableSecondBody, -- 98
	Vec3(0.5, -10, 0) -- 98
) -- 98
disposable:destroy() -- 99
local destroyPass = disposable.world == nil and disposable.firstBody == nil -- 100
local elapsed = 0 -- 102
local maxHingeMovement = 0 -- 103
local phase = "Simulating" -- 104
local completed = false -- 105
local captureDelay = -1 -- 106
local screenshot = "" -- 107
local measuredFixedDistance = 0 -- 108
local measuredRopeDistance = 0 -- 109
local endpointRefs = fixed.world == world and fixed.firstBody == fixedAnchorBody and fixed.secondBody == fixedBody -- 110
print("CONSTRAINT3D_READY") -- 113
threadLoop(function() -- 114
	elapsed = elapsed + App.deltaTime -- 115
	maxHingeMovement = math.max( -- 116
		maxHingeMovement, -- 116
		vecDistance(hingeBody.position, hingeStart) -- 116
	) -- 116
	if not completed and elapsed >= 3 then -- 116
		local fixedDistance = vecDistance(fixedBody.position, fixedAnchorBody.position) -- 119
		local ropeDistance = vecDistance(distanceBody.position, distanceAnchorBody.position) -- 120
		measuredFixedDistance = fixedDistance -- 121
		measuredRopeDistance = ropeDistance -- 122
		local hingeRadius = vecDistance(hingeBody.position, hingeAnchorBody.position) -- 123
		local expectedHingeRadius = vecDistance(hingeStart, hingeAnchorBody.position) -- 124
		local fixedPass = math.abs(fixedDistance - 1.4) < 0.12 -- 125
		local distancePass = math.abs(ropeDistance - 2) < 0.08 -- 126
		local hingePass = math.abs(hingeRadius - expectedHingeRadius) < 0.1 and math.abs(hingeNode.position.z) < 0.03 and maxHingeMovement > 0.15 -- 127
		phase = fixedPass and distancePass and hingePass and endpointRefs and destroyPass and "PASS" or "FAIL" -- 132
		completed = true -- 133
		screenshot = App:saveScreenshot(output .. "/constraint-3d") -- 134
		captureDelay = 0 -- 135
	end -- 135
	if captureDelay >= 0 then -- 135
		captureDelay = captureDelay + App.deltaTime -- 139
		if captureDelay >= 2 then -- 139
			captureDelay = -1 -- 141
			local summary = (((((((((("CONSTRAINT3D_SUMMARY status=" .. phase) .. " fixed=") .. __TS__NumberToFixed(measuredFixedDistance, 3)) .. " distance=") .. __TS__NumberToFixed(measuredRopeDistance, 3)) .. " hingeMove=") .. __TS__NumberToFixed(maxHingeMovement, 3)) .. " refs=") .. tostring(endpointRefs)) .. " screenshot=") .. screenshot -- 142
			Content:save(output .. "/result.txt", summary) -- 143
			print(summary) -- 144
		end -- 144
	end -- 144
	ImGui.SetNextWindowPos( -- 148
		Vec2(12, 12), -- 148
		"Always" -- 148
	) -- 148
	ImGui.SetNextWindowSize( -- 149
		Vec2(390, 0), -- 149
		"Always" -- 149
	) -- 149
	ImGui.SetNextWindowBgAlpha(0.8) -- 150
	ImGui.Begin( -- 151
		"JOLT-C Constraints", -- 151
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 151
		function() -- 151
			ImGui.Text("Phase: " .. phase) -- 152
			ImGui.Text("Fixed distance: " .. __TS__NumberToFixed( -- 153
				vecDistance(fixedNode.position, fixedAnchorNode.position), -- 153
				3 -- 153
			)) -- 153
			ImGui.Text("Rope distance: " .. __TS__NumberToFixed( -- 154
				vecDistance(distanceNode.position, distanceAnchorNode.position), -- 154
				3 -- 154
			)) -- 154
			ImGui.Text("Hinge movement: " .. __TS__NumberToFixed(maxHingeMovement, 3)) -- 155
			ImGui.Text("Endpoint refs: " .. tostring(endpointRefs)) -- 156
		end -- 151
	) -- 151
	return false -- 158
end) -- 114
return ____exports -- 114