-- [ts]: JoltDynamicsLab3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayFind = ____lualib.__TS__ArrayFind -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArraySplice = ____lualib.__TS__ArraySplice -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local makeCapsuleBody3D = ____PhysicsBody3D.makeCapsuleBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Camera3D = ____Dora.Camera3D -- 6
local Color3 = ____Dora.Color3 -- 7
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
	Vec3(8, 6, 12), -- 22
	Vec3(0, 2, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("") -- 24
view:setEnvironmentIntensity(0, 0, 1) -- 25
view.showAABB = false -- 26
local light = DirectionalLight3D() -- 28
light.color = Color3(16777215) -- 29
light.intensity = 5 -- 30
light.angleX = -40 -- 31
light.angleY = 30 -- 32
view:addChild(light) -- 33
local world = PhysicsWorld3D() -- 35
view:addChild(world) -- 36
local groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 38
view:addChild(groundModel) -- 39
local groundNode = Node3D() -- 40
groundNode.position = Vec3(0, -0.5, 0) -- 41
view:addChild(groundNode) -- 42
local groundBody = makeBoxBody3D( -- 43
	world, -- 43
	groundNode, -- 43
	Vec3(7, 0.5, 4), -- 43
	PhysicsWorld3D.Static -- 43
) -- 43
groundBody.collisionLayer = 1 -- 44
local platformNode = Node3D() -- 46
platformNode.position = Vec3(0, 1, -1.2) -- 47
view:addChild(platformNode) -- 48
local platformModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 49
platformModel.scale = Vec3(0.35, 0.15, 0.35) -- 50
platformNode:addChild(platformModel) -- 51
local platformBody = makeBoxBody3D( -- 52
	world, -- 52
	platformNode, -- 52
	Vec3(2.2, 0.2, 1.3), -- 52
	PhysicsWorld3D.Kinematic -- 52
) -- 52
platformBody.collisionLayer = 1 -- 53
local sensorNode = Node3D() -- 55
sensorNode.position = Vec3(0, 2.8, 0) -- 56
view:addChild(sensorNode) -- 57
local sensorBody = makeBoxBody3D( -- 58
	world, -- 58
	sensorNode, -- 58
	Vec3(2.6, 0.12, 2), -- 58
	PhysicsWorld3D.Static -- 58
) -- 58
sensorBody.sensor = true -- 59
sensorBody.collisionLayer = 2 -- 60
local actors = {} -- 69
local shapeNames = {"Box", "Sphere", "Capsule"} -- 70
local shapeIndex = 1 -- 71
local selected -- 72
local spawnSerial = 0 -- 73
local gravity = -9.81 -- 74
local impulse = 5 -- 75
local dragGain = 0.8 -- 76
local platformMotion = true -- 77
local collisionEnabled = true -- 78
local physicsDebug = false -- 79
local enterCount = 0 -- 80
local stayCount = 0 -- 81
local exitCount = 0 -- 82
local sensorCount = 0 -- 83
local rayResult = "None" -- 84
local overlapCount = 0 -- 85
local elapsed = 0 -- 86
local function selectedShape() -- 88
	repeat -- 88
		local ____switch3 = shapeIndex -- 88
		local ____cond3 = ____switch3 == 2 -- 88
		if ____cond3 then -- 88
			return {index = 1, name = "Sphere"} -- 90
		end -- 90
		____cond3 = ____cond3 or ____switch3 == 3 -- 90
		if ____cond3 then -- 90
			return {index = 2, name = "Capsule"} -- 91
		end -- 91
		do -- 91
			return {index = 0, name = "Box"} -- 92
		end -- 92
	until true -- 92
end -- 88
local function spawn(position) -- 96
	spawnSerial = spawnSerial + 1 -- 97
	local shape = selectedShape() -- 98
	local node = Node3D() -- 99
	node.position = position or Vec3((spawnSerial % 5 - 2) * 1.2, 6 + spawnSerial * 0.18, 0) -- 100
	view:addChild(node) -- 101
	local model = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 102
	model.tag = "jolt-actor-" .. tostring(spawnSerial) -- 103
	model.scale = Vec3(0.62, 0.62, 0.62) -- 104
	model.position = Vec3(0, -0.35, 0) -- 105
	node:addChild(model) -- 106
	local body = shape.index == 0 and makeBoxBody3D( -- 108
		world, -- 109
		node, -- 109
		Vec3(0.58, 0.5, 0.58) -- 109
	) or (shape.index == 1 and makeSphereBody3D(world, node, 0.58) or makeCapsuleBody3D(world, node, 0.45, 0.42)) -- 109
	body.collisionLayer = 0 -- 113
	body.collisionMask = collisionEnabled and 4294967295 or 1 << 2 -- 114
	local actor = { -- 115
		node = node, -- 115
		model = model, -- 115
		body = body, -- 115
		name = (shape.name .. " ") .. tostring(spawnSerial) -- 115
	} -- 115
	body:onContactEnter(function(other) -- 116
		enterCount = enterCount + 1 -- 117
		if other == sensorBody then -- 117
			sensorCount = sensorCount + 1 -- 118
		end -- 118
	end) -- 116
	body:onContactStay(function() -- 120
		stayCount = stayCount + 1 -- 120
		return stayCount -- 120
	end) -- 120
	body:onContactExit(function() -- 121
		exitCount = exitCount + 1 -- 121
		return exitCount -- 121
	end) -- 121
	actors[#actors + 1] = actor -- 122
	return actor -- 123
end -- 96
local function select(actor) -- 126
	if selected then -- 126
		selected.model.scale = Vec3(0.62, 0.62, 0.62) -- 127
	end -- 127
	selected = actor -- 128
	if selected then -- 128
		selected.model.scale = Vec3(0.78, 0.78, 0.78) -- 129
	end -- 129
end -- 126
local function clearActors() -- 132
	select(nil) -- 133
	while #actors > 0 do -- 133
		local actor = table.remove(actors) -- 135
		actor.body:removeFromParent(true) -- 136
	end -- 136
end -- 132
local function updateCollisionMasks() -- 140
	for ____, actor in ipairs(actors) do -- 141
		actor.body.collisionMask = collisionEnabled and 4294967295 or 1 << 2 -- 141
	end -- 141
end -- 140
local function queryScene() -- 144
	rayResult = "None" -- 145
	local start = Vec3(0, 9, 0) -- 146
	world:raycast( -- 147
		start, -- 147
		Vec3(0, -11, 0), -- 147
		function(body, point) -- 147
			local dx = point.x - start.x -- 148
			local dy = point.y - start.y -- 149
			local dz = point.z - start.z -- 150
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz) -- 151
			rayResult = ((body.tag ~= "" and body.tag or "Collider") .. " @ ") .. __TS__NumberToFixed(distance, 2) -- 152
			return true -- 153
		end -- 147
	) -- 147
	overlapCount = 0 -- 155
	world:querySphere( -- 156
		Vec3(0, 2.5, 0), -- 156
		3.5, -- 156
		function() -- 156
			overlapCount = overlapCount + 1 -- 157
			return false -- 158
		end -- 156
	) -- 156
end -- 144
view:onTapBegan(function(touch) -- 162
	local picked = view:pick(touch.viewLocation) -- 163
	select(__TS__ArrayFind( -- 164
		actors, -- 164
		function(____, actor) return actor.model == picked end -- 164
	)) -- 164
end) -- 162
view:onTapMoved(function(touch) -- 167
	if not selected then -- 167
		return -- 168
	end -- 168
	local velocity = selected.body.linearVelocity -- 169
	selected.body.linearVelocity = Vec3(velocity.x - touch.delta.x * dragGain, velocity.y + touch.delta.y * dragGain, velocity.z) -- 170
end) -- 167
do -- 167
	local i = 0 -- 177
	while i < 5 do -- 177
		spawn(Vec3((i - 2) * 1.3, 4.5 + i * 0.8, 0)) -- 177
		i = i + 1 -- 177
	end -- 177
end -- 177
world.showDebug = physicsDebug -- 178
print("JOLT_DYNAMICS_LAB_READY") -- 179
threadLoop(function() -- 181
	elapsed = elapsed + App.deltaTime -- 182
	if platformMotion then -- 182
		platformBody.position = Vec3( -- 183
			math.sin(elapsed * 1.2) * 2.8, -- 183
			1, -- 183
			-1.2 -- 183
		) -- 183
	end -- 183
	world.gravity = Vec3(0, gravity, 0) -- 184
	queryScene() -- 185
	ImGui.SetNextWindowPos( -- 187
		Vec2(12, 12), -- 187
		"Always" -- 187
	) -- 187
	ImGui.SetNextWindowSize( -- 188
		Vec2(390, 0), -- 188
		"Always" -- 188
	) -- 188
	ImGui.SetNextWindowBgAlpha(0.82) -- 189
	ImGui.Begin( -- 190
		"JOLT Dynamics Lab", -- 190
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 190
		function() -- 190
			local changed = false -- 191
			changed, shapeIndex = ImGui.Combo("Spawn Shape", shapeIndex, shapeNames) -- 192
			changed, gravity = ImGui.DragFloat( -- 193
				"Gravity", -- 193
				gravity, -- 193
				0.2, -- 193
				-30, -- 193
				10, -- 193
				"%.2f" -- 193
			) -- 193
			changed, impulse = ImGui.DragFloat( -- 194
				"Impulse", -- 194
				impulse, -- 194
				0.2, -- 194
				0.5, -- 194
				20, -- 194
				"%.1f" -- 194
			) -- 194
			changed, dragGain = ImGui.DragFloat( -- 195
				"Drag Gain", -- 195
				dragGain, -- 195
				0.05, -- 195
				0.1, -- 195
				2.5, -- 195
				"%.2f" -- 195
			) -- 195
			changed, platformMotion = ImGui.Checkbox("Kinematic Platform", platformMotion) -- 196
			changed, collisionEnabled = ImGui.Checkbox("Ground Collision", collisionEnabled) -- 197
			if changed then -- 197
				updateCollisionMasks() -- 198
			end -- 198
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 199
			if changed then -- 199
				world.showDebug = physicsDebug -- 200
			end -- 200
			ImGui.Separator() -- 202
			ImGui.Text("Selected: " .. (selected and selected.name or "None")) -- 203
			ImGui.Text("Bodies: " .. tostring(#actors)) -- 204
			ImGui.Text((((("Enter / Stay / Exit: " .. tostring(enterCount)) .. " / ") .. tostring(stayCount)) .. " / ") .. tostring(exitCount)) -- 205
			ImGui.Text("Sensor enters: " .. tostring(sensorCount)) -- 206
			ImGui.Text("Ray: " .. rayResult) -- 207
			ImGui.Text("Overlap: " .. tostring(overlapCount)) -- 208
			if ImGui.Button( -- 208
				"Spawn", -- 210
				Vec2(115, 30) -- 210
			) then -- 210
				spawn() -- 210
			end -- 210
			ImGui.SameLine() -- 211
			if ImGui.Button( -- 211
				"Delete", -- 212
				Vec2(115, 30) -- 212
			) and selected then -- 212
				local target = selected -- 213
				select(nil) -- 214
				target.body:removeFromParent(true) -- 215
				local index = __TS__ArrayIndexOf(actors, target) -- 216
				if index >= 0 then -- 216
					__TS__ArraySplice(actors, index, 1) -- 217
				end -- 217
			end -- 217
			ImGui.SameLine() -- 219
			if ImGui.Button( -- 219
				"Clear", -- 220
				Vec2(115, 30) -- 220
			) then -- 220
				clearActors() -- 220
			end -- 220
			if ImGui.Button( -- 220
				"Force Left", -- 222
				Vec2(115, 30) -- 222
			) and selected then -- 222
				selected.body:applyForce(Vec3(-impulse * 20, 0, 0)) -- 222
			end -- 222
			ImGui.SameLine() -- 223
			if ImGui.Button( -- 223
				"Impulse Up", -- 224
				Vec2(115, 30) -- 224
			) and selected then -- 224
				selected.body:applyLinearImpulse(Vec3(0, impulse, 0)) -- 224
			end -- 224
			ImGui.SameLine() -- 225
			if ImGui.Button( -- 225
				"Spin", -- 226
				Vec2(115, 30) -- 226
			) and selected then -- 226
				selected.body.angularVelocity = Vec3(0, impulse, impulse * 0.4) -- 226
			end -- 226
		end -- 190
	) -- 190
	return false -- 228
end) -- 181
return ____exports -- 181