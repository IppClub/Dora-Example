-- [ts]: MeshCollider3D.ts
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
local output = "/tmp/dora-3d-mesh-collider" -- 20
local meshPath = "Test/Model3D/Assets/Model/Ground.gltf" -- 21
local view = Director.entry -- 22
local camera = Camera3D() -- 23
camera:lookAt( -- 24
	Vec3(7, 5, 10), -- 24
	Vec3(0, 0.8, 0) -- 24
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
local groundVisual = Model3D(meshPath) -- 40
view:addChild(groundVisual) -- 41
local sphereNode = Node3D() -- 43
sphereNode.position = Vec3(0, 3, 0) -- 44
view:addChild(sphereNode) -- 45
local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 46
duck.scale = Vec3(0.55, 0.55, 0.55) -- 47
duck.position = Vec3(0, -0.45, 0) -- 48
sphereNode:addChild(duck) -- 49
local phase = "Loading mesh through Content" -- 51
local meshBodyCreated = false -- 52
local cacheHit = false -- 53
local rayHit = false -- 54
local elapsed = 0 -- 55
local loadTime = 0 -- 56
local stableFrames = 0 -- 57
local completed = false -- 58
local captureDelay = -1 -- 59
local screenshot = "" -- 60
local loadStarted = App.runningTime -- 61
PhysicsShape3D:loadMeshAsync( -- 63
	meshPath, -- 63
	function(shape) -- 63
		loadTime = App.runningTime - loadStarted -- 64
		if not shape.built then -- 64
			phase = "FAIL: cook" -- 66
			completed = true -- 67
			captureDelay = 0 -- 68
			screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 69
			return -- 70
		end -- 70
		local meshNode = Node3D() -- 72
		view:addChild(meshNode) -- 73
		local meshBody = world:createBody(meshNode, shape, PhysicsWorld3D.Static) -- 74
		meshBodyCreated = meshBody ~= nil -- 75
		world:createSphere(sphereNode, 0.5, PhysicsWorld3D.Dynamic) -- 76
		PhysicsShape3D:loadMeshAsync( -- 77
			meshPath, -- 77
			function(cached) -- 77
				cacheHit = cached == shape and cached.built -- 78
			end -- 77
		) -- 77
		phase = "Simulating" -- 80
	end -- 63
) -- 63
print("MESH_COLLIDER3D_READY") -- 83
threadLoop(function() -- 84
	elapsed = elapsed + App.deltaTime -- 85
	if not completed and meshBodyCreated and sphereNode.position.y < 0.65 then -- 85
		stableFrames = stableFrames + 1 -- 87
		if stableFrames >= 8 then -- 87
			world:raycast( -- 89
				Vec3(2.5, 3, 0), -- 89
				Vec3(0, -1, 0), -- 89
				6, -- 89
				function(body) -- 89
					rayHit = body.node ~= sphereNode -- 90
					return true -- 91
				end -- 89
			) -- 89
			completed = true -- 93
			phase = cacheHit and rayHit and "PASS" or "FAIL" -- 94
			screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 95
			captureDelay = 0 -- 96
		end -- 96
	elseif not meshBodyCreated then -- 96
		stableFrames = 0 -- 99
	end -- 99
	if not completed and elapsed > 8 then -- 99
		completed = true -- 103
		phase = "FAIL: timeout" -- 104
		screenshot = App:saveScreenshot(output .. "/mesh-collider") -- 105
		captureDelay = 0 -- 106
	end -- 106
	if captureDelay >= 0 then -- 106
		captureDelay = captureDelay + App.deltaTime -- 110
		if captureDelay >= 2 then -- 110
			captureDelay = -1 -- 112
			local summary = (((((((((((("MESH_COLLIDER3D_SUMMARY status=" .. (phase == "PASS" and "PASS" or "FAIL")) .. " built=") .. tostring(meshBodyCreated)) .. " cache=") .. tostring(cacheHit)) .. " ray=") .. tostring(rayHit)) .. " y=") .. __TS__NumberToFixed(sphereNode.position.y, 3)) .. " load=") .. __TS__NumberToFixed(loadTime, 3)) .. " screenshot=") .. screenshot -- 113
			Content:save(output .. "/result.txt", summary) -- 114
			print(summary) -- 115
		end -- 115
	end -- 115
	ImGui.SetNextWindowPos( -- 119
		Vec2(12, 12), -- 119
		"Always" -- 119
	) -- 119
	ImGui.SetNextWindowSize( -- 120
		Vec2(380, 0), -- 120
		"Always" -- 120
	) -- 120
	ImGui.SetNextWindowBgAlpha(0.78) -- 121
	ImGui.Begin( -- 122
		"JOLT-C Mesh Collider", -- 122
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 122
		function() -- 122
			ImGui.Text("Phase: " .. phase) -- 123
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(loadTime, 3)) .. "s") -- 124
			ImGui.Text("Cache hit: " .. tostring(cacheHit)) -- 125
			ImGui.Text("Mesh ray hit: " .. tostring(rayHit)) -- 126
			ImGui.Text("Dynamic body Y: " .. __TS__NumberToFixed(sphereNode.position.y, 2)) -- 127
		end -- 122
	) -- 122
	return false -- 129
end) -- 84
return ____exports -- 84