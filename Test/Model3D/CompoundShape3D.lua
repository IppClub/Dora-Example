-- [ts]: CompoundShape3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 5
local Content = ____Dora.Content -- 6
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 7
local Director = ____Dora.Director -- 8
local Model3D = ____Dora.Model3D -- 9
local Node3D = ____Dora.Node3D -- 10
local PhysicsShape3D = ____Dora.PhysicsShape3D -- 11
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 12
local Vec2 = ____Dora.Vec2 -- 13
local Vec3 = ____Dora.Vec3 -- 14
local threadLoop = ____Dora.threadLoop -- 15
local ImGui = require("ImGui") -- 18
local output = "/tmp/dora-3d-compound" -- 20
local view = Director.entry -- 21
local camera = Camera3D() -- 22
camera:lookAt( -- 23
	Vec3(7, 5, 11), -- 23
	Vec3(0, 1, 0) -- 23
) -- 23
Director:pushCamera(camera) -- 24
view:setEnvironmentMap("") -- 25
view:setEnvironmentIntensity(0, 0, 1) -- 26
local light = DirectionalLight3D() -- 28
light.color = Color3(16777215) -- 29
light.intensity = 4 -- 30
light.angleX = -45 -- 31
light.angleY = 25 -- 32
view:addChild(light) -- 33
local world = PhysicsWorld3D() -- 35
world.gravity = Vec3(0, -9.81, 0) -- 36
view:addChild(world) -- 37
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 39
view:addChild(floorVisual) -- 40
local floorNode = Node3D() -- 41
floorNode.position = Vec3(0, -0.5, 0) -- 42
view:addChild(floorNode) -- 43
world:createBox( -- 44
	floorNode, -- 44
	Vec3(7, 0.5, 4), -- 44
	PhysicsWorld3D.Static -- 44
) -- 44
local compoundNode = Node3D() -- 46
compoundNode.position = Vec3(0, 4, 0) -- 47
view:addChild(compoundNode) -- 48
for ____, x in ipairs({-1, 1}) do -- 50
	local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 51
	duck.position = Vec3(x, -0.45, 0) -- 52
	duck.scale = Vec3(0.55, 0.55, 0.55) -- 53
	compoundNode:addChild(duck) -- 54
end -- 54
local box = PhysicsShape3D:box(Vec3(0.55, 0.55, 0.55)) -- 57
local sphere = PhysicsShape3D:sphere(0.55) -- 58
local compound = PhysicsShape3D:compound() -- 59
local leftAdded = compound:addChild( -- 60
	box, -- 60
	Vec3(-1, 0, 0) -- 60
) -- 60
local rightAdded = compound:addChild( -- 61
	sphere, -- 61
	Vec3(1, 0, 0), -- 61
	Vec3(0, 30, 0) -- 61
) -- 61
local built = compound:build() -- 62
local frozen = not compound:addChild( -- 63
	box, -- 63
	Vec3(0, 1, 0) -- 63
) -- 63
local body = world:createBody(compoundNode, compound, PhysicsWorld3D.Dynamic) -- 64
local elapsed = 0 -- 66
local stableFrames = 0 -- 67
local leftHit = false -- 68
local rightHit = false -- 69
local phase = "Falling" -- 70
local completed = false -- 71
local captureDelay = -1 -- 72
local screenshot = "" -- 73
print("COMPOUND3D_READY") -- 75
threadLoop(function() -- 76
	elapsed = elapsed + App.deltaTime -- 77
	local velocity = body.linearVelocity -- 78
	if elapsed > 0.5 and math.abs(velocity.y) < 0.08 and compoundNode.position.y < 0.8 then -- 78
		stableFrames = stableFrames + 1 -- 80
	else -- 80
		stableFrames = 0 -- 82
	end -- 82
	if not completed and stableFrames >= 8 then -- 82
		phase = "Querying" -- 86
		local y = compoundNode.position.y + 3 -- 87
		world:raycast( -- 88
			Vec3(compoundNode.position.x - 1, y, 0), -- 88
			Vec3(0, -1, 0), -- 88
			6, -- 88
			function(hit) -- 88
				leftHit = hit == body -- 89
				return true -- 90
			end -- 88
		) -- 88
		world:raycast( -- 92
			Vec3(compoundNode.position.x + 1, y, 0), -- 92
			Vec3(0, -1, 0), -- 92
			6, -- 92
			function(hit) -- 92
				rightHit = hit == body -- 93
				return true -- 94
			end -- 92
		) -- 92
		completed = true -- 96
		phase = leftAdded and rightAdded and built and compound.built and frozen and leftHit and rightHit and "PASS" or "FAIL" -- 97
		screenshot = App:saveScreenshot(output .. "/compound-shape") -- 98
		captureDelay = 0 -- 99
	end -- 99
	if not completed and elapsed > 8 then -- 99
		completed = true -- 103
		phase = "FAIL" -- 104
		captureDelay = 0 -- 105
		screenshot = App:saveScreenshot(output .. "/compound-shape") -- 106
	end -- 106
	if captureDelay >= 0 then -- 106
		captureDelay = captureDelay + App.deltaTime -- 110
		if captureDelay >= 2 then -- 110
			captureDelay = -1 -- 112
			local summary = (((((((((((("COMPOUND3D_SUMMARY status=" .. phase) .. " built=") .. tostring(compound.built)) .. " frozen=") .. tostring(frozen)) .. " left=") .. tostring(leftHit)) .. " right=") .. tostring(rightHit)) .. " y=") .. __TS__NumberToFixed(compoundNode.position.y, 3)) .. " screenshot=") .. screenshot -- 113
			Content:save(output .. "/result.txt", summary) -- 114
			print(summary) -- 115
		end -- 115
	end -- 115
	ImGui.SetNextWindowPos( -- 119
		Vec2(12, 12), -- 119
		"Always" -- 119
	) -- 119
	ImGui.SetNextWindowSize( -- 120
		Vec2(350, 0), -- 120
		"Always" -- 120
	) -- 120
	ImGui.SetNextWindowBgAlpha(0.78) -- 121
	ImGui.Begin( -- 122
		"JOLT-C Compound Shape", -- 122
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 122
		function() -- 122
			ImGui.Text("Phase: " .. phase) -- 123
			ImGui.Text("Built: " .. tostring(compound.built)) -- 124
			ImGui.Text("Frozen: " .. tostring(frozen)) -- 125
			ImGui.Text((("Ray hits: " .. tostring(leftHit)) .. ", ") .. tostring(rightHit)) -- 126
			ImGui.Text("Body Y: " .. __TS__NumberToFixed(compoundNode.position.y, 2)) -- 127
		end -- 122
	) -- 122
	return false -- 129
end) -- 76
return ____exports -- 76