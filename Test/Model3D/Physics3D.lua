-- [ts]: Physics3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
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
local view = Director.entry -- 20
local camera = Camera3D() -- 21
camera:lookAt( -- 22
	Vec3(7, 4.5, 10), -- 22
	Vec3(0, 1.5, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("") -- 25
view:setEnvironmentIntensity(0, 0, 1) -- 26
local light = DirectionalLight3D() -- 28
light.color = Color3(16777215) -- 29
light.intensity = 4 -- 30
light.angleX = -35 -- 31
light.angleY = 30 -- 32
view:addChild(light) -- 33
local world = PhysicsWorld3D() -- 35
world.gravity = Vec3(0, -9.81, 0) -- 36
view:addChild(world) -- 37
local floor = Node3D() -- 39
floor.position = Vec3(0, -0.5, 0) -- 40
view:addChild(floor) -- 41
local floorBody = world:createBox( -- 42
	floor, -- 42
	Vec3(5, 0.5, 4), -- 42
	PhysicsWorld3D.Static -- 42
) -- 42
floorBody.collisionLayer = 1 -- 43
local duckFile = "Test/Model3D/Assets/Model/Duck.glb" -- 45
local ducks = {} -- 46
local bodies = {} -- 47
local enterCount = 0 -- 48
local stayCount = 0 -- 49
local exitCount = 0 -- 50
local sensorCount = 0 -- 51
local rayHit = "None" -- 52
local overlapCount = 0 -- 53
do -- 53
	local i = 0 -- 55
	while i < 3 do -- 55
		local duck = Model3D(duckFile) -- 56
		duck.tag = "Duck " .. tostring(i + 1) -- 57
		duck.position = Vec3((i - 1) * 2, 3 + i * 1.25, 0) -- 58
		duck.scale = Vec3(0.7, 0.7, 0.7) -- 59
		view:addChild(duck) -- 60
		ducks[#ducks + 1] = duck -- 61
		local body = world:createSphere(duck, 0.65, PhysicsWorld3D.Dynamic) -- 63
		body.collisionLayer = 0 -- 64
		body.collisionMask = 4294967295 -- 65
		body:onContactEnter(function() -- 66
			enterCount = enterCount + 1 -- 66
			return enterCount -- 66
		end) -- 66
		body:onContactStay(function() -- 67
			stayCount = stayCount + 1 -- 67
			return stayCount -- 67
		end) -- 67
		body:onContactExit(function() -- 68
			exitCount = exitCount + 1 -- 68
			return exitCount -- 68
		end) -- 68
		bodies[#bodies + 1] = body -- 69
		i = i + 1 -- 55
	end -- 55
end -- 55
local triggerNode = Node3D() -- 72
triggerNode.position = Vec3(0, 2.1, 0) -- 73
view:addChild(triggerNode) -- 74
local trigger = world:createBox( -- 75
	triggerNode, -- 75
	Vec3(3.5, 0.15, 2), -- 75
	PhysicsWorld3D.Static -- 75
) -- 75
trigger.sensor = true -- 76
trigger:onContactEnter(function() -- 77
	sensorCount = sensorCount + 1 -- 77
	return sensorCount -- 77
end) -- 77
bodies[1]:applyImpulse(Vec3(1.8, 1, 0)) -- 79
print((("PHYSICS3D_READY bodies=" .. tostring(#bodies)) .. " gravity=") .. tostring(world.gravity.y)) -- 80
local queryTimer = 0 -- 82
local verificationTimer = 0 -- 83
local verified = false -- 84
local verificationStatus = "Pending" -- 85
threadLoop(function() -- 86
	queryTimer = queryTimer + App.deltaTime -- 87
	verificationTimer = verificationTimer + App.deltaTime -- 88
	if queryTimer >= 0.25 then -- 88
		queryTimer = 0 -- 90
		rayHit = "None" -- 91
		world:raycast( -- 92
			Vec3(0, 8, 0), -- 92
			Vec3(0, -1, 0), -- 92
			20, -- 92
			function(body, _point, _normal, distance) -- 92
				local ____opt_0 = body.node -- 92
				rayHit = ((____opt_0 and ____opt_0.tag or "Collider") .. " @ ") .. __TS__NumberToFixed(distance, 2) -- 93
				return true -- 94
			end -- 92
		) -- 92
		overlapCount = 0 -- 96
		world:overlapSphere( -- 97
			Vec3(0, 1, 0), -- 97
			4, -- 97
			function() -- 97
				overlapCount = overlapCount + 1 -- 98
				return false -- 99
			end -- 97
		) -- 97
	end -- 97
	if not verified and verificationTimer >= 3 then -- 97
		verified = true -- 104
		local passed = enterCount > 0 and stayCount > 0 and sensorCount > 0 and rayHit ~= "None" and overlapCount > 0 -- 105
		verificationStatus = passed and "PASS" or "FAIL" -- 110
		local screenshot = App:saveScreenshot("/tmp/dora-3d-physics/jolt-b-runtime") -- 111
		local positions = table.concat( -- 112
			__TS__ArrayMap( -- 112
				ducks, -- 112
				function(____, duck) return __TS__NumberToFixed(duck.position.y, 2) end -- 112
			), -- 112
			"," -- 112
		) -- 112
		local summary = (((((((((((((((("PHYSICS3D_SUMMARY status=" .. verificationStatus) .. " enter=") .. tostring(enterCount)) .. " stay=") .. tostring(stayCount)) .. " exit=") .. tostring(exitCount)) .. " sensor=") .. tostring(sensorCount)) .. " ray=") .. rayHit) .. " overlap=") .. tostring(overlapCount)) .. " y=") .. positions) .. " screenshot=") .. screenshot -- 113
		Content:save("/tmp/dora-3d-physics/summary.txt", summary) -- 114
		print(summary) -- 115
	end -- 115
	ImGui.SetNextWindowPos( -- 118
		Vec2(12, 12), -- 118
		"Always" -- 118
	) -- 118
	ImGui.SetNextWindowSize( -- 119
		Vec2(340, 0), -- 119
		"Always" -- 119
	) -- 119
	ImGui.SetNextWindowBgAlpha(0.75) -- 120
	ImGui.Begin( -- 121
		"JOLT-B Physics3D", -- 121
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 121
		function() -- 121
			ImGui.Text("Bodies: " .. tostring(#bodies + 2)) -- 122
			ImGui.Text((((("Contact Enter / Stay / Exit: " .. tostring(enterCount)) .. " / ") .. tostring(stayCount)) .. " / ") .. tostring(exitCount)) -- 123
			ImGui.Text("Sensor Enter: " .. tostring(sensorCount)) -- 124
			ImGui.Text("Ray: " .. rayHit) -- 125
			ImGui.Text("Overlap radius 4: " .. tostring(overlapCount)) -- 126
			ImGui.Text("Verification: " .. verificationStatus) -- 127
			if ImGui.Button( -- 127
				"Impulse All", -- 128
				Vec2(-1, 30) -- 128
			) then -- 128
				for ____, body in ipairs(bodies) do -- 129
					body:applyImpulse(Vec3(0, 4.5, 0)) -- 129
				end -- 129
			end -- 129
		end -- 121
	) -- 121
	return false -- 132
end) -- 86
return ____exports -- 86