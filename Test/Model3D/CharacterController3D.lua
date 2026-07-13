-- [ts]: CharacterController3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
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
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 12
local Vec2 = ____Dora.Vec2 -- 13
local Vec3 = ____Dora.Vec3 -- 14
local threadLoop = ____Dora.threadLoop -- 15
local ImGui = require("ImGui") -- 18
local output = "/tmp/dora-3d-character" -- 20
local view = Director.entry -- 21
local camera = Camera3D() -- 22
camera:lookAt( -- 23
	Vec3(8, 4.5, 10), -- 23
	Vec3(1.5, 1, 0) -- 23
) -- 23
Director:pushCamera(camera) -- 24
view:setEnvironmentMap("") -- 25
view:setEnvironmentIntensity(0, 0, 1) -- 26
local light = DirectionalLight3D() -- 28
light.color = Color3(16777215) -- 29
light.intensity = 4 -- 30
light.angleX = -40 -- 31
light.angleY = 25 -- 32
view:addChild(light) -- 33
local world = PhysicsWorld3D() -- 35
world.gravity = Vec3(0, -9.81, 0) -- 36
view:addChild(world) -- 37
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 39
view:addChild(floorVisual) -- 40
local floor = Node3D() -- 41
floor.position = Vec3(0, -0.5, 0) -- 42
view:addChild(floor) -- 43
makeBoxBody3D( -- 44
	world, -- 44
	floor, -- 44
	Vec3(7, 0.5, 4), -- 44
	PhysicsWorld3D.Static -- 44
) -- 44
local characterNode = Node3D() -- 46
characterNode.position = Vec3(-2.5, 3, 0) -- 47
view:addChild(characterNode) -- 48
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 49
duck.scale = Vec3(0.65, 0.65, 0.65) -- 50
duck.position = Vec3(0, 0.15, 0) -- 51
characterNode:addChild(duck) -- 52
local character = world:createCharacter( -- 54
	characterNode, -- 54
	0.5, -- 54
	0.3, -- 54
	50, -- 54
	0.4 -- 54
) -- 54
character.collisionLayer = 0 -- 55
character.collisionMask = 4294967295 -- 56
local phase = "Falling" -- 58
local groundedFrames = 0 -- 59
local walkedFrom = 0 -- 60
local jumped = false -- 61
local jumpPeak = 0 -- 62
local relandedFrames = 0 -- 63
local completed = false -- 64
local elapsed = 0 -- 65
local captureDelay = -1 -- 66
local screenshot = "" -- 67
print("CHARACTER3D_READY") -- 69
threadLoop(function() -- 70
	elapsed = elapsed + App.deltaTime -- 71
	jumpPeak = math.max(jumpPeak, characterNode.position.y) -- 72
	if not jumped and character.grounded then -- 72
		groundedFrames = groundedFrames + 1 -- 75
		if phase == "Falling" and groundedFrames >= 5 then -- 75
			phase = "Walking" -- 77
			walkedFrom = characterNode.position.x -- 78
			character.desiredVelocity = Vec3(2, 0, 0) -- 79
		end -- 79
		if phase == "Walking" and characterNode.position.x - walkedFrom > 1.2 then -- 79
			phase = "Jumping" -- 82
			jumped = true -- 83
			jumpPeak = characterNode.position.y -- 84
			character:jump(5) -- 85
		end -- 85
	elseif jumped and not character.grounded then -- 85
		phase = "Airborne" -- 88
	elseif jumped and character.grounded and phase == "Airborne" then -- 88
		phase = "Relanded" -- 90
		relandedFrames = 1 -- 91
		character.desiredVelocity = Vec3(0, 0, 0) -- 92
	elseif phase == "Relanded" and character.grounded and not completed then -- 92
		relandedFrames = relandedFrames + 1 -- 94
		if relandedFrames < 5 then -- 94
			return false -- 95
		end -- 95
		completed = true -- 96
		phase = "PASS" -- 97
		screenshot = App:saveScreenshot(output .. "/character-controller") -- 98
		captureDelay = 0 -- 99
	end -- 99
	if captureDelay >= 0 then -- 99
		captureDelay = captureDelay + App.deltaTime -- 102
		if captureDelay >= 0.75 then -- 102
			captureDelay = -1 -- 104
			local summary = (((((((("CHARACTER3D_SUMMARY status=PASS x=" .. __TS__NumberToFixed(characterNode.position.x, 3)) .. " y=") .. __TS__NumberToFixed(characterNode.position.y, 3)) .. " peak=") .. __TS__NumberToFixed(jumpPeak, 3)) .. " grounded=") .. tostring(character.grounded)) .. " screenshot=") .. screenshot -- 105
			Content:save(output .. "/result.txt", summary) -- 106
			print(summary) -- 107
		end -- 107
	end -- 107
	if not completed and elapsed > 10 then -- 107
		completed = true -- 112
		phase = "FAIL" -- 113
		local summary = (((((("CHARACTER3D_SUMMARY status=FAIL x=" .. __TS__NumberToFixed(characterNode.position.x, 3)) .. " y=") .. __TS__NumberToFixed(characterNode.position.y, 3)) .. " peak=") .. __TS__NumberToFixed(jumpPeak, 3)) .. " grounded=") .. tostring(character.grounded) -- 114
		Content:save(output .. "/result.txt", summary) -- 115
		print(summary) -- 116
	end -- 116
	ImGui.SetNextWindowPos( -- 119
		Vec2(12, 12), -- 119
		"Always" -- 119
	) -- 119
	ImGui.SetNextWindowSize( -- 120
		Vec2(330, 0), -- 120
		"Always" -- 120
	) -- 120
	ImGui.SetNextWindowBgAlpha(0.78) -- 121
	ImGui.Begin( -- 122
		"JOLT-C Character", -- 122
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 122
		function() -- 122
			ImGui.Text("Phase: " .. phase) -- 123
			ImGui.Text((("Position: " .. __TS__NumberToFixed(characterNode.position.x, 2)) .. ", ") .. __TS__NumberToFixed(characterNode.position.y, 2)) -- 124
			ImGui.Text((("Velocity: " .. __TS__NumberToFixed(character.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(character.velocity.y, 2)) -- 125
			ImGui.Text("Grounded: " .. tostring(character.grounded)) -- 126
			if ImGui.Button( -- 126
				"Jump", -- 127
				Vec2(-1, 30) -- 127
			) then -- 127
				character:jump(5) -- 127
			end -- 127
		end -- 122
	) -- 122
	return false -- 129
end) -- 70
return ____exports -- 70