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
		actorBody:removeFromParent(true) -- 76
	end -- 76
	actorGeneration = actorGeneration + 1 -- 78
	actorNode.position = Vec3(1.8, 2.2, 0) -- 79
	actorNode.angles = Vec3(0, 0, 0) -- 80
	actorBody = makeBoxBody3D( -- 81
		world, -- 81
		actorNode, -- 81
		Vec3(0.6, 0.55, 0.6) -- 81
	) -- 81
	actorConstraint = Constraint3D:hinge( -- 82
		anchorBody, -- 83
		actorBody, -- 84
		anchorNode.position, -- 85
		Vec3(0, 0, 1), -- 86
		-85, -- 86
		85 -- 88
	) -- 88
end -- 73
local function destroyBodyCascade() -- 92
	actorBody:removeFromParent(true) -- 93
	bodyCascadePass = actorBody.world == nil and actorConstraint.world == nil and actorConstraint.firstBody == nil -- 94
end -- 92
local function runWorldCleanupCycle() -- 99
	local cycleWorld = PhysicsWorld3D() -- 100
	view:addChild(cycleWorld) -- 101
	local firstNode = Node3D() -- 102
	firstNode.position = Vec3(0, -20, 0) -- 103
	view:addChild(firstNode) -- 104
	local secondNode = Node3D() -- 105
	secondNode.position = Vec3(1, -20, 0) -- 106
	view:addChild(secondNode) -- 107
	local characterNode = Node3D() -- 108
	characterNode.position = Vec3(0, -20, 2) -- 109
	view:addChild(characterNode) -- 110
	local first = makeBoxBody3D( -- 112
		cycleWorld, -- 112
		firstNode, -- 112
		Vec3(0.2, 0.2, 0.2), -- 112
		PhysicsWorld3D.Static -- 112
	) -- 112
	local second = makeSphereBody3D(cycleWorld, secondNode, 0.2) -- 113
	local constraint = Constraint3D:fixed( -- 114
		first, -- 114
		second, -- 114
		Vec3(0.5, -20, 0) -- 114
	) -- 114
	local character = cycleWorld:createCharacter(characterNode, 0.45, 0.25) -- 115
	cycleWorld:removeFromParent(true) -- 117
	worldCleanupPass = first.world == nil and second.world == nil and constraint.world == nil and character.world == nil -- 118
	lastCharacterEmpty = character.node == nil -- 122
	if not worldCleanupPass or not lastCharacterEmpty then -- 122
		stressFailures = stressFailures + 1 -- 123
	end -- 123
	stressCycles = stressCycles + 1 -- 124
	firstNode:removeFromParent(true) -- 125
	secondNode:removeFromParent(true) -- 126
	characterNode:removeFromParent(true) -- 127
end -- 99
local function beginStress(count) -- 130
	stressTarget = stressCycles + count -- 131
	stressRunning = true -- 132
end -- 130
rebuildActor() -- 135
runWorldCleanupCycle() -- 136
print("JOLT_LIFECYCLE_LAB_READY") -- 137
threadLoop(function() -- 139
	if stressRunning then -- 139
		do -- 139
			local i = 0 -- 141
			while i < 4 and stressCycles < stressTarget do -- 141
				runWorldCleanupCycle() -- 141
				i = i + 1 -- 141
			end -- 141
		end -- 141
		if stressCycles >= stressTarget then -- 141
			stressRunning = false -- 142
		end -- 142
	end -- 142
	ImGui.SetNextWindowPos( -- 145
		Vec2(12, 12), -- 145
		"Always" -- 145
	) -- 145
	ImGui.SetNextWindowSize( -- 146
		Vec2(410, 0), -- 146
		"Always" -- 146
	) -- 146
	ImGui.SetNextWindowBgAlpha(0.82) -- 147
	ImGui.Begin( -- 148
		"JOLT Lifecycle Lab", -- 148
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 148
		function() -- 148
			ImGui.Text("Visible generation: " .. tostring(actorGeneration)) -- 149
			ImGui.Text("Body cascade cleanup: " .. tostring(bodyCascadePass)) -- 150
			ImGui.Text("World cleanup: " .. tostring(worldCleanupPass)) -- 151
			ImGui.Text("Character cleanup: " .. tostring(lastCharacterEmpty)) -- 152
			ImGui.Text((("Stress cycles / failures: " .. tostring(stressCycles)) .. " / ") .. tostring(stressFailures)) -- 153
			ImGui.Text("Stress state: " .. (stressRunning and "Running" or "Idle")) -- 154
			local changed = false -- 155
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 156
			if changed then -- 156
				world.showDebug = physicsDebug -- 157
			end -- 157
			if ImGui.Button( -- 157
				"Destroy Body", -- 159
				Vec2(185, 30) -- 159
			) then -- 159
				destroyBodyCascade() -- 159
			end -- 159
			ImGui.SameLine() -- 160
			if ImGui.Button( -- 160
				"Rebuild Actor", -- 161
				Vec2(185, 30) -- 161
			) then -- 161
				rebuildActor() -- 161
			end -- 161
			if ImGui.Button( -- 161
				"World Cycle", -- 163
				Vec2(120, 30) -- 163
			) then -- 163
				runWorldCleanupCycle() -- 163
			end -- 163
			ImGui.SameLine() -- 164
			if ImGui.Button( -- 164
				"Stress 100", -- 165
				Vec2(120, 30) -- 165
			) then -- 165
				beginStress(100) -- 165
			end -- 165
			ImGui.SameLine() -- 166
			if ImGui.Button( -- 166
				"Stress 1000", -- 167
				Vec2(120, 30) -- 167
			) then -- 167
				beginStress(1000) -- 167
			end -- 167
		end -- 148
	) -- 148
	return false -- 169
end) -- 139
return ____exports -- 139