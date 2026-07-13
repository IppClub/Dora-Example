-- [ts]: CompoundShape3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBody3D = ____PhysicsBody3D.makeBody3D -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local Content = ____Dora.Content -- 7
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Director = ____Dora.Director -- 9
local Model3D = ____Dora.Model3D -- 10
local Node3D = ____Dora.Node3D -- 11
local FixtureDef3D = ____Dora.FixtureDef3D -- 12
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 13
local Vec2 = ____Dora.Vec2 -- 14
local Vec3 = ____Dora.Vec3 -- 15
local threadLoop = ____Dora.threadLoop -- 16
local ImGui = require("ImGui") -- 19
local output = "/tmp/dora-3d-compound" -- 21
local view = Director.entry -- 22
local camera = Camera3D() -- 23
camera:lookAt( -- 24
	Vec3(7, 5, 11), -- 24
	Vec3(0, 1, 0) -- 24
) -- 24
Director:pushCamera(camera) -- 25
view:setEnvironmentMap("") -- 26
view:setEnvironmentIntensity(0, 0, 1) -- 27
local light = DirectionalLight3D() -- 29
light.color = Color3(16777215) -- 30
light.intensity = 4 -- 31
light.angleX = -45 -- 32
light.angleY = 25 -- 33
view:addChild(light) -- 34
local world = PhysicsWorld3D() -- 36
world.gravity = Vec3(0, -9.81, 0) -- 37
view:addChild(world) -- 38
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 40
view:addChild(floorVisual) -- 41
local floorNode = Node3D() -- 42
floorNode.position = Vec3(0, -0.5, 0) -- 43
view:addChild(floorNode) -- 44
makeBoxBody3D( -- 45
	world, -- 45
	floorNode, -- 45
	Vec3(7, 0.5, 4), -- 45
	PhysicsWorld3D.Static -- 45
) -- 45
local compoundNode = Node3D() -- 47
compoundNode.position = Vec3(0, 4, 0) -- 48
view:addChild(compoundNode) -- 49
for ____, x in ipairs({-1, 1}) do -- 51
	local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 52
	duck.position = Vec3(x, -0.45, 0) -- 53
	duck.scale = Vec3(0.55, 0.55, 0.55) -- 54
	compoundNode:addChild(duck) -- 55
end -- 55
local box = FixtureDef3D:box(Vec3(0.55, 0.55, 0.55)) -- 58
local sphere = FixtureDef3D:sphere(0.55) -- 59
local compound = FixtureDef3D:compound() -- 60
local leftAdded = compound:addChild( -- 61
	box, -- 61
	Vec3(-1, 0, 0) -- 61
) -- 61
local rightAdded = compound:addChild( -- 62
	sphere, -- 62
	Vec3(1, 0, 0), -- 62
	Vec3(0, 30, 0) -- 62
) -- 62
local built = compound:build() -- 63
local frozen = not compound:addChild( -- 64
	box, -- 64
	Vec3(0, 1, 0) -- 64
) -- 64
local body = makeBody3D(world, compoundNode, compound, PhysicsWorld3D.Dynamic) -- 65
local elapsed = 0 -- 67
local stableFrames = 0 -- 68
local leftHit = false -- 69
local rightHit = false -- 70
local phase = "Falling" -- 71
local completed = false -- 72
local captureDelay = -1 -- 73
local screenshot = "" -- 74
print("COMPOUND3D_READY") -- 76
threadLoop(function() -- 77
	elapsed = elapsed + App.deltaTime -- 78
	local velocity = body.linearVelocity -- 79
	if elapsed > 0.5 and math.abs(velocity.y) < 0.08 and body.position.y < 0.8 then -- 79
		stableFrames = stableFrames + 1 -- 81
	else -- 81
		stableFrames = 0 -- 83
	end -- 83
	if not completed and stableFrames >= 8 then -- 83
		phase = "Querying" -- 87
		local y = body.position.y + 3 -- 88
		world:raycast( -- 89
			Vec3(body.position.x - 1, y, 0), -- 89
			Vec3(body.position.x - 1, y - 6, 0), -- 89
			function(hit) -- 89
				leftHit = hit == body -- 90
				return true -- 91
			end -- 89
		) -- 89
		world:raycast( -- 93
			Vec3(body.position.x + 1, y, 0), -- 93
			Vec3(body.position.x + 1, y - 6, 0), -- 93
			function(hit) -- 93
				rightHit = hit == body -- 94
				return true -- 95
			end -- 93
		) -- 93
		completed = true -- 97
		phase = leftAdded and rightAdded and built and compound.built and frozen and leftHit and rightHit and "PASS" or "FAIL" -- 98
		screenshot = App:saveScreenshot(output .. "/compound-shape") -- 99
		captureDelay = 0 -- 100
	end -- 100
	if not completed and elapsed > 8 then -- 100
		completed = true -- 104
		phase = "FAIL" -- 105
		captureDelay = 0 -- 106
		screenshot = App:saveScreenshot(output .. "/compound-shape") -- 107
	end -- 107
	if captureDelay >= 0 then -- 107
		captureDelay = captureDelay + App.deltaTime -- 111
		if captureDelay >= 2 then -- 111
			captureDelay = -1 -- 113
			local summary = (((((((((((("COMPOUND3D_SUMMARY status=" .. phase) .. " built=") .. tostring(compound.built)) .. " frozen=") .. tostring(frozen)) .. " left=") .. tostring(leftHit)) .. " right=") .. tostring(rightHit)) .. " y=") .. __TS__NumberToFixed(body.position.y, 3)) .. " screenshot=") .. screenshot -- 114
			Content:save(output .. "/result.txt", summary) -- 115
			print(summary) -- 116
		end -- 116
	end -- 116
	ImGui.SetNextWindowPos( -- 120
		Vec2(12, 12), -- 120
		"Always" -- 120
	) -- 120
	ImGui.SetNextWindowSize( -- 121
		Vec2(350, 0), -- 121
		"Always" -- 121
	) -- 121
	ImGui.SetNextWindowBgAlpha(0.78) -- 122
	ImGui.Begin( -- 123
		"JOLT-C Compound Shape", -- 123
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 123
		function() -- 123
			ImGui.Text("Phase: " .. phase) -- 124
			ImGui.Text("Built: " .. tostring(compound.built)) -- 125
			ImGui.Text("Frozen: " .. tostring(frozen)) -- 126
			ImGui.Text((("Ray hits: " .. tostring(leftHit)) .. ", ") .. tostring(rightHit)) -- 127
			ImGui.Text("Body Y: " .. __TS__NumberToFixed(body.position.y, 2)) -- 128
		end -- 123
	) -- 123
	return false -- 130
end) -- 77
return ____exports -- 77