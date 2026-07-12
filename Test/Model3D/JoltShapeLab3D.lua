-- [ts]: JoltShapeLab3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Node3D = ____Dora.Node3D -- 10
local PhysicsShape3D = ____Dora.PhysicsShape3D -- 11
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 13
local Vec2 = ____Dora.Vec2 -- 14
local Vec3 = ____Dora.Vec3 -- 15
local threadLoop = ____Dora.threadLoop -- 16
local ImGui = require("ImGui") -- 19
local view = Director.entry -- 21
local camera = Camera3D() -- 22
camera:lookAt( -- 23
	Vec3(9, 6, 13), -- 23
	Vec3(0, 1.5, 0) -- 23
) -- 23
Director:pushCamera(camera) -- 24
view:setEnvironmentMap("") -- 25
view:setEnvironmentIntensity(0, 0, 1) -- 26
view.showAABB = true -- 27
local light = DirectionalLight3D() -- 29
light.color = Color3(16777215) -- 30
light.intensity = 5 -- 31
light.angleX = -45 -- 32
light.angleY = 25 -- 33
view:addChild(light) -- 34
local world = PhysicsWorld3D() -- 36
view:addChild(world) -- 37
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 39
view:addChild(floorVisual) -- 40
local floorNode = Node3D() -- 41
floorNode.position = Vec3(0, -0.5, 0) -- 42
view:addChild(floorNode) -- 43
world:createBox( -- 44
	floorNode, -- 44
	Vec3(8, 0.5, 4), -- 44
	PhysicsWorld3D.Static -- 44
) -- 44
local childBox = PhysicsShape3D:box(Vec3(0.55, 0.5, 0.55)) -- 46
local childSphere = PhysicsShape3D:sphere(0.58) -- 47
local compound = PhysicsShape3D:compound() -- 48
compound:addChild( -- 49
	childBox, -- 49
	Vec3(-0.9, 0, 0), -- 49
	Vec3(0, 0, -12) -- 49
) -- 49
compound:addChild( -- 50
	childSphere, -- 50
	Vec3(0.9, 0, 0) -- 50
) -- 50
compound:build() -- 51
local frozen = not compound:addChild( -- 52
	childBox, -- 52
	Vec3(0, 1, 0) -- 52
) -- 52
local compounds = {} -- 55
local serial = 0 -- 56
local function spawnCompound() -- 58
	serial = serial + 1 -- 59
	local node = Node3D() -- 60
	node.position = Vec3(-2.7 + serial % 3 * 0.4, 3.5 + serial * 0.45, 0) -- 61
	view:addChild(node) -- 62
	for ____, x in ipairs({-0.9, 0.9}) do -- 63
		local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 64
		duck.position = Vec3(x, -0.4, 0) -- 65
		duck.scale = Vec3(0.48, 0.48, 0.48) -- 66
		node:addChild(duck) -- 67
	end -- 67
	local body = world:createBody(node, compound, PhysicsWorld3D.Dynamic) -- 69
	compounds[#compounds + 1] = {node = node, body = body} -- 70
end -- 58
local function clearCompounds() -- 73
	while #compounds > 0 do -- 73
		local actor = table.remove(compounds) -- 75
		actor.body:destroy() -- 76
		actor.node:removeFromParent(true) -- 77
	end -- 77
end -- 73
local meshPath = "Test/Model3D/Assets/Model/Ground.gltf" -- 81
local meshNode = Node3D() -- 82
meshNode.position = Vec3(3.2, 1.2, 0) -- 83
view:addChild(meshNode) -- 84
local meshVisual = Model3D(meshPath) -- 85
meshVisual.scale = Vec3(0.55, 0.55, 0.55) -- 86
meshNode:addChild(meshVisual) -- 87
local meshShape -- 89
local meshBody -- 90
local meshState = "Not loaded" -- 91
local meshLoadTime = 0 -- 92
local cacheHit = false -- 93
local kinematicMesh = false -- 94
local moveMesh = false -- 95
local dynamicRejected = false -- 96
local elapsed = 0 -- 97
local physicsDebug = false -- 98
local function createMeshBody() -- 100
	if not meshShape then -- 100
		return -- 101
	end -- 101
	if kinematicMesh then -- 101
		kinematicMesh = false -- 103
		moveMesh = false -- 104
		meshState = "Mesh colliders must be static" -- 105
		return -- 106
	end -- 106
	if meshBody ~= nil then -- 106
		meshBody:destroy() -- 108
	end -- 108
	meshBody = world:createBody(meshNode, meshShape, PhysicsWorld3D.Static) -- 109
	meshState = meshBody ~= nil and "Static ready" or "Body creation rejected" -- 114
end -- 100
local function loadMesh() -- 117
	meshState = "Loading through Content" -- 118
	local started = App.runningTime -- 119
	PhysicsShape3D:loadMeshAsync( -- 120
		meshPath, -- 120
		function(shape) -- 120
			meshLoadTime = App.runningTime - started -- 121
			if not shape.built then -- 121
				meshState = "Cook failed" -- 123
				return -- 124
			end -- 124
			meshShape = shape -- 126
			createMeshBody() -- 127
			PhysicsShape3D:loadMeshAsync( -- 128
				meshPath, -- 128
				function(cached) -- 128
					cacheHit = cached == shape -- 129
				end -- 128
			) -- 128
		end -- 120
	) -- 120
end -- 117
local function testDynamicRejection() -- 134
	if not meshShape then -- 134
		return -- 135
	end -- 135
	local probe = Node3D() -- 136
	probe.position = Vec3(0, -20, 0) -- 137
	view:addChild(probe) -- 138
	local rejected = world:createBody(probe, meshShape, PhysicsWorld3D.Dynamic) -- 139
	dynamicRejected = rejected == nil -- 140
	if rejected ~= nil then -- 140
		rejected:destroy() -- 141
	end -- 141
	probe:removeFromParent(true) -- 142
end -- 134
do -- 134
	local i = 0 -- 145
	while i < 3 do -- 145
		spawnCompound() -- 145
		i = i + 1 -- 145
	end -- 145
end -- 145
loadMesh() -- 146
print("JOLT_SHAPE_LAB_READY") -- 147
threadLoop(function() -- 149
	elapsed = elapsed + App.deltaTime -- 150
	if moveMesh and kinematicMesh then -- 150
		meshNode.position = Vec3( -- 151
			3.2, -- 151
			1.2 + math.sin(elapsed * 1.5) * 0.7, -- 151
			0 -- 151
		) -- 151
	end -- 151
	ImGui.SetNextWindowPos( -- 153
		Vec2(12, 12), -- 153
		"Always" -- 153
	) -- 153
	ImGui.SetNextWindowSize( -- 154
		Vec2(390, 0), -- 154
		"Always" -- 154
	) -- 154
	ImGui.SetNextWindowBgAlpha(0.82) -- 155
	ImGui.Begin( -- 156
		"JOLT Shape Lab", -- 156
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 156
		function() -- 156
			ImGui.Text("Compound Builder") -- 157
			ImGui.Text((("Built / frozen: " .. tostring(compound.built)) .. " / ") .. tostring(frozen)) -- 158
			ImGui.Text("Shared bodies: " .. tostring(#compounds)) -- 159
			if ImGui.Button( -- 159
				"Spawn Compound", -- 160
				Vec2(175, 30) -- 160
			) then -- 160
				spawnCompound() -- 160
			end -- 160
			ImGui.SameLine() -- 161
			if ImGui.Button( -- 161
				"Clear Compounds", -- 162
				Vec2(175, 30) -- 162
			) then -- 162
				clearCompounds() -- 162
			end -- 162
			ImGui.Separator() -- 164
			ImGui.Text("glTF Mesh Collider") -- 165
			ImGui.Text("State: " .. meshState) -- 166
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(meshLoadTime, 3)) .. "s") -- 167
			ImGui.Text("Cache hit: " .. tostring(cacheHit)) -- 168
			ImGui.Text("Dynamic rejected: " .. tostring(dynamicRejected)) -- 169
			local changed = false -- 170
			changed, kinematicMesh = ImGui.Checkbox("Kinematic Mesh (unsupported)", kinematicMesh) -- 171
			if changed and meshShape then -- 171
				createMeshBody() -- 172
			end -- 172
			changed, moveMesh = ImGui.Checkbox("Move Kinematic", moveMesh) -- 173
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 174
			if changed then -- 174
				world.showDebug = physicsDebug -- 175
			end -- 175
			if ImGui.Button( -- 175
				"Reload Cached", -- 176
				Vec2(175, 30) -- 176
			) then -- 176
				loadMesh() -- 176
			end -- 176
			ImGui.SameLine() -- 177
			if ImGui.Button( -- 177
				"Test Dynamic", -- 178
				Vec2(175, 30) -- 178
			) then -- 178
				testDynamicRejection() -- 178
			end -- 178
		end -- 156
	) -- 156
	return false -- 180
end) -- 149
return ____exports -- 149