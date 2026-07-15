-- [ts]: JoltShapeLab3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBody3D = ____PhysicsBody3D.makeBody3D -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Body3D = ____Dora.Body3D -- 5
local BodyDef3D = ____Dora.BodyDef3D -- 7
local Camera3D = ____Dora.Camera3D -- 8
local Color3 = ____Dora.Color3 -- 9
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 10
local Director = ____Dora.Director -- 11
local Model3D = ____Dora.Model3D -- 12
local Node3D = ____Dora.Node3D -- 13
local FixtureDef3D = ____Dora.FixtureDef3D -- 14
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 16
local Vec2 = ____Dora.Vec2 -- 17
local Vec3 = ____Dora.Vec3 -- 18
local threadLoop = ____Dora.threadLoop -- 19
local ImGui = require("ImGui") -- 22
local view = Director.entry -- 24
local camera = Camera3D() -- 25
camera:lookAt( -- 26
	Vec3(9, 6, 13), -- 26
	Vec3(0, 1.5, 0) -- 26
) -- 26
Director:pushCamera(camera) -- 27
view:setEnvironmentMap("") -- 28
view:setEnvironmentIntensity(0, 0, 1) -- 29
view.showAABB = true -- 30
local light = DirectionalLight3D() -- 32
light.color = Color3(16777215) -- 33
light.intensity = 5 -- 34
light.angleX = -45 -- 35
light.angleY = 25 -- 36
view:addChild(light) -- 37
local world = PhysicsWorld3D() -- 39
view:addChild(world) -- 40
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 42
view:addChild(floorVisual) -- 43
local floorNode = Node3D() -- 44
floorNode.position = Vec3(0, -0.5, 0) -- 45
view:addChild(floorNode) -- 46
makeBoxBody3D( -- 47
	world, -- 47
	floorNode, -- 47
	Vec3(8, 0.5, 4), -- 47
	PhysicsWorld3D.Static -- 47
) -- 47
local childBox = FixtureDef3D:box(Vec3(0.55, 0.5, 0.55)) -- 49
local childSphere = FixtureDef3D:sphere(0.58) -- 50
local compound = FixtureDef3D:compound() -- 51
compound:addChild( -- 52
	childBox, -- 52
	Vec3(-0.9, 0, 0), -- 52
	Vec3(0, 0, -12) -- 52
) -- 52
compound:addChild( -- 53
	childSphere, -- 53
	Vec3(0.9, 0, 0) -- 53
) -- 53
compound:build() -- 54
local frozen = not compound:addChild( -- 55
	childBox, -- 55
	Vec3(0, 1, 0) -- 55
) -- 55
local compounds = {} -- 58
local serial = 0 -- 59
local function spawnCompound() -- 61
	serial = serial + 1 -- 62
	local node = Node3D() -- 63
	node.position = Vec3(-2.7 + serial % 3 * 0.4, 3.5 + serial * 0.45, 0) -- 64
	view:addChild(node) -- 65
	for ____, x in ipairs({-0.9, 0.9}) do -- 66
		local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 67
		duck.position = Vec3(x, -0.4, 0) -- 68
		duck.scale = Vec3(0.48, 0.48, 0.48) -- 69
		node:addChild(duck) -- 70
	end -- 70
	local body = makeBody3D(world, node, compound, PhysicsWorld3D.Dynamic) -- 72
	compounds[#compounds + 1] = {node = node, body = body} -- 73
end -- 61
local function clearCompounds() -- 76
	while #compounds > 0 do -- 76
		local actor = table.remove(compounds) -- 78
		actor.body:removeFromParent(true) -- 79
	end -- 79
end -- 76
local meshPath = "Test/Model3D/Assets/Model/Ground.gltf" -- 83
local meshNode = Node3D() -- 84
meshNode.position = Vec3(3.2, 1.2, 0) -- 85
view:addChild(meshNode) -- 86
local meshVisual = Model3D(meshPath) -- 87
meshVisual.scale = Vec3(0.55, 0.55, 0.55) -- 88
meshNode:addChild(meshVisual) -- 89
local meshShape -- 91
local meshBody -- 92
local meshState = "Not loaded" -- 93
local meshLoadTime = 0 -- 94
local cacheHit = false -- 95
local dynamicRejected = false -- 96
local elapsed = 0 -- 97
local physicsDebug = false -- 98
local kinematicNode = Node3D() -- 100
kinematicNode.position = Vec3(3.2, 3, 0) -- 101
view:addChild(kinematicNode) -- 102
local kinematicPlatform = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 103
kinematicPlatform.scale = Vec3(0.28, 0.12, 0.28) -- 104
kinematicNode:addChild(kinematicPlatform) -- 105
local kinematicBody = makeBoxBody3D( -- 106
	world, -- 107
	kinematicNode, -- 108
	Vec3(1.8, 0.2, 1), -- 109
	PhysicsWorld3D.Kinematic -- 110
) -- 110
local moveKinematic = true -- 112
local function createMeshBody() -- 114
	if not meshShape then -- 114
		return -- 115
	end -- 115
	if meshBody then -- 115
		local position = meshBody.position -- 117
		meshBody:removeChild(meshNode, false) -- 118
		meshBody:removeFromParent(true) -- 119
		view:addChild(meshNode) -- 120
		meshNode.position = position -- 121
	end -- 121
	meshBody = makeBody3D(world, meshNode, meshShape, PhysicsWorld3D.Static) -- 123
	meshState = meshBody ~= nil and "Static ready" or "Body creation rejected" -- 128
end -- 114
local function loadMesh() -- 131
	meshState = "Loading through Content" -- 132
	local started = App.runningTime -- 133
	FixtureDef3D:loadMeshAsync( -- 134
		meshPath, -- 134
		function(shape) -- 134
			meshLoadTime = App.runningTime - started -- 135
			if not shape.built then -- 135
				meshState = "Cook failed" -- 137
				return -- 138
			end -- 138
			meshShape = shape -- 140
			createMeshBody() -- 141
			FixtureDef3D:loadMeshAsync( -- 142
				meshPath, -- 142
				function(cached) -- 142
					cacheHit = cached == shape -- 143
				end -- 142
			) -- 142
		end -- 134
	) -- 134
end -- 131
local function testDynamicRejection() -- 148
	if not meshShape then -- 148
		return -- 149
	end -- 149
	local probe = Node3D() -- 150
	probe.position = Vec3(0, -20, 0) -- 151
	view:addChild(probe) -- 152
	local def = BodyDef3D() -- 153
	def.type = PhysicsWorld3D.Dynamic -- 154
	def:attach(meshShape) -- 155
	local rejected = Body3D(def, world, probe.position, probe.angles) -- 156
	dynamicRejected = rejected == nil -- 157
	if rejected ~= nil then -- 157
		rejected:removeFromParent(true) -- 158
	end -- 158
	probe:removeFromParent(true) -- 159
end -- 148
do -- 148
	local i = 0 -- 162
	while i < 3 do -- 162
		spawnCompound() -- 162
		i = i + 1 -- 162
	end -- 162
end -- 162
loadMesh() -- 163
print("JOLT_SHAPE_LAB_READY") -- 164
threadLoop(function() -- 166
	elapsed = elapsed + App.deltaTime -- 167
	if moveKinematic then -- 167
		kinematicBody.position = Vec3( -- 169
			3.2, -- 169
			3 + math.sin(elapsed * 1.5) * 0.7, -- 169
			0 -- 169
		) -- 169
	end -- 169
	ImGui.SetNextWindowPos( -- 172
		Vec2(12, 12), -- 172
		"Always" -- 172
	) -- 172
	ImGui.SetNextWindowSize( -- 173
		Vec2(390, 0), -- 173
		"Always" -- 173
	) -- 173
	ImGui.SetNextWindowBgAlpha(0.82) -- 174
	ImGui.Begin( -- 175
		"JOLT Shape Lab", -- 175
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 175
		function() -- 175
			ImGui.Text("Compound Builder") -- 176
			ImGui.Text((("Built / frozen: " .. tostring(compound.built)) .. " / ") .. tostring(frozen)) -- 177
			ImGui.Text("Shared bodies: " .. tostring(#compounds)) -- 178
			if ImGui.Button( -- 178
				"Spawn Compound", -- 179
				Vec2(175, 30) -- 179
			) then -- 179
				spawnCompound() -- 179
			end -- 179
			ImGui.SameLine() -- 180
			if ImGui.Button( -- 180
				"Clear Compounds", -- 181
				Vec2(175, 30) -- 181
			) then -- 181
				clearCompounds() -- 181
			end -- 181
			ImGui.Separator() -- 183
			ImGui.Text("glTF Mesh Collider") -- 184
			ImGui.Text("State: " .. meshState) -- 185
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(meshLoadTime, 3)) .. "s") -- 186
			ImGui.Text("Cache hit: " .. tostring(cacheHit)) -- 187
			ImGui.Text("Dynamic rejected: " .. tostring(dynamicRejected)) -- 188
			local changed = false -- 189
			changed, moveKinematic = ImGui.Checkbox("Move Kinematic Platform", moveKinematic) -- 190
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 191
			if changed then -- 191
				world.showDebug = physicsDebug -- 192
			end -- 192
			if ImGui.Button( -- 192
				"Reload Cached", -- 193
				Vec2(175, 30) -- 193
			) then -- 193
				loadMesh() -- 193
			end -- 193
			ImGui.SameLine() -- 194
			if ImGui.Button( -- 194
				"Test Dynamic", -- 195
				Vec2(175, 30) -- 195
			) then -- 195
				testDynamicRejection() -- 195
			end -- 195
		end -- 175
	) -- 175
	return false -- 197
end) -- 166
return ____exports -- 166