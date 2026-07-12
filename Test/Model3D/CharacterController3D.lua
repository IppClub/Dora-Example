-- [ts]: CharacterController3D.ts
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
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 11
local Vec2 = ____Dora.Vec2 -- 12
local Vec3 = ____Dora.Vec3 -- 13
local threadLoop = ____Dora.threadLoop -- 14
local ImGui = require("ImGui") -- 17
local output = "/tmp/dora-3d-character" -- 19
local view = Director.entry -- 20
local camera = Camera3D() -- 21
camera:lookAt( -- 22
	Vec3(8, 4.5, 10), -- 22
	Vec3(1.5, 1, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("") -- 24
view:setEnvironmentIntensity(0, 0, 1) -- 25
local light = DirectionalLight3D() -- 27
light.color = Color3(16777215) -- 28
light.intensity = 4 -- 29
light.angleX = -40 -- 30
light.angleY = 25 -- 31
view:addChild(light) -- 32
local world = PhysicsWorld3D() -- 34
world.gravity = Vec3(0, -9.81, 0) -- 35
view:addChild(world) -- 36
local floorVisual = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 38
view:addChild(floorVisual) -- 39
local floor = Node3D() -- 40
floor.position = Vec3(0, -0.5, 0) -- 41
view:addChild(floor) -- 42
world:createBox( -- 43
	floor, -- 43
	Vec3(7, 0.5, 4), -- 43
	PhysicsWorld3D.Static -- 43
) -- 43
local characterNode = Node3D() -- 45
characterNode.position = Vec3(-2.5, 3, 0) -- 46
view:addChild(characterNode) -- 47
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 48
duck.scale = Vec3(0.65, 0.65, 0.65) -- 49
duck.position = Vec3(0, 0.15, 0) -- 50
characterNode:addChild(duck) -- 51
local character = world:createCharacter( -- 53
	characterNode, -- 53
	0.5, -- 53
	0.3, -- 53
	50, -- 53
	0.4 -- 53
) -- 53
character.collisionLayer = 0 -- 54
character.collisionMask = 4294967295 -- 55
local phase = "Falling" -- 57
local groundedFrames = 0 -- 58
local walkedFrom = 0 -- 59
local jumped = false -- 60
local jumpPeak = 0 -- 61
local relandedFrames = 0 -- 62
local completed = false -- 63
local elapsed = 0 -- 64
local captureDelay = -1 -- 65
local screenshot = "" -- 66
print("CHARACTER3D_READY") -- 68
threadLoop(function() -- 69
	elapsed = elapsed + App.deltaTime -- 70
	jumpPeak = math.max(jumpPeak, characterNode.position.y) -- 71
	if not jumped and character.grounded then -- 71
		groundedFrames = groundedFrames + 1 -- 74
		if phase == "Falling" and groundedFrames >= 5 then -- 74
			phase = "Walking" -- 76
			walkedFrom = characterNode.position.x -- 77
			character.desiredVelocity = Vec3(2, 0, 0) -- 78
		end -- 78
		if phase == "Walking" and characterNode.position.x - walkedFrom > 1.2 then -- 78
			phase = "Jumping" -- 81
			jumped = true -- 82
			jumpPeak = characterNode.position.y -- 83
			character:jump(5) -- 84
		end -- 84
	elseif jumped and not character.grounded then -- 84
		phase = "Airborne" -- 87
	elseif jumped and character.grounded and phase == "Airborne" then -- 87
		phase = "Relanded" -- 89
		relandedFrames = 1 -- 90
		character.desiredVelocity = Vec3(0, 0, 0) -- 91
	elseif phase == "Relanded" and character.grounded and not completed then -- 91
		relandedFrames = relandedFrames + 1 -- 93
		if relandedFrames < 5 then -- 93
			return false -- 94
		end -- 94
		completed = true -- 95
		phase = "PASS" -- 96
		screenshot = App:saveScreenshot(output .. "/character-controller") -- 97
		captureDelay = 0 -- 98
	end -- 98
	if captureDelay >= 0 then -- 98
		captureDelay = captureDelay + App.deltaTime -- 101
		if captureDelay >= 0.75 then -- 101
			captureDelay = -1 -- 103
			local summary = (((((((("CHARACTER3D_SUMMARY status=PASS x=" .. __TS__NumberToFixed(characterNode.position.x, 3)) .. " y=") .. __TS__NumberToFixed(characterNode.position.y, 3)) .. " peak=") .. __TS__NumberToFixed(jumpPeak, 3)) .. " grounded=") .. tostring(character.grounded)) .. " screenshot=") .. screenshot -- 104
			Content:save(output .. "/result.txt", summary) -- 105
			print(summary) -- 106
		end -- 106
	end -- 106
	if not completed and elapsed > 10 then -- 106
		completed = true -- 111
		phase = "FAIL" -- 112
		local summary = (((((("CHARACTER3D_SUMMARY status=FAIL x=" .. __TS__NumberToFixed(characterNode.position.x, 3)) .. " y=") .. __TS__NumberToFixed(characterNode.position.y, 3)) .. " peak=") .. __TS__NumberToFixed(jumpPeak, 3)) .. " grounded=") .. tostring(character.grounded) -- 113
		Content:save(output .. "/result.txt", summary) -- 114
		print(summary) -- 115
	end -- 115
	ImGui.SetNextWindowPos( -- 118
		Vec2(12, 12), -- 118
		"Always" -- 118
	) -- 118
	ImGui.SetNextWindowSize( -- 119
		Vec2(330, 0), -- 119
		"Always" -- 119
	) -- 119
	ImGui.SetNextWindowBgAlpha(0.78) -- 120
	ImGui.Begin( -- 121
		"JOLT-C Character", -- 121
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 121
		function() -- 121
			ImGui.Text("Phase: " .. phase) -- 122
			ImGui.Text((("Position: " .. __TS__NumberToFixed(characterNode.position.x, 2)) .. ", ") .. __TS__NumberToFixed(characterNode.position.y, 2)) -- 123
			ImGui.Text((("Velocity: " .. __TS__NumberToFixed(character.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(character.velocity.y, 2)) -- 124
			ImGui.Text("Grounded: " .. tostring(character.grounded)) -- 125
			if ImGui.Button( -- 125
				"Jump", -- 126
				Vec2(-1, 30) -- 126
			) then -- 126
				character:jump(5) -- 126
			end -- 126
		end -- 121
	) -- 121
	return false -- 128
end) -- 69
return ____exports -- 69