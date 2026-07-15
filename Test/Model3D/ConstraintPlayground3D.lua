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
	body:removeChild(dynamicNode, false) -- 85
	body:removeFromParent(true) -- 86
	view:addChild(dynamicNode) -- 87
	local start = mode == 0 and Vec3(1.8, 2.4, 0) or (mode == 1 and Vec3(ropeLength * 0.72, 4.5 - ropeLength * 0.69, 0) or Vec3(1.8, 2.4, 0)) -- 89
	dynamicNode.position = start -- 94
	dynamicNode.angles = Vec3(0, 0, 0) -- 95
	body = makeBoxBody3D( -- 96
		world, -- 96
		dynamicNode, -- 96
		Vec3(0.65, 0.55, 0.65) -- 96
	) -- 96
	if mode == 0 then -- 96
		constraint = Constraint3D:fixed( -- 99
			anchorBody, -- 99
			body, -- 99
			Vec3(0.9, 3.45, 0) -- 99
		) -- 99
	elseif mode == 1 then -- 99
		constraint = Constraint3D:distance( -- 101
			anchorBody, -- 102
			body, -- 103
			anchorBody.position, -- 104
			body.position, -- 105
			ropeLength, -- 106
			ropeLength -- 107
		) -- 107
	else -- 107
		constraint = Constraint3D:hinge( -- 110
			anchorBody, -- 111
			body, -- 112
			anchorBody.position, -- 113
			Vec3(0, 0, 1), -- 114
			-hingeLimit, -- 114
			hingeLimit -- 116
		) -- 116
	end -- 116
	state = "Connected" -- 119
	peakSpeed = 0 -- 120
end -- 82
local function push(x, y) -- 123
	body:applyLinearImpulse(Vec3(x * impulse, y * impulse, 0)) -- 124
end -- 123
view:onTapBegan(function(touch) -- 127
	selected = view:pick(touch.viewLocation) == dynamicModel -- 128
	dynamicModel.scale = selected and Vec3(0.92, 0.92, 0.92) or Vec3(0.8, 0.8, 0.8) -- 129
end) -- 127
view:onTapMoved(function(touch) -- 132
	if not selected then -- 132
		return -- 133
	end -- 133
	local velocity = body.linearVelocity -- 134
	body.linearVelocity = Vec3(velocity.x - touch.delta.x * dragGain, velocity.y + touch.delta.y * dragGain, 0) -- 135
end) -- 132
view:onTapEnded(function() -- 142
	selected = false -- 143
	dynamicModel.scale = Vec3(0.8, 0.8, 0.8) -- 144
end) -- 142
rebuild() -- 147
print("CONSTRAINT_PLAYGROUND3D_READY") -- 148
threadLoop(function() -- 150
	peakSpeed = math.max( -- 151
		peakSpeed, -- 151
		vecLength(body.linearVelocity) -- 151
	) -- 151
	ImGui.SetNextWindowPos( -- 153
		Vec2(12, 12), -- 153
		"Always" -- 153
	) -- 153
	ImGui.SetNextWindowSize( -- 154
		Vec2(350, 0), -- 154
		"Always" -- 154
	) -- 154
	ImGui.SetNextWindowBgAlpha(0.82) -- 155
	ImGui.Begin( -- 156
		"Constraint Playground", -- 156
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 156
		function() -- 156
			local changed = false -- 157
			changed, mode = ImGui.Combo("Constraint", mode, modeNames) -- 158
			if changed then -- 158
				rebuild() -- 159
			end -- 159
			if mode == 1 then -- 159
				changed, ropeLength = ImGui.DragFloat( -- 162
					"Length", -- 162
					ropeLength, -- 162
					0.05, -- 162
					1.5, -- 162
					4, -- 162
					"%.2f" -- 162
				) -- 162
				if changed then -- 162
					rebuild() -- 163
				end -- 163
			elseif mode == 2 then -- 163
				changed, hingeLimit = ImGui.DragFloat( -- 165
					"Limit", -- 165
					hingeLimit, -- 165
					1, -- 165
					10, -- 165
					170, -- 165
					"%.0f deg" -- 165
				) -- 165
				if changed then -- 165
					rebuild() -- 166
				end -- 166
			end -- 166
			changed, impulse = ImGui.DragFloat( -- 169
				"Impulse", -- 169
				impulse, -- 169
				0.1, -- 169
				0.5, -- 169
				12, -- 169
				"%.1f" -- 169
			) -- 169
			changed, dragGain = ImGui.DragFloat( -- 170
				"Drag Gain", -- 170
				dragGain, -- 170
				0.05, -- 170
				0.2, -- 170
				2.5, -- 170
				"%.2f" -- 170
			) -- 170
			changed, showAABB = ImGui.Checkbox("Show AABB", showAABB) -- 171
			if changed then -- 171
				view.showAABB = showAABB -- 172
			end -- 172
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 173
			if changed then -- 173
				world.showDebug = physicsDebug -- 174
			end -- 174
			ImGui.Separator() -- 176
			ImGui.Text("State: " .. state) -- 177
			ImGui.Text("Selected: " .. tostring(selected)) -- 178
			ImGui.Text("Speed: " .. __TS__NumberToFixed( -- 179
				vecLength(body.linearVelocity), -- 179
				2 -- 179
			)) -- 179
			ImGui.Text("Peak speed: " .. __TS__NumberToFixed(peakSpeed, 2)) -- 180
			ImGui.Text((("Position: " .. __TS__NumberToFixed(body.position.x, 2)) .. ", ") .. __TS__NumberToFixed(body.position.y, 2)) -- 181
			if ImGui.Button( -- 181
				"Left", -- 183
				Vec2(100, 30) -- 183
			) then -- 183
				push(-1, 0) -- 183
			end -- 183
			ImGui.SameLine() -- 184
			if ImGui.Button( -- 184
				"Up", -- 185
				Vec2(100, 30) -- 185
			) then -- 185
				push(0, 1) -- 185
			end -- 185
			ImGui.SameLine() -- 186
			if ImGui.Button( -- 186
				"Right", -- 187
				Vec2(100, 30) -- 187
			) then -- 187
				push(1, 0) -- 187
			end -- 187
			if ImGui.Button( -- 187
				"Break", -- 189
				Vec2(150, 30) -- 189
			) and constraint then -- 189
				constraint:destroy() -- 190
				constraint = nil -- 191
				state = "Broken" -- 192
			end -- 192
			ImGui.SameLine() -- 194
			if ImGui.Button( -- 194
				"Rebuild", -- 195
				Vec2(150, 30) -- 195
			) then -- 195
				rebuild() -- 195
			end -- 195
		end -- 156
	) -- 156
	return false -- 197
end) -- 150
return ____exports -- 150