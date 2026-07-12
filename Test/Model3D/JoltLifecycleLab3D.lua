-- [ts]: JoltLifecycleLab3D.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Director = ____Dora.Director -- 9
local Model3D = ____Dora.Model3D -- 10
local Node3D = ____Dora.Node3D -- 11
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 12
local Vec2 = ____Dora.Vec2 -- 13
local Vec3 = ____Dora.Vec3 -- 14
local threadLoop = ____Dora.threadLoop -- 15
local ImGui = require("ImGui") -- 18
local view = Director.entry -- 20
local camera = Camera3D() -- 21
camera:lookAt( -- 22
	Vec3(7, 5, 11), -- 22
	Vec3(0, 2, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("") -- 24
view:setEnvironmentIntensity(0, 0, 1) -- 25
local light = DirectionalLight3D() -- 27
light.color = Color3(16777215) -- 28
light.intensity = 5 -- 29
light.angleX = -40 -- 30
light.angleY = 30 -- 31
view:addChild(light) -- 32
local world = PhysicsWorld3D() -- 34
view:addChild(world) -- 35
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 37
view:addChild(floorVisual) -- 38
local floorNode = Node3D() -- 39
floorNode.position = Vec3(0, -0.5, 0) -- 40
view:addChild(floorNode) -- 41
world:createBox( -- 42
	floorNode, -- 42
	Vec3(7, 0.5, 4), -- 42
	PhysicsWorld3D.Static -- 42
) -- 42
local anchorNode = Node3D() -- 44
anchorNode.position = Vec3(0, 4.5, 0) -- 45
view:addChild(anchorNode) -- 46
local anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 47
anchorModel.scale = Vec3(0.3, 0.3, 0.3) -- 48
anchorNode:addChild(anchorModel) -- 49
local anchorBody = world:createBox( -- 50
	anchorNode, -- 50
	Vec3(0.2, 0.2, 0.2), -- 50
	PhysicsWorld3D.Static -- 50
) -- 50
local actorNode = Node3D() -- 52
view:addChild(actorNode) -- 53
local actorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 54
actorModel.scale = Vec3(0.72, 0.72, 0.72) -- 55
actorModel.position = Vec3(0, -0.4, 0) -- 56
actorNode:addChild(actorModel) -- 57
local actorBody -- 59
local actorConstraint -- 60
local actorGeneration = 0 -- 61
local bodyCascadePass = false -- 62
local worldCleanupPass = false -- 63
local stressRunning = false -- 64
local stressTarget = 0 -- 65
local stressCycles = 0 -- 66
local stressFailures = 0 -- 67
local lastCharacterEmpty = false -- 68
local physicsDebug = false -- 69
local function rebuildActor() -- 71
	if actorGeneration > 0 then -- 71
		actorConstraint:destroy() -- 73
		actorBody:destroy() -- 74
	end -- 74
	actorGeneration = actorGeneration + 1 -- 76
	actorNode.position = Vec3(1.8, 2.2, 0) -- 77
	actorNode.eulerAngles = Vec3(0, 0, 0) -- 78
	actorBody = world:createBox( -- 79
		actorNode, -- 79
		Vec3(0.6, 0.55, 0.6) -- 79
	) -- 79
	actorConstraint = world:createHingeConstraint( -- 80
		anchorBody, -- 81
		actorBody, -- 82
		anchorNode.position, -- 83
		Vec3(0, 0, 1), -- 84
		-85, -- 84
		85 -- 86
	) -- 86
end -- 71
local function destroyBodyCascade() -- 90
	actorBody:destroy() -- 91
	bodyCascadePass = actorBody.world == nil and actorConstraint.world == nil and actorConstraint.firstBody == nil -- 92
end -- 90
local function runWorldCleanupCycle() -- 97
	local cycleWorld = PhysicsWorld3D() -- 98
	view:addChild(cycleWorld) -- 99
	local firstNode = Node3D() -- 100
	firstNode.position = Vec3(0, -20, 0) -- 101
	view:addChild(firstNode) -- 102
	local secondNode = Node3D() -- 103
	secondNode.position = Vec3(1, -20, 0) -- 104
	view:addChild(secondNode) -- 105
	local characterNode = Node3D() -- 106
	characterNode.position = Vec3(0, -20, 2) -- 107
	view:addChild(characterNode) -- 108
	local first = cycleWorld:createBox( -- 110
		firstNode, -- 110
		Vec3(0.2, 0.2, 0.2), -- 110
		PhysicsWorld3D.Static -- 110
	) -- 110
	local second = cycleWorld:createSphere(secondNode, 0.2) -- 111
	local constraint = cycleWorld:createFixedConstraint( -- 112
		first, -- 112
		second, -- 112
		Vec3(0.5, -20, 0) -- 112
	) -- 112
	local character = cycleWorld:createCharacter(characterNode, 0.45, 0.25) -- 113
	cycleWorld:removeFromParent(true) -- 115
	worldCleanupPass = first.world == nil and second.world == nil and constraint.world == nil and character.world == nil -- 116
	lastCharacterEmpty = character.node == nil -- 120
	if not worldCleanupPass or not lastCharacterEmpty then -- 120
		stressFailures = stressFailures + 1 -- 121
	end -- 121
	stressCycles = stressCycles + 1 -- 122
	firstNode:removeFromParent(true) -- 123
	secondNode:removeFromParent(true) -- 124
	characterNode:removeFromParent(true) -- 125
end -- 97
local function beginStress(count) -- 128
	stressTarget = stressCycles + count -- 129
	stressRunning = true -- 130
end -- 128
rebuildActor() -- 133
runWorldCleanupCycle() -- 134
print("JOLT_LIFECYCLE_LAB_READY") -- 135
threadLoop(function() -- 137
	if stressRunning then -- 137
		do -- 137
			local i = 0 -- 139
			while i < 4 and stressCycles < stressTarget do -- 139
				runWorldCleanupCycle() -- 139
				i = i + 1 -- 139
			end -- 139
		end -- 139
		if stressCycles >= stressTarget then -- 139
			stressRunning = false -- 140
		end -- 140
	end -- 140
	ImGui.SetNextWindowPos( -- 143
		Vec2(12, 12), -- 143
		"Always" -- 143
	) -- 143
	ImGui.SetNextWindowSize( -- 144
		Vec2(410, 0), -- 144
		"Always" -- 144
	) -- 144
	ImGui.SetNextWindowBgAlpha(0.82) -- 145
	ImGui.Begin( -- 146
		"JOLT Lifecycle Lab", -- 146
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 146
		function() -- 146
			ImGui.Text("Visible generation: " .. tostring(actorGeneration)) -- 147
			ImGui.Text("Body cascade cleanup: " .. tostring(bodyCascadePass)) -- 148
			ImGui.Text("World cleanup: " .. tostring(worldCleanupPass)) -- 149
			ImGui.Text("Character cleanup: " .. tostring(lastCharacterEmpty)) -- 150
			ImGui.Text((("Stress cycles / failures: " .. tostring(stressCycles)) .. " / ") .. tostring(stressFailures)) -- 151
			ImGui.Text("Stress state: " .. (stressRunning and "Running" or "Idle")) -- 152
			local changed = false -- 153
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 154
			if changed then -- 154
				world.showDebug = physicsDebug -- 155
			end -- 155
			if ImGui.Button( -- 155
				"Destroy Body", -- 157
				Vec2(185, 30) -- 157
			) then -- 157
				destroyBodyCascade() -- 157
			end -- 157
			ImGui.SameLine() -- 158
			if ImGui.Button( -- 158
				"Rebuild Actor", -- 159
				Vec2(185, 30) -- 159
			) then -- 159
				rebuildActor() -- 159
			end -- 159
			if ImGui.Button( -- 159
				"World Cycle", -- 161
				Vec2(120, 30) -- 161
			) then -- 161
				runWorldCleanupCycle() -- 161
			end -- 161
			ImGui.SameLine() -- 162
			if ImGui.Button( -- 162
				"Stress 100", -- 163
				Vec2(120, 30) -- 163
			) then -- 163
				beginStress(100) -- 163
			end -- 163
			ImGui.SameLine() -- 164
			if ImGui.Button( -- 164
				"Stress 1000", -- 165
				Vec2(120, 30) -- 165
			) then -- 165
				beginStress(1000) -- 165
			end -- 165
		end -- 146
	) -- 146
	return false -- 167
end) -- 137
return ____exports -- 137