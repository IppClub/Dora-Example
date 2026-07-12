-- [ts]: ConstraintPlayground3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Camera3D = ____Dora.Camera3D -- 5
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
world.gravity = Vec3(0, -9.81, 0) -- 35
view:addChild(world) -- 36
local groundModel = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 38
view:addChild(groundModel) -- 39
local groundNode = Node3D() -- 40
groundNode.position = Vec3(0, -0.5, 0) -- 41
view:addChild(groundNode) -- 42
world:createBox( -- 43
	groundNode, -- 43
	Vec3(7, 0.5, 4), -- 43
	PhysicsWorld3D.Static -- 43
) -- 43
local anchorNode = Node3D() -- 45
anchorNode.position = Vec3(0, 4.5, 0) -- 46
view:addChild(anchorNode) -- 47
local anchorModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 48
anchorModel.scale = Vec3(0.32, 0.32, 0.32) -- 49
anchorModel.position = Vec3(0, -0.2, 0) -- 50
anchorNode:addChild(anchorModel) -- 51
local anchorBody = world:createBox( -- 52
	anchorNode, -- 52
	Vec3(0.22, 0.22, 0.22), -- 52
	PhysicsWorld3D.Static -- 52
) -- 52
local dynamicNode = Node3D() -- 54
view:addChild(dynamicNode) -- 55
local dynamicModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 56
dynamicModel.tag = "playground-duck" -- 57
dynamicModel.scale = Vec3(0.8, 0.8, 0.8) -- 58
dynamicModel.position = Vec3(0, -0.45, 0) -- 59
dynamicNode:addChild(dynamicModel) -- 60
local modeNames = {"Fixed", "Distance", "Hinge"} -- 62
local mode = 2 -- 63
local ropeLength = 2.8 -- 64
local hingeLimit = 80 -- 65
local impulse = 4 -- 66
local dragGain = 0.9 -- 67
local showAABB = false -- 68
local physicsDebug = false -- 69
local selected = false -- 70
local body = world:createBox( -- 71
	dynamicNode, -- 71
	Vec3(0.65, 0.55, 0.65) -- 71
) -- 71
local constraint -- 72
local state = "Connected" -- 73
local peakSpeed = 0 -- 74
local function vecLength(value) -- 76
	return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z) -- 76
end -- 76
local function rebuild() -- 80
	if constraint ~= nil then -- 80
		constraint:destroy() -- 81
	end -- 81
	constraint = nil -- 82
	body:destroy() -- 83
	local start = mode == 0 and Vec3(1.8, 2.4, 0) or (mode == 1 and Vec3(ropeLength * 0.72, 4.5 - ropeLength * 0.69, 0) or Vec3(1.8, 2.4, 0)) -- 85
	dynamicNode.position = start -- 90
	dynamicNode.eulerAngles = Vec3(0, 0, 0) -- 91
	body = world:createBox( -- 92
		dynamicNode, -- 92
		Vec3(0.65, 0.55, 0.65) -- 92
	) -- 92
	if mode == 0 then -- 92
		constraint = world:createFixedConstraint( -- 95
			anchorBody, -- 95
			body, -- 95
			Vec3(0.9, 3.45, 0) -- 95
		) -- 95
	elseif mode == 1 then -- 95
		constraint = world:createDistanceConstraint( -- 97
			anchorBody, -- 98
			body, -- 99
			anchorNode.position, -- 100
			dynamicNode.position, -- 101
			ropeLength, -- 102
			ropeLength -- 103
		) -- 103
	else -- 103
		constraint = world:createHingeConstraint( -- 106
			anchorBody, -- 107
			body, -- 108
			anchorNode.position, -- 109
			Vec3(0, 0, 1), -- 110
			-hingeLimit, -- 110
			hingeLimit -- 112
		) -- 112
	end -- 112
	state = "Connected" -- 115
	peakSpeed = 0 -- 116
end -- 80
local function push(x, y) -- 119
	body:applyImpulse(Vec3(x * impulse, y * impulse, 0)) -- 120
end -- 119
view:onTapBegan(function(touch) -- 123
	selected = view:pick(touch.viewLocation) == dynamicModel -- 124
	dynamicModel.scale = selected and Vec3(0.92, 0.92, 0.92) or Vec3(0.8, 0.8, 0.8) -- 125
end) -- 123
view:onTapMoved(function(touch) -- 128
	if not selected then -- 128
		return -- 129
	end -- 129
	local velocity = body.linearVelocity -- 130
	body.linearVelocity = Vec3(velocity.x - touch.delta.x * dragGain, velocity.y + touch.delta.y * dragGain, 0) -- 131
end) -- 128
view:onTapEnded(function() -- 138
	selected = false -- 139
	dynamicModel.scale = Vec3(0.8, 0.8, 0.8) -- 140
end) -- 138
rebuild() -- 143
print("CONSTRAINT_PLAYGROUND3D_READY") -- 144
threadLoop(function() -- 146
	peakSpeed = math.max( -- 147
		peakSpeed, -- 147
		vecLength(body.linearVelocity) -- 147
	) -- 147
	ImGui.SetNextWindowPos( -- 149
		Vec2(12, 12), -- 149
		"Always" -- 149
	) -- 149
	ImGui.SetNextWindowSize( -- 150
		Vec2(350, 0), -- 150
		"Always" -- 150
	) -- 150
	ImGui.SetNextWindowBgAlpha(0.82) -- 151
	ImGui.Begin( -- 152
		"Constraint Playground", -- 152
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 152
		function() -- 152
			local changed = false -- 153
			changed, mode = ImGui.Combo("Constraint", mode, modeNames) -- 154
			if changed then -- 154
				rebuild() -- 155
			end -- 155
			if mode == 1 then -- 155
				changed, ropeLength = ImGui.DragFloat( -- 158
					"Length", -- 158
					ropeLength, -- 158
					0.05, -- 158
					1.5, -- 158
					4, -- 158
					"%.2f" -- 158
				) -- 158
				if changed then -- 158
					rebuild() -- 159
				end -- 159
			elseif mode == 2 then -- 159
				changed, hingeLimit = ImGui.DragFloat( -- 161
					"Limit", -- 161
					hingeLimit, -- 161
					1, -- 161
					10, -- 161
					170, -- 161
					"%.0f deg" -- 161
				) -- 161
				if changed then -- 161
					rebuild() -- 162
				end -- 162
			end -- 162
			changed, impulse = ImGui.DragFloat( -- 165
				"Impulse", -- 165
				impulse, -- 165
				0.1, -- 165
				0.5, -- 165
				12, -- 165
				"%.1f" -- 165
			) -- 165
			changed, dragGain = ImGui.DragFloat( -- 166
				"Drag Gain", -- 166
				dragGain, -- 166
				0.05, -- 166
				0.2, -- 166
				2.5, -- 166
				"%.2f" -- 166
			) -- 166
			changed, showAABB = ImGui.Checkbox("Show AABB", showAABB) -- 167
			if changed then -- 167
				view.showAABB = showAABB -- 168
			end -- 168
			changed, physicsDebug = ImGui.Checkbox("Physics Debug", physicsDebug) -- 169
			if changed then -- 169
				world.showDebug = physicsDebug -- 170
			end -- 170
			ImGui.Separator() -- 172
			ImGui.Text("State: " .. state) -- 173
			ImGui.Text("Selected: " .. tostring(selected)) -- 174
			ImGui.Text("Speed: " .. __TS__NumberToFixed( -- 175
				vecLength(body.linearVelocity), -- 175
				2 -- 175
			)) -- 175
			ImGui.Text("Peak speed: " .. __TS__NumberToFixed(peakSpeed, 2)) -- 176
			ImGui.Text((("Position: " .. __TS__NumberToFixed(dynamicNode.position.x, 2)) .. ", ") .. __TS__NumberToFixed(dynamicNode.position.y, 2)) -- 177
			if ImGui.Button( -- 177
				"Left", -- 179
				Vec2(100, 30) -- 179
			) then -- 179
				push(-1, 0) -- 179
			end -- 179
			ImGui.SameLine() -- 180
			if ImGui.Button( -- 180
				"Up", -- 181
				Vec2(100, 30) -- 181
			) then -- 181
				push(0, 1) -- 181
			end -- 181
			ImGui.SameLine() -- 182
			if ImGui.Button( -- 182
				"Right", -- 183
				Vec2(100, 30) -- 183
			) then -- 183
				push(1, 0) -- 183
			end -- 183
			if ImGui.Button( -- 183
				"Break", -- 185
				Vec2(150, 30) -- 185
			) and constraint then -- 185
				constraint:destroy() -- 186
				constraint = nil -- 187
				state = "Broken" -- 188
			end -- 188
			ImGui.SameLine() -- 190
			if ImGui.Button( -- 190
				"Rebuild", -- 191
				Vec2(150, 30) -- 191
			) then -- 191
				rebuild() -- 191
			end -- 191
		end -- 152
	) -- 152
	return false -- 193
end) -- 146
return ____exports -- 146