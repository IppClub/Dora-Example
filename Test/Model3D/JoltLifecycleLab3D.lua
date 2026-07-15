-- [ts]: JoltLifecycleLab3D.ts
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 7
local Constraint3D = ____Dora.Constraint3D -- 8
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 10
local Director = ____Dora.Director -- 11
local Model3D = ____Dora.Model3D -- 12
local Node3D = ____Dora.Node3D -- 13
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 14
local Vec2 = ____Dora.Vec2 -- 15
local Vec3 = ____Dora.Vec3 -- 16
local threadLoop = ____Dora.threadLoop -- 17
local ImGui = require("ImGui") -- 20
local view = Director.entry -- 22
local camera = Camera3D() -- 23
camera:lookAt( -- 24
	Vec3(7, 5, 11), -- 24
	Vec3(0, 2, 0) -- 24
) -- 24
Director:pushCamera(camera) -- 25
view:setEnvironmentMap("") -- 26
view:setEnvironmentIntensity(0, 0, 1) -- 27
local light = DirectionalLight3D() -- 29
light.color = Color3(16777215) -- 30
light.intensity = 5 -- 31
light.angleX = -40 -- 32
light.angleY = 30 -- 33
view:addChild(light) -- 34
local world = PhysicsWorld3D() -- 36
view:addChild(world) -- 37
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 39
view:addChild(floorVisual) -- 40
local floorNode = Node3D() -- 41
floorNode.position = Vec3(0, -0.5, 0) -- 42
view:addChild(floorNode) -- 43
makeBoxBody3D( -- 44
	world, -- 44
	floorNode, -- 44
	Vec3(7, 0.5, 4), -- 44
	PhysicsWorld3D.Static -- 44
) -- 44
local anchorNode = Node3D() -- 46
anchorNode.position = Vec3(0, 4.5, 0) -- 47
view:addChild(anchorNode) -- 48
local anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 49
anchorModel.scale = Vec3(0.3, 0.3, 0.3) -- 50
anchorNode:addChild(anchorModel) -- 51
local anchorBody = makeBoxBody3D( -- 52
	world, -- 52
	anchorNode, -- 52
	Vec3(0.2, 0.2, 0.2), -- 52
	PhysicsWorld3D.Static -- 52
) -- 52
local actorNode = Node3D() -- 54
view:addChild(actorNode) -- 55
local actorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 56
actorModel.scale = Vec3(0.72, 0.72, 0.72) -- 57
actorModel.position = Vec3(0, -0.4, 0) -- 58
actorNode:addChild(actorModel) -- 59
local actorBody -- 61
local actorConstraint -- 62
local actorGeneration = 0 -- 63
local bodyCascadePass = false -- 64
local worldCleanupPass = false -- 65
local stressRunning = false -- 66
local stressTarget = 0 -- 67
local stressCycles = 0 -- 68
local stressFailures = 0 -- 69
local lastCharacterEmpty = false -- 70
local physicsDebug = false -- 71
local function rebuildActor() -- 73
	if actorGeneration > 0 then -- 73
		actorConstraint:destroy() -- 75
		actorBody:removeChild(actorNode, false) -- 76
		actorBody:removeFromParent(true) -- 77
		view:addChild(actorNode) -- 78
	end -- 78
	actorGeneration = actorGeneration + 1 -- 80
	actorNode.position = Vec3(1.8, 2.2, 0) -- 81
	actorNode.angles = Vec3(0, 0, 0) -- 82
	actorBody = makeBoxBody3D( -- 83
		world, -- 83
		actorNode, -- 83
		Vec3(0.6, 0.55, 0.6) -- 83
	) -- 83
	actorConstraint = Constraint3D:hinge( -- 84
		anchorBody, -- 85
		actorBody, -- 86
		anchorBody.position, -- 87
		Vec3(0, 0, 1), -- 88
		-85, -- 88
		85 -- 90
	) -- 90
end -- 73
local function destroyBodyCascade() -- 94
	actorBody:removeFromParent(true) -- 95
	bodyCascadePass = actorBody.world == nil and actorConstraint.world == nil and actorConstraint.firstBody == nil -- 96
end -- 94
local function runWorldCleanupCycle() -- 101
	local cycleWorld = PhysicsWorld3D() -- 102
	view:addChild(cycleWorld) -- 103
	local firstNode = Node3D() -- 104
	firstNode.position = Vec3(0, -20, 0) -- 105
	view:addChild(firstNode) -- 106
	local secondNode = Node3D() -- 107
	secondNode.position = Vec3(1, -20, 0) -- 108
	view:addChild(secondNode) -- 109
	local characterNode = Node3D() -- 110
	characterNode.position = Vec3(0, -20, 2) -- 111
	view:addChild(characterNode) -- 112
	local first = makeBoxBody3D( -- 114
		cycleWorld, -- 114
		firstNode, -- 114
		Vec3(0.2, 0.2, 0.2), -- 114
		PhysicsWorld3D.Static -- 114
	) -- 114
	local second = makeSphereBody3D(cycleWorld, secondNode, 0.2) -- 115
	local constraint = Constraint3D:fixed( -- 116
		first, -- 116
		second, -- 116
		Vec3(0.5, -20, 0) -- 116
	) -- 116
	local character = cycleWorld:createCharacter(characterNode, 0.45, 0.25) -- 117
	cycleWorld:removeFromParent(true) -- 119
	worldCleanupPass = first.world == nil and second.world == nil and constraint.world == nil and character.world == nil -- 120
	lastCharacterEmpty = character.node == nil -- 124
	if not worldCleanupPass or not lastCharacterEmpty then -- 124
		stressFailures = stressFailures + 1 -- 125
	end -- 125
	stressCycles = stressCycles + 1 -- 126
	firstNode:removeFromParent(true) -- 127
	secondNode:removeFromParent(true) -- 128
	characterNode:removeFromParent(true) -- 129
end -- 101
local function beginStress(count) -- 132
	stressTarget = stressCycles + count -- 133
	stressRunning = true -- 134
end -- 132
rebuildActor() -- 137
runWorldCleanupCycle() -- 138
print("JOLT_LIFECYCLE_LAB_READY") -- 139
threadLoop(function() -- 141
	if stressRunning then -- 141
		do -- 141
			local i = 0 -- 143
			while i < 4 and stressCycles < stressTarget do -- 143
				runWorldCleanupCycle() -- 143
				i = i + 1 -- 143
			end -- 143
		end -- 143
		if stressCycles >= stressTarget then -- 143
			stressRunning = false -- 144
		end -- 144
	end -- 144
	ImGui.SetNextWindowPos( -- 147
		Vec2(12, 12), -- 147
		"Always" -- 147
	) -- 147
	ImGui.SetNextWindowSize( -- 148
		Vec2(410, 0), -- 148
		"Always" -- 148
	) -- 148
	ImGui.SetNextWindowBgAlpha(0.82) -- 149
	ImGui.Begin( -- 150
		"JOLT Lifecycle Lab", -- 150
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 150
		function() -- 150
			ImGui.Text("Visible generation: " .. tostring(actorGeneration)) -- 151
			ImGui.Text("Body cascade cleanup: " .. tostring(bodyCascadePass)) -- 152
			ImGui.Text("World cleanup: " .. tostring(worldCleanupPass)) -- 153
			ImGui.Text("Character cleanup: " .. tostring(lastCharacterEmpty)) -- 154
			ImGui.Text((("Stress cycles / failures: " .. tostring(stressCycles)) .. " / ") .. tostring(stressFailures)) -- 155
			ImGui.Text("Stress state: " .. (stressRunning and "Running" or "Idle")) -- 156
			local changed = false -- 157
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 158
			if changed then -- 158
				world.showDebug = physicsDebug -- 159
			end -- 159
			if ImGui.Button( -- 159
				"Destroy Body", -- 161
				Vec2(185, 30) -- 161
			) then -- 161
				destroyBodyCascade() -- 161
			end -- 161
			ImGui.SameLine() -- 162
			if ImGui.Button( -- 162
				"Rebuild Actor", -- 163
				Vec2(185, 30) -- 163
			) then -- 163
				rebuildActor() -- 163
			end -- 163
			if ImGui.Button( -- 163
				"World Cycle", -- 165
				Vec2(120, 30) -- 165
			) then -- 165
				runWorldCleanupCycle() -- 165
			end -- 165
			ImGui.SameLine() -- 166
			if ImGui.Button( -- 166
				"Stress 100", -- 167
				Vec2(120, 30) -- 167
			) then -- 167
				beginStress(100) -- 167
			end -- 167
			ImGui.SameLine() -- 168
			if ImGui.Button( -- 168
				"Stress 1000", -- 169
				Vec2(120, 30) -- 169
			) then -- 169
				beginStress(1000) -- 169
			end -- 169
		end -- 150
	) -- 150
	return false -- 171
end) -- 141
return ____exports -- 141