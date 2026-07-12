-- [ts]: JoltDynamicsLab3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayFind = ____lualib.__TS__ArrayFind -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArraySplice = ____lualib.__TS__ArraySplice -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Node3D = ____Dora.Node3D -- 10
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 11
local Vec2 = ____Dora.Vec2 -- 12
local Vec3 = ____Dora.Vec3 -- 13
local threadLoop = ____Dora.threadLoop -- 14
local ImGui = require("ImGui") -- 17
local view = Director.entry -- 19
local camera = Camera3D() -- 20
camera:lookAt( -- 21
	Vec3(8, 6, 12), -- 21
	Vec3(0, 2, 0) -- 21
) -- 21
Director:pushCamera(camera) -- 22
view:setEnvironmentMap("") -- 23
view:setEnvironmentIntensity(0, 0, 1) -- 24
view.showAABB = false -- 25
local light = DirectionalLight3D() -- 27
light.color = Color3(16777215) -- 28
light.intensity = 5 -- 29
light.angleX = -40 -- 30
light.angleY = 30 -- 31
view:addChild(light) -- 32
local world = PhysicsWorld3D() -- 34
view:addChild(world) -- 35
local groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 37
view:addChild(groundModel) -- 38
local groundNode = Node3D() -- 39
groundNode.position = Vec3(0, -0.5, 0) -- 40
view:addChild(groundNode) -- 41
local groundBody = world:createBox( -- 42
	groundNode, -- 42
	Vec3(7, 0.5, 4), -- 42
	PhysicsWorld3D.Static -- 42
) -- 42
groundBody.collisionLayer = 1 -- 43
local platformNode = Node3D() -- 45
platformNode.position = Vec3(0, 1, -1.2) -- 46
view:addChild(platformNode) -- 47
local platformModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 48
platformModel.scale = Vec3(0.35, 0.15, 0.35) -- 49
platformNode:addChild(platformModel) -- 50
local platformBody = world:createBox( -- 51
	platformNode, -- 51
	Vec3(2.2, 0.2, 1.3), -- 51
	PhysicsWorld3D.Kinematic -- 51
) -- 51
platformBody.collisionLayer = 1 -- 52
local sensorNode = Node3D() -- 54
sensorNode.position = Vec3(0, 2.8, 0) -- 55
view:addChild(sensorNode) -- 56
local sensorBody = world:createBox( -- 57
	sensorNode, -- 57
	Vec3(2.6, 0.12, 2), -- 57
	PhysicsWorld3D.Static -- 57
) -- 57
sensorBody.sensor = true -- 58
sensorBody.collisionLayer = 2 -- 59
local actors = {} -- 68
local shapeNames = {"Box", "Sphere", "Capsule"} -- 69
local shapeIndex = 1 -- 70
local selected -- 71
local spawnSerial = 0 -- 72
local gravity = -9.81 -- 73
local impulse = 5 -- 74
local dragGain = 0.8 -- 75
local platformMotion = true -- 76
local collisionEnabled = true -- 77
local physicsDebug = false -- 78
local enterCount = 0 -- 79
local stayCount = 0 -- 80
local exitCount = 0 -- 81
local sensorCount = 0 -- 82
local rayResult = "None" -- 83
local overlapCount = 0 -- 84
local elapsed = 0 -- 85
local function selectedShape() -- 87
	repeat -- 87
		local ____switch3 = shapeIndex -- 87
		local ____cond3 = ____switch3 == 2 -- 87
		if ____cond3 then -- 87
			return {index = 1, name = "Sphere"} -- 89
		end -- 89
		____cond3 = ____cond3 or ____switch3 == 3 -- 89
		if ____cond3 then -- 89
			return {index = 2, name = "Capsule"} -- 90
		end -- 90
		do -- 90
			return {index = 0, name = "Box"} -- 91
		end -- 91
	until true -- 91
end -- 87
local function spawn(position) -- 95
	spawnSerial = spawnSerial + 1 -- 96
	local shape = selectedShape() -- 97
	local node = Node3D() -- 98
	node.position = position or Vec3((spawnSerial % 5 - 2) * 1.2, 6 + spawnSerial * 0.18, 0) -- 99
	view:addChild(node) -- 100
	local model = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 101
	model.tag = "jolt-actor-" .. tostring(spawnSerial) -- 102
	model.scale = Vec3(0.62, 0.62, 0.62) -- 103
	model.position = Vec3(0, -0.35, 0) -- 104
	node:addChild(model) -- 105
	local body = shape.index == 0 and world:createBox( -- 107
		node, -- 108
		Vec3(0.58, 0.5, 0.58) -- 108
	) or (shape.index == 1 and world:createSphere(node, 0.58) or world:createCapsule(node, 0.45, 0.42)) -- 108
	body.collisionLayer = 0 -- 112
	body.collisionMask = collisionEnabled and 4294967295 or 1 << 2 -- 113
	local actor = { -- 114
		node = node, -- 114
		model = model, -- 114
		body = body, -- 114
		name = (shape.name .. " ") .. tostring(spawnSerial) -- 114
	} -- 114
	body:onContactEnter(function(other) -- 115
		enterCount = enterCount + 1 -- 116
		if other == sensorBody then -- 116
			sensorCount = sensorCount + 1 -- 117
		end -- 117
	end) -- 115
	body:onContactStay(function() -- 119
		stayCount = stayCount + 1 -- 119
		return stayCount -- 119
	end) -- 119
	body:onContactExit(function() -- 120
		exitCount = exitCount + 1 -- 120
		return exitCount -- 120
	end) -- 120
	actors[#actors + 1] = actor -- 121
	return actor -- 122
end -- 95
local function select(actor) -- 125
	if selected then -- 125
		selected.model.scale = Vec3(0.62, 0.62, 0.62) -- 126
	end -- 126
	selected = actor -- 127
	if selected then -- 127
		selected.model.scale = Vec3(0.78, 0.78, 0.78) -- 128
	end -- 128
end -- 125
local function clearActors() -- 131
	select(nil) -- 132
	while #actors > 0 do -- 132
		local actor = table.remove(actors) -- 134
		actor.body:destroy() -- 135
		actor.node:removeFromParent(true) -- 136
	end -- 136
end -- 131
local function updateCollisionMasks() -- 140
	for ____, actor in ipairs(actors) do -- 141
		actor.body.collisionMask = collisionEnabled and 4294967295 or 1 << 2 -- 141
	end -- 141
end -- 140
local function queryScene() -- 144
	rayResult = "None" -- 145
	world:raycast( -- 146
		Vec3(0, 9, 0), -- 146
		Vec3(0, -1, 0), -- 146
		20, -- 146
		function(body, _point, _normal, distance) -- 146
			local ____opt_0 = body.node -- 146
			rayResult = ((____opt_0 and ____opt_0.tag or "Collider") .. " @ ") .. __TS__NumberToFixed(distance, 2) -- 147
			return true -- 148
		end -- 146
	) -- 146
	overlapCount = 0 -- 150
	world:overlapSphere( -- 151
		Vec3(0, 2.5, 0), -- 151
		3.5, -- 151
		function() -- 151
			overlapCount = overlapCount + 1 -- 152
			return false -- 153
		end -- 151
	) -- 151
end -- 144
view:onTapBegan(function(touch) -- 157
	local picked = view:pick(touch.viewLocation) -- 158
	select(__TS__ArrayFind( -- 159
		actors, -- 159
		function(____, actor) return actor.model == picked end -- 159
	)) -- 159
end) -- 157
view:onTapMoved(function(touch) -- 162
	if not selected then -- 162
		return -- 163
	end -- 163
	local velocity = selected.body.linearVelocity -- 164
	selected.body.linearVelocity = Vec3(velocity.x - touch.delta.x * dragGain, velocity.y + touch.delta.y * dragGain, velocity.z) -- 165
end) -- 162
do -- 162
	local i = 0 -- 172
	while i < 5 do -- 172
		spawn(Vec3((i - 2) * 1.3, 4.5 + i * 0.8, 0)) -- 172
		i = i + 1 -- 172
	end -- 172
end -- 172
world.showDebug = physicsDebug -- 173
print("JOLT_DYNAMICS_LAB_READY") -- 174
threadLoop(function() -- 176
	elapsed = elapsed + App.deltaTime -- 177
	if platformMotion then -- 177
		platformNode.position = Vec3( -- 178
			math.sin(elapsed * 1.2) * 2.8, -- 178
			1, -- 178
			-1.2 -- 178
		) -- 178
	end -- 178
	world.gravity = Vec3(0, gravity, 0) -- 179
	queryScene() -- 180
	ImGui.SetNextWindowPos( -- 182
		Vec2(12, 12), -- 182
		"Always" -- 182
	) -- 182
	ImGui.SetNextWindowSize( -- 183
		Vec2(390, 0), -- 183
		"Always" -- 183
	) -- 183
	ImGui.SetNextWindowBgAlpha(0.82) -- 184
	ImGui.Begin( -- 185
		"JOLT Dynamics Lab", -- 185
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 185
		function() -- 185
			local changed = false -- 186
			changed, shapeIndex = ImGui.Combo("Spawn Shape", shapeIndex, shapeNames) -- 187
			changed, gravity = ImGui.DragFloat( -- 188
				"Gravity", -- 188
				gravity, -- 188
				0.2, -- 188
				-30, -- 188
				10, -- 188
				"%.2f" -- 188
			) -- 188
			changed, impulse = ImGui.DragFloat( -- 189
				"Impulse", -- 189
				impulse, -- 189
				0.2, -- 189
				0.5, -- 189
				20, -- 189
				"%.1f" -- 189
			) -- 189
			changed, dragGain = ImGui.DragFloat( -- 190
				"Drag Gain", -- 190
				dragGain, -- 190
				0.05, -- 190
				0.1, -- 190
				2.5, -- 190
				"%.2f" -- 190
			) -- 190
			changed, platformMotion = ImGui.Checkbox("Kinematic Platform", platformMotion) -- 191
			changed, collisionEnabled = ImGui.Checkbox("Ground Collision", collisionEnabled) -- 192
			if changed then -- 192
				updateCollisionMasks() -- 193
			end -- 193
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 194
			if changed then -- 194
				world.showDebug = physicsDebug -- 195
			end -- 195
			ImGui.Separator() -- 197
			ImGui.Text("Selected: " .. (selected and selected.name or "None")) -- 198
			ImGui.Text("Bodies: " .. tostring(#actors)) -- 199
			ImGui.Text((((("Enter / Stay / Exit: " .. tostring(enterCount)) .. " / ") .. tostring(stayCount)) .. " / ") .. tostring(exitCount)) -- 200
			ImGui.Text("Sensor enters: " .. tostring(sensorCount)) -- 201
			ImGui.Text("Ray: " .. rayResult) -- 202
			ImGui.Text("Overlap: " .. tostring(overlapCount)) -- 203
			if ImGui.Button( -- 203
				"Spawn", -- 205
				Vec2(115, 30) -- 205
			) then -- 205
				spawn() -- 205
			end -- 205
			ImGui.SameLine() -- 206
			if ImGui.Button( -- 206
				"Delete", -- 207
				Vec2(115, 30) -- 207
			) and selected then -- 207
				local target = selected -- 208
				select(nil) -- 209
				target.body:destroy() -- 210
				target.node:removeFromParent(true) -- 211
				local index = __TS__ArrayIndexOf(actors, target) -- 212
				if index >= 0 then -- 212
					__TS__ArraySplice(actors, index, 1) -- 213
				end -- 213
			end -- 213
			ImGui.SameLine() -- 215
			if ImGui.Button( -- 215
				"Clear", -- 216
				Vec2(115, 30) -- 216
			) then -- 216
				clearActors() -- 216
			end -- 216
			if ImGui.Button( -- 216
				"Force Left", -- 218
				Vec2(115, 30) -- 218
			) and selected then -- 218
				selected.body:applyForce(Vec3(-impulse * 20, 0, 0)) -- 218
			end -- 218
			ImGui.SameLine() -- 219
			if ImGui.Button( -- 219
				"Impulse Up", -- 220
				Vec2(115, 30) -- 220
			) and selected then -- 220
				selected.body:applyImpulse(Vec3(0, impulse, 0)) -- 220
			end -- 220
			ImGui.SameLine() -- 221
			if ImGui.Button( -- 221
				"Spin", -- 222
				Vec2(115, 30) -- 222
			) and selected then -- 222
				selected.body.angularVelocity = Vec3(0, impulse, impulse * 0.4) -- 222
			end -- 222
		end -- 185
	) -- 185
	return false -- 224
end) -- 176
return ____exports -- 176