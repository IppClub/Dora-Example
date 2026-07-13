-- [ts]: ConstraintPlayground3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local ____Dora = require("Dora") -- 3
local Camera3D = ____Dora.Camera3D -- 6
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
world.gravity = Vec3(0, -9.81, 0) -- 37
view:addChild(world) -- 38
local groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 40
view:addChild(groundModel) -- 41
local groundNode = Node3D() -- 42
groundNode.position = Vec3(0, -0.5, 0) -- 43
view:addChild(groundNode) -- 44
makeBoxBody3D( -- 45
	world, -- 45
	groundNode, -- 45
	Vec3(7, 0.5, 4), -- 45
	PhysicsWorld3D.Static -- 45
) -- 45
local anchorNode = Node3D() -- 47
anchorNode.position = Vec3(0, 4.5, 0) -- 48
view:addChild(anchorNode) -- 49
local anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 50
anchorModel.scale = Vec3(0.32, 0.32, 0.32) -- 51
anchorModel.position = Vec3(0, -0.2, 0) -- 52
anchorNode:addChild(anchorModel) -- 53
local anchorBody = makeBoxBody3D( -- 54
	world, -- 54
	anchorNode, -- 54
	Vec3(0.22, 0.22, 0.22), -- 54
	PhysicsWorld3D.Static -- 54
) -- 54
local dynamicNode = Node3D() -- 56
view:addChild(dynamicNode) -- 57
local dynamicModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 58
dynamicModel.tag = "playground-duck" -- 59
dynamicModel.scale = Vec3(0.8, 0.8, 0.8) -- 60
dynamicModel.position = Vec3(0, -0.45, 0) -- 61
dynamicNode:addChild(dynamicModel) -- 62
local modeNames = {"Fixed", "Distance", "Hinge"} -- 64
local mode = 2 -- 65
local ropeLength = 2.8 -- 66
local hingeLimit = 80 -- 67
local impulse = 4 -- 68
local dragGain = 0.9 -- 69
local showAABB = false -- 70
local physicsDebug = false -- 71
local selected = false -- 72
local body = makeBoxBody3D( -- 73
	world, -- 73
	dynamicNode, -- 73
	Vec3(0.65, 0.55, 0.65) -- 73
) -- 73
local constraint -- 74
local state = "Connected" -- 75
local peakSpeed = 0 -- 76
local function vecLength(value) -- 78
	return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z) -- 78
end -- 78
local function rebuild() -- 82
	if constraint ~= nil then -- 82
		constraint:destroy() -- 83
	end -- 83
	constraint = nil -- 84
	body:removeFromParent(true) -- 85
	local start = mode == 0 and Vec3(1.8, 2.4, 0) or (mode == 1 and Vec3(ropeLength * 0.72, 4.5 - ropeLength * 0.69, 0) or Vec3(1.8, 2.4, 0)) -- 87
	dynamicNode.position = start -- 92
	dynamicNode.angles = Vec3(0, 0, 0) -- 93
	body = makeBoxBody3D( -- 94
		world, -- 94
		dynamicNode, -- 94
		Vec3(0.65, 0.55, 0.65) -- 94
	) -- 94
	if mode == 0 then -- 94
		constraint = Constraint3D:fixed( -- 97
			anchorBody, -- 97
			body, -- 97
			Vec3(0.9, 3.45, 0) -- 97
		) -- 97
	elseif mode == 1 then -- 97
		constraint = Constraint3D:distance( -- 99
			anchorBody, -- 100
			body, -- 101
			anchorNode.position, -- 102
			dynamicNode.position, -- 103
			ropeLength, -- 104
			ropeLength -- 105
		) -- 105
	else -- 105
		constraint = Constraint3D:hinge( -- 108
			anchorBody, -- 109
			body, -- 110
			anchorNode.position, -- 111
			Vec3(0, 0, 1), -- 112
			-hingeLimit, -- 112
			hingeLimit -- 114
		) -- 114
	end -- 114
	state = "Connected" -- 117
	peakSpeed = 0 -- 118
end -- 82
local function push(x, y) -- 121
	body:applyLinearImpulse(Vec3(x * impulse, y * impulse, 0)) -- 122
end -- 121
view:onTapBegan(function(touch) -- 125
	selected = view:pick(touch.viewLocation) == dynamicModel -- 126
	dynamicModel.scale = selected and Vec3(0.92, 0.92, 0.92) or Vec3(0.8, 0.8, 0.8) -- 127
end) -- 125
view:onTapMoved(function(touch) -- 130
	if not selected then -- 130
		return -- 131
	end -- 131
	local velocity = body.linearVelocity -- 132
	body.linearVelocity = Vec3(velocity.x - touch.delta.x * dragGain, velocity.y + touch.delta.y * dragGain, 0) -- 133
end) -- 130
view:onTapEnded(function() -- 140
	selected = false -- 141
	dynamicModel.scale = Vec3(0.8, 0.8, 0.8) -- 142
end) -- 140
rebuild() -- 145
print("CONSTRAINT_PLAYGROUND3D_READY") -- 146
threadLoop(function() -- 148
	peakSpeed = math.max( -- 149
		peakSpeed, -- 149
		vecLength(body.linearVelocity) -- 149
	) -- 149
	ImGui.SetNextWindowPos( -- 151
		Vec2(12, 12), -- 151
		"Always" -- 151
	) -- 151
	ImGui.SetNextWindowSize( -- 152
		Vec2(350, 0), -- 152
		"Always" -- 152
	) -- 152
	ImGui.SetNextWindowBgAlpha(0.82) -- 153
	ImGui.Begin( -- 154
		"Constraint Playground", -- 154
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 154
		function() -- 154
			local changed = false -- 155
			changed, mode = ImGui.Combo("Constraint", mode, modeNames) -- 156
			if changed then -- 156
				rebuild() -- 157
			end -- 157
			if mode == 1 then -- 157
				changed, ropeLength = ImGui.DragFloat( -- 160
					"Length", -- 160
					ropeLength, -- 160
					0.05, -- 160
					1.5, -- 160
					4, -- 160
					"%.2f" -- 160
				) -- 160
				if changed then -- 160
					rebuild() -- 161
				end -- 161
			elseif mode == 2 then -- 161
				changed, hingeLimit = ImGui.DragFloat( -- 163
					"Limit", -- 163
					hingeLimit, -- 163
					1, -- 163
					10, -- 163
					170, -- 163
					"%.0f deg" -- 163
				) -- 163
				if changed then -- 163
					rebuild() -- 164
				end -- 164
			end -- 164
			changed, impulse = ImGui.DragFloat( -- 167
				"Impulse", -- 167
				impulse, -- 167
				0.1, -- 167
				0.5, -- 167
				12, -- 167
				"%.1f" -- 167
			) -- 167
			changed, dragGain = ImGui.DragFloat( -- 168
				"Drag Gain", -- 168
				dragGain, -- 168
				0.05, -- 168
				0.2, -- 168
				2.5, -- 168
				"%.2f" -- 168
			) -- 168
			changed, showAABB = ImGui.Checkbox("Show AABB", showAABB) -- 169
			if changed then -- 169
				view.showAABB = showAABB -- 170
			end -- 170
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 171
			if changed then -- 171
				world.showDebug = physicsDebug -- 172
			end -- 172
			ImGui.Separator() -- 174
			ImGui.Text("State: " .. state) -- 175
			ImGui.Text("Selected: " .. tostring(selected)) -- 176
			ImGui.Text("Speed: " .. __TS__NumberToFixed( -- 177
				vecLength(body.linearVelocity), -- 177
				2 -- 177
			)) -- 177
			ImGui.Text("Peak speed: " .. __TS__NumberToFixed(peakSpeed, 2)) -- 178
			ImGui.Text((("Position: " .. __TS__NumberToFixed(dynamicNode.position.x, 2)) .. ", ") .. __TS__NumberToFixed(dynamicNode.position.y, 2)) -- 179
			if ImGui.Button( -- 179
				"Left", -- 181
				Vec2(100, 30) -- 181
			) then -- 181
				push(-1, 0) -- 181
			end -- 181
			ImGui.SameLine() -- 182
			if ImGui.Button( -- 182
				"Up", -- 183
				Vec2(100, 30) -- 183
			) then -- 183
				push(0, 1) -- 183
			end -- 183
			ImGui.SameLine() -- 184
			if ImGui.Button( -- 184
				"Right", -- 185
				Vec2(100, 30) -- 185
			) then -- 185
				push(1, 0) -- 185
			end -- 185
			if ImGui.Button( -- 185
				"Break", -- 187
				Vec2(150, 30) -- 187
			) and constraint then -- 187
				constraint:destroy() -- 188
				constraint = nil -- 189
				state = "Broken" -- 190
			end -- 190
			ImGui.SameLine() -- 192
			if ImGui.Button( -- 192
				"Rebuild", -- 193
				Vec2(150, 30) -- 193
			) then -- 193
				rebuild() -- 193
			end -- 193
		end -- 154
	) -- 154
	return false -- 195
end) -- 148
return ____exports -- 148