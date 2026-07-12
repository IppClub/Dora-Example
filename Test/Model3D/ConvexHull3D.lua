-- [ts]: ConvexHull3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
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
local PhysicsShape3D = ____Dora.PhysicsShape3D -- 12
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 14
local Vec2 = ____Dora.Vec2 -- 15
local Vec3 = ____Dora.Vec3 -- 16
local threadLoop = ____Dora.threadLoop -- 17
local ImGui = require("ImGui") -- 20
local output = "/tmp/dora-3d-convex-hull" -- 22
local modelPath = "Test/Model3D/Assets/Model/Duck.glb" -- 23
local view = Director.entry -- 24
local camera = Camera3D() -- 25
camera:lookAt( -- 26
	Vec3(7, 5, 10), -- 26
	Vec3(0, 1, 0) -- 26
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
local floorNode = Node3D() -- 42
floorNode.position = Vec3(0, -0.5, 0) -- 43
view:addChild(floorNode) -- 44
world:createBox( -- 45
	floorNode, -- 45
	Vec3(7, 0.5, 4), -- 45
	PhysicsWorld3D.Static -- 45
) -- 45
local hullNode = Node3D() -- 47
hullNode.position = Vec3(0, 4, 0) -- 48
view:addChild(hullNode) -- 49
local duck = Model3D(modelPath) -- 50
hullNode:addChild(duck) -- 51
local phase = "Loading convex hull through Content" -- 53
local hullShape -- 54
local hullBody -- 55
local hullBuilt = false -- 56
local cacheHit = false -- 57
local cacheIsolated = false -- 58
local dynamicCreated = false -- 59
local rotated = false -- 60
local rayHit = false -- 61
local elapsed = 0 -- 62
local loadTime = 0 -- 63
local stableFrames = 0 -- 64
local completed = false -- 65
local captureDelay = -1 -- 66
local screenshot = "" -- 67
local loadStarted = App.runningTime -- 68
PhysicsShape3D:loadConvexHullAsync( -- 70
	modelPath, -- 70
	function(shape) -- 70
		loadTime = App.runningTime - loadStarted -- 71
		hullShape = shape -- 72
		hullBuilt = shape.built -- 73
		if not hullBuilt then -- 73
			phase = "FAIL: hull cook" -- 75
			completed = true -- 76
			captureDelay = 0 -- 77
			return -- 78
		end -- 78
		PhysicsShape3D:loadConvexHullAsync( -- 80
			modelPath, -- 80
			function(cached) -- 80
				cacheHit = cached == shape and cached.built -- 81
			end -- 80
		) -- 80
		PhysicsShape3D:loadMeshAsync( -- 83
			modelPath, -- 83
			function(mesh) -- 83
				cacheIsolated = mesh ~= shape and mesh.built -- 84
			end -- 83
		) -- 83
		hullBody = world:createBody(hullNode, shape, PhysicsWorld3D.Dynamic) -- 86
		dynamicCreated = hullBody ~= nil -- 87
		hullBody.angularVelocity = Vec3(0.4, 1.2, 0.25) -- 88
		phase = "Dynamic hull falling" -- 89
	end -- 70
) -- 70
print("CONVEX_HULL3D_READY") -- 92
threadLoop(function() -- 93
	elapsed = elapsed + App.deltaTime -- 94
	rotated = rotated or math.abs(hullNode.eulerAngles.y) > 5 or math.abs(hullNode.eulerAngles.x) > 5 -- 95
	if not completed and hullBody ~= nil and elapsed > 1 and hullNode.position.y < 2 and math.abs(hullBody.linearVelocity.y) < 0.08 then -- 95
		stableFrames = stableFrames + 1 -- 103
		if stableFrames >= 20 then -- 103
			world:raycast( -- 105
				Vec3(hullNode.position.x, hullNode.position.y + 5, hullNode.position.z), -- 105
				Vec3(0, -1, 0), -- 105
				10, -- 105
				function(body) -- 105
					rayHit = body.node == hullNode -- 106
					return true -- 107
				end -- 105
			) -- 105
			completed = true -- 109
			phase = hullBuilt and cacheHit and cacheIsolated and dynamicCreated and rotated and rayHit and "PASS" or "FAIL" -- 110
			screenshot = App:saveScreenshot(output .. "/convex-hull") -- 111
			captureDelay = 0 -- 112
		end -- 112
	elseif not dynamicCreated then -- 112
		stableFrames = 0 -- 115
	end -- 115
	if not completed and elapsed > 12 then -- 115
		completed = true -- 119
		phase = "FAIL: timeout" -- 120
		screenshot = App:saveScreenshot(output .. "/convex-hull") -- 121
		captureDelay = 0 -- 122
	end -- 122
	if captureDelay >= 0 then -- 122
		captureDelay = captureDelay + App.deltaTime -- 126
		if captureDelay >= 2 then -- 126
			captureDelay = -1 -- 128
			local summary = (((((((((((((((((("CONVEX_HULL3D_SUMMARY status=" .. (phase == "PASS" and "PASS" or "FAIL")) .. " built=") .. tostring(hullBuilt)) .. " cache=") .. tostring(cacheHit)) .. " isolated=") .. tostring(cacheIsolated)) .. " dynamic=") .. tostring(dynamicCreated)) .. " rotated=") .. tostring(rotated)) .. " ray=") .. tostring(rayHit)) .. " y=") .. __TS__NumberToFixed(hullNode.position.y, 3)) .. " load=") .. __TS__NumberToFixed(loadTime, 3)) .. " screenshot=") .. screenshot -- 129
			Content:save(output .. "/result.txt", summary) -- 130
			print(summary) -- 131
		end -- 131
	end -- 131
	ImGui.SetNextWindowPos( -- 135
		Vec2(12, 12), -- 135
		"Always" -- 135
	) -- 135
	ImGui.SetNextWindowSize( -- 136
		Vec2(380, 0), -- 136
		"Always" -- 136
	) -- 136
	ImGui.SetNextWindowBgAlpha(0.78) -- 137
	ImGui.Begin( -- 138
		"JOLT-C Dynamic Convex Hull", -- 138
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 138
		function() -- 138
			ImGui.Text("Phase: " .. phase) -- 139
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(loadTime, 3)) .. "s") -- 140
			ImGui.Text((("Hull built/cache: " .. tostring(hullBuilt)) .. "/") .. tostring(cacheHit)) -- 141
			ImGui.Text("Mesh cache isolated: " .. tostring(cacheIsolated)) -- 142
			ImGui.Text((((("Dynamic/rotated/ray: " .. tostring(dynamicCreated)) .. "/") .. tostring(rotated)) .. "/") .. tostring(rayHit)) -- 143
			ImGui.Text("Body Y: " .. __TS__NumberToFixed(hullNode.position.y, 2)) -- 144
		end -- 138
	) -- 138
	return false -- 146
end) -- 93
return ____exports -- 93