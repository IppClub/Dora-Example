-- [ts]: Physics3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Body3D = ____Dora.Body3D -- 4
local BodyDef3D = ____Dora.BodyDef3D -- 6
local Camera3D = ____Dora.Camera3D -- 7
local Color3 = ____Dora.Color3 -- 8
local Content = ____Dora.Content -- 9
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 10
local Director = ____Dora.Director -- 11
local FixtureDef3D = ____Dora.FixtureDef3D -- 12
local Model3D = ____Dora.Model3D -- 13
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 14
local Vec2 = ____Dora.Vec2 -- 15
local Vec3 = ____Dora.Vec3 -- 16
local threadLoop = ____Dora.threadLoop -- 17
local ImGui = require("ImGui") -- 20
local view = Director.entry -- 22
local camera = Camera3D() -- 23
camera:lookAt( -- 24
	Vec3(7, 4.5, 10), -- 24
	Vec3(0, 1.5, 0) -- 24
) -- 24
Director:pushCamera(camera) -- 25
view:setEnvironmentMap("") -- 27
view:setEnvironmentIntensity(0, 0, 1) -- 28
local light = DirectionalLight3D() -- 30
light.color = Color3(16777215) -- 31
light.intensity = 4 -- 32
light.angleX = -35 -- 33
light.angleY = 30 -- 34
view:addChild(light) -- 35
local world = PhysicsWorld3D() -- 37
world.gravity = Vec3(0, -9.81, 0) -- 38
view:addChild(world) -- 39
local floorDef = BodyDef3D() -- 41
floorDef.type = PhysicsWorld3D.Static -- 42
floorDef.collisionLayer = 1 -- 43
floorDef:attach(FixtureDef3D:box(Vec3(5, 0.5, 4))) -- 44
local floorBody = Body3D( -- 45
	floorDef, -- 45
	world, -- 45
	Vec3(0, -0.5, 0) -- 45
) -- 45
view:addChild(floorBody) -- 46
local duckFile = "Test/Model3D/Assets/Model/Duck.glb" -- 48
local ducks = {} -- 49
local bodies = {} -- 50
local enterCount = 0 -- 51
local stayCount = 0 -- 52
local exitCount = 0 -- 53
local sensorCount = 0 -- 54
local rayHit = "None" -- 55
local overlapCount = 0 -- 56
do -- 56
	local i = 0 -- 58
	while i < 3 do -- 58
		local duck = Model3D(duckFile) -- 59
		duck.tag = "Duck " .. tostring(i + 1) -- 60
		duck.scale = Vec3(0.7, 0.7, 0.7) -- 61
		ducks[#ducks + 1] = duck -- 62
		local def = BodyDef3D() -- 64
		def.type = PhysicsWorld3D.Dynamic -- 65
		def:attach(FixtureDef3D:sphere(0.65)) -- 66
		local body = Body3D( -- 67
			def, -- 67
			world, -- 67
			Vec3((i - 1) * 2, 3 + i * 1.25, 0) -- 67
		) -- 67
		body.tag = duck.tag -- 68
		body:addChild(duck) -- 69
		view:addChild(body) -- 70
		body:onContactEnter(function() -- 71
			enterCount = enterCount + 1 -- 71
			return enterCount -- 71
		end) -- 71
		body:onContactStay(function() -- 72
			stayCount = stayCount + 1 -- 72
			return stayCount -- 72
		end) -- 72
		body:onContactExit(function() -- 73
			exitCount = exitCount + 1 -- 73
			return exitCount -- 73
		end) -- 73
		bodies[#bodies + 1] = body -- 74
		i = i + 1 -- 58
	end -- 58
end -- 58
local triggerDef = BodyDef3D() -- 77
triggerDef.type = PhysicsWorld3D.Static -- 78
triggerDef.sensor = true -- 79
triggerDef:attach(FixtureDef3D:box(Vec3(3.5, 0.15, 2))) -- 80
local trigger = Body3D( -- 81
	triggerDef, -- 81
	world, -- 81
	Vec3(0, 2.1, 0) -- 81
) -- 81
view:addChild(trigger) -- 82
trigger:onContactEnter(function() -- 83
	sensorCount = sensorCount + 1 -- 83
	return sensorCount -- 83
end) -- 83
bodies[1]:applyLinearImpulse(Vec3(1.8, 1, 0)) -- 85
print((("PHYSICS3D_READY bodies=" .. tostring(#bodies)) .. " gravity=") .. tostring(world.gravity.y)) -- 86
local queryTimer = 0 -- 88
local verificationTimer = 0 -- 89
local verified = false -- 90
local verificationStatus = "Pending" -- 91
threadLoop(function() -- 92
	queryTimer = queryTimer + App.deltaTime -- 93
	verificationTimer = verificationTimer + App.deltaTime -- 94
	if queryTimer >= 0.25 then -- 94
		queryTimer = 0 -- 96
		rayHit = "None" -- 97
		world:raycast( -- 98
			Vec3(0, 8, 0), -- 98
			Vec3(0, -12, 0), -- 98
			function(body) -- 98
				rayHit = body.tag ~= "" and body.tag or "Collider" -- 99
				return true -- 100
			end -- 98
		) -- 98
		overlapCount = 0 -- 102
		world:querySphere( -- 103
			Vec3(0, 1, 0), -- 103
			4, -- 103
			function() -- 103
				overlapCount = overlapCount + 1 -- 104
				return false -- 105
			end -- 103
		) -- 103
	end -- 103
	if not verified and verificationTimer >= 3 then -- 103
		verified = true -- 110
		local passed = enterCount > 0 and stayCount > 0 and sensorCount > 0 and rayHit ~= "None" and overlapCount > 0 -- 111
		verificationStatus = passed and "PASS" or "FAIL" -- 116
		local screenshot = App:saveScreenshot("/tmp/dora-3d-physics/jolt-b-runtime") -- 117
		local positions = table.concat( -- 118
			__TS__ArrayMap( -- 118
				bodies, -- 118
				function(____, body) return __TS__NumberToFixed(body.position.y, 2) end -- 118
			), -- 118
			"," -- 118
		) -- 118
		local summary = (((((((((((((((("PHYSICS3D_SUMMARY status=" .. verificationStatus) .. " enter=") .. tostring(enterCount)) .. " stay=") .. tostring(stayCount)) .. " exit=") .. tostring(exitCount)) .. " sensor=") .. tostring(sensorCount)) .. " ray=") .. rayHit) .. " overlap=") .. tostring(overlapCount)) .. " y=") .. positions) .. " screenshot=") .. screenshot -- 119
		Content:save("/tmp/dora-3d-physics/summary.txt", summary) -- 120
		print(summary) -- 121
	end -- 121
	ImGui.SetNextWindowPos( -- 124
		Vec2(12, 12), -- 124
		"Always" -- 124
	) -- 124
	ImGui.SetNextWindowSize( -- 125
		Vec2(340, 0), -- 125
		"Always" -- 125
	) -- 125
	ImGui.SetNextWindowBgAlpha(0.75) -- 126
	ImGui.Begin( -- 127
		"JOLT-B Physics3D", -- 127
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 127
		function() -- 127
			ImGui.Text("Bodies: " .. tostring(#bodies + 2)) -- 128
			ImGui.Text((((("Contact Enter / Stay / Exit: " .. tostring(enterCount)) .. " / ") .. tostring(stayCount)) .. " / ") .. tostring(exitCount)) -- 129
			ImGui.Text("Sensor Enter: " .. tostring(sensorCount)) -- 130
			ImGui.Text("Ray: " .. rayHit) -- 131
			ImGui.Text("Overlap radius 4: " .. tostring(overlapCount)) -- 132
			ImGui.Text("Verification: " .. verificationStatus) -- 133
			if ImGui.Button( -- 133
				"Impulse All", -- 134
				Vec2(-1, 30) -- 134
			) then -- 134
				for ____, body in ipairs(bodies) do -- 135
					body:applyLinearImpulse(Vec3(0, 4.5, 0)) -- 135
				end -- 135
			end -- 135
		end -- 127
	) -- 127
	return false -- 138
end) -- 92
return ____exports -- 92