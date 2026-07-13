-- [ts]: MeshCollider3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBody3D = ____PhysicsBody3D.makeBody3D -- 1
local makeSphereBody3D = ____PhysicsBody3D.makeSphereBody3D -- 1
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 4
local Camera3D = ____Dora.Camera3D -- 6
local Color3 = ____Dora.Color3 -- 7
local Content = ____Dora.Content -- 8
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 9
local Director = ____Dora.Director -- 10
local Model3D = ____Dora.Model3D -- 11
local Node3D = ____Dora.Node3D -- 12
local FixtureDef3D = ____Dora.FixtureDef3D -- 13
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 14
local Vec2 = ____Dora.Vec2 -- 15
local Vec3 = ____Dora.Vec3 -- 16
local threadLoop = ____Dora.threadLoop -- 17
local ImGui = require("ImGui") -- 20
local output = "/tmp/dora-3d-mesh-collider" -- 22
local meshPath = "Test/Model3D/Assets/Model/Ground.gltf" -- 23
local view = Director.entry -- 24
local camera = Camera3D() -- 25
camera:lookAt( -- 26
	Vec3(7, 5, 10), -- 26
	Vec3(0, 0.8, 0) -- 26
) -- 26
Director:pushCamera(camera) -- 27
view:setEnvironmentMap("") -- 28
view:setEnvironmentIntensity(0, 0, 1) -- 29
local light = DirectionalLight3D() -- 31
light.color = Color3(16777215) -- 32
light.intensity = 4 -- 33
light.angleX = -45 -- 34
light.angleY = 25 -- 35
view:addChild(light) -- 36
local world = PhysicsWorld3D() -- 38
world.gravity = Vec3(0, -9.81, 0) -- 39
view:addChild(world) -- 40
local groundVisual = Model3D(meshPath) -- 42
view:addChild(groundVisual) -- 43
local sphereNode = Node3D() -- 45
sphereNode.position = Vec3(0, 3, 0) -- 46
view:addChild(sphereNode) -- 47
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 48
duck.scale = Vec3(0.55, 0.55, 0.55) -- 49
duck.position = Vec3(0, -0.45, 0) -- 50
sphereNode:addChild(duck) -- 51
local phase = "Loading mesh through Content" -- 53
local meshBodyCreated = false -- 54
local sphereBody -- 55
local cacheHit = false -- 56
local rayHit = false -- 57
local elapsed = 0 -- 58
local loadTime = 0 -- 59
local stableFrames = 0 -- 60
local completed = false -- 61
local captureDelay = -1 -- 62
local screenshot = "" -- 63
local loadStarted = App.runningTime -- 64
FixtureDef3D:loadMeshAsync( -- 66
	meshPath, -- 66
	function(shape) -- 66
		loadTime = App.runningTime - loadStarted -- 67
		if not shape.built then -- 67
			phase = "FAIL: cook" -- 69
			completed = true -- 70
			captureDelay = 0 -- 71
			screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 72
			return -- 73
		end -- 73
		local meshNode = Node3D() -- 75
		view:addChild(meshNode) -- 76
		local meshBody = makeBody3D(world, meshNode, shape, PhysicsWorld3D.Static) -- 77
		meshBodyCreated = meshBody ~= nil -- 78
		sphereBody = makeSphereBody3D(world, sphereNode, 0.5, PhysicsWorld3D.Dynamic) -- 79
		FixtureDef3D:loadMeshAsync( -- 80
			meshPath, -- 80
			function(cached) -- 80
				cacheHit = cached == shape and cached.built -- 81
			end -- 80
		) -- 80
		phase = "Simulating" -- 83
	end -- 66
) -- 66
print("MESH_COLLIDER3D_READY") -- 86
threadLoop(function() -- 87
	elapsed = elapsed + App.deltaTime -- 88
	if not completed and meshBodyCreated and sphereBody ~= nil and sphereBody.position.y < 0.65 then -- 88
		stableFrames = stableFrames + 1 -- 90
		if stableFrames >= 8 then -- 90
			world:raycast( -- 92
				Vec3(2.5, 3, 0), -- 92
				Vec3(2.5, -3, 0), -- 92
				function(body) -- 92
					rayHit = body ~= sphereBody -- 93
					return true -- 94
				end -- 92
			) -- 92
			completed = true -- 96
			phase = cacheHit and rayHit and "PASS" or "FAIL" -- 97
			screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 98
			captureDelay = 0 -- 99
		end -- 99
	elseif not meshBodyCreated then -- 99
		stableFrames = 0 -- 102
	end -- 102
	if not completed and elapsed > 8 then -- 102
		completed = true -- 106
		phase = "FAIL: timeout" -- 107
		screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 108
		captureDelay = 0 -- 109
	end -- 109
	if captureDelay >= 0 then -- 109
		captureDelay = captureDelay + App.deltaTime -- 113
		if captureDelay >= 2 then -- 113
			captureDelay = -1 -- 115
			local ____temp_4 = phase == "PASS" and "PASS" or "FAIL" -- 116
			local ____meshBodyCreated_5 = meshBodyCreated -- 116
			local ____cacheHit_6 = cacheHit -- 116
			local ____rayHit_7 = rayHit -- 116
			local ____opt_0 = sphereBody -- 116
			local summary = (((((((((((("MESH_COLLIDER3D_SUMMARY status=" .. ____temp_4) .. " built=") .. tostring(____meshBodyCreated_5)) .. " cache=") .. tostring(____cacheHit_6)) .. " ray=") .. tostring(____rayHit_7)) .. " y=") .. (____opt_0 and __TS__NumberToFixed(sphereBody and sphereBody.position.y, 3) or "nan")) .. " load=") .. __TS__NumberToFixed(loadTime, 3)) .. " screenshot=") .. screenshot -- 116
			Content:save(output .. "/result.txt", summary) -- 117
			print(summary) -- 118
		end -- 118
	end -- 118
	ImGui.SetNextWindowPos( -- 122
		Vec2(12, 12), -- 122
		"Always" -- 122
	) -- 122
	ImGui.SetNextWindowSize( -- 123
		Vec2(380, 0), -- 123
		"Always" -- 123
	) -- 123
	ImGui.SetNextWindowBgAlpha(0.78) -- 124
	ImGui.Begin( -- 125
		"JOLT-C Mesh Collider", -- 125
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 125
		function() -- 125
			ImGui.Text("Phase: " .. phase) -- 126
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(loadTime, 3)) .. "s") -- 127
			ImGui.Text("Cache hit: " .. tostring(cacheHit)) -- 128
			ImGui.Text("Mesh ray hit: " .. tostring(rayHit)) -- 129
			local ____ImGui_Text_12 = ImGui.Text -- 130
			local ____opt_8 = sphereBody -- 130
			____ImGui_Text_12("Dynamic body Y: " .. (____opt_8 and __TS__NumberToFixed(sphereBody and sphereBody.position.y, 2) or "n/a")) -- 130
		end -- 125
	) -- 125
	return false -- 132
end) -- 87
return ____exports -- 87