-- [ts]: ConvexHull3D.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____PhysicsBody3D = require("PhysicsBody3D") -- 1
local makeBody3D = ____PhysicsBody3D.makeBody3D -- 1
local makeBoxBody3D = ____PhysicsBody3D.makeBoxBody3D -- 1
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
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 15
local Vec2 = ____Dora.Vec2 -- 16
local Vec3 = ____Dora.Vec3 -- 17
local threadLoop = ____Dora.threadLoop -- 18
local ImGui = require("ImGui") -- 21
local output = "/tmp/dora-3d-convex-hull" -- 23
local modelPath = "Test/Model3D/Assets/Model/Duck.glb" -- 24
local view = Director.entry -- 25
local camera = Camera3D() -- 26
camera:lookAt( -- 27
	Vec3(7, 5, 10), -- 27
	Vec3(0, 1, 0) -- 27
) -- 27
Director:pushCamera(camera) -- 28
view:setEnvironmentMap("") -- 29
view:setEnvironmentIntensity(0, 0, 1) -- 30
local light = DirectionalLight3D() -- 32
light.color = Color3(16777215) -- 33
light.intensity = 4 -- 34
light.angleX = -45 -- 35
light.angleY = 25 -- 36
view:addChild(light) -- 37
local world = PhysicsWorld3D() -- 39
world.gravity = Vec3(0, -9.81, 0) -- 40
view:addChild(world) -- 41
local floorNode = Node3D() -- 43
floorNode.position = Vec3(0, -0.5, 0) -- 44
view:addChild(floorNode) -- 45
makeBoxBody3D( -- 46
	world, -- 46
	floorNode, -- 46
	Vec3(7, 0.5, 4), -- 46
	PhysicsWorld3D.Static -- 46
) -- 46
local hullNode = Node3D() -- 48
hullNode.position = Vec3(0, 4, 0) -- 49
view:addChild(hullNode) -- 50
local duck = Model3D(modelPath) -- 51
hullNode:addChild(duck) -- 52
local phase = "Loading convex hull through Content" -- 54
local hullShape -- 55
local hullBody -- 56
local hullBuilt = false -- 57
local cacheHit = false -- 58
local cacheIsolated = false -- 59
local dynamicCreated = false -- 60
local rotated = false -- 61
local rayHit = false -- 62
local elapsed = 0 -- 63
local loadTime = 0 -- 64
local stableFrames = 0 -- 65
local completed = false -- 66
local captureDelay = -1 -- 67
local screenshot = "" -- 68
local loadStarted = App.runningTime -- 69
FixtureDef3D:loadConvexHullAsync( -- 71
	modelPath, -- 71
	function(shape) -- 71
		loadTime = App.runningTime - loadStarted -- 72
		hullShape = shape -- 73
		hullBuilt = shape.built -- 74
		if not hullBuilt then -- 74
			phase = "FAIL: hull cook" -- 76
			completed = true -- 77
			captureDelay = 0 -- 78
			return -- 79
		end -- 79
		FixtureDef3D:loadConvexHullAsync( -- 81
			modelPath, -- 81
			function(cached) -- 81
				cacheHit = cached == shape and cached.built -- 82
			end -- 81
		) -- 81
		FixtureDef3D:loadMeshAsync( -- 84
			modelPath, -- 84
			function(mesh) -- 84
				cacheIsolated = mesh ~= shape and mesh.built -- 85
			end -- 84
		) -- 84
		hullBody = makeBody3D(world, hullNode, shape, PhysicsWorld3D.Dynamic) -- 87
		dynamicCreated = hullBody ~= nil -- 88
		hullBody.angularVelocity = Vec3(0.4, 1.2, 0.25) -- 89
		phase = "Dynamic hull falling" -- 90
	end -- 71
) -- 71
print("CONVEX_HULL3D_READY") -- 93
threadLoop(function() -- 94
	elapsed = elapsed + App.deltaTime -- 95
	if hullBody then -- 95
		rotated = rotated or math.abs(hullBody.angles.y) > 5 or math.abs(hullBody.angles.x) > 5 -- 97
	end -- 97
	if not completed and hullBody ~= nil and elapsed > 1 and hullBody.position.y < 2 and math.abs(hullBody.linearVelocity.y) < 0.08 then -- 97
		stableFrames = stableFrames + 1 -- 106
		if stableFrames >= 20 then -- 106
			local position = hullBody.position -- 108
			world:raycast( -- 109
				Vec3(position.x, position.y + 5, position.z), -- 109
				Vec3(position.x, position.y - 5, position.z), -- 109
				function(body) -- 109
					rayHit = body == hullBody -- 110
					return true -- 111
				end -- 109
			) -- 109
			completed = true -- 113
			phase = hullBuilt and cacheHit and cacheIsolated and dynamicCreated and rotated and rayHit and "PASS" or "FAIL" -- 114
			screenshot = App:saveScreenshot(output .. "/convex-hull") -- 115
			captureDelay = 0 -- 116
		end -- 116
	elseif not dynamicCreated then -- 116
		stableFrames = 0 -- 119
	end -- 119
	if not completed and elapsed > 12 then -- 119
		completed = true -- 123
		phase = "FAIL: timeout" -- 124
		screenshot = App:saveScreenshot(output .. "/convex-hull") -- 125
		captureDelay = 0 -- 126
	end -- 126
	if captureDelay >= 0 then -- 126
		captureDelay = captureDelay + App.deltaTime -- 130
		if captureDelay >= 2 then -- 130
			captureDelay = -1 -- 132
			local ____temp_4 = phase == "PASS" and "PASS" or "FAIL" -- 133
			local ____hullBuilt_5 = hullBuilt -- 133
			local ____cacheHit_6 = cacheHit -- 133
			local ____cacheIsolated_7 = cacheIsolated -- 133
			local ____dynamicCreated_8 = dynamicCreated -- 133
			local ____rotated_9 = rotated -- 133
			local ____rayHit_10 = rayHit -- 133
			local ____opt_0 = hullBody -- 133
			local summary = (((((((((((((((((("CONVEX_HULL3D_SUMMARY status=" .. ____temp_4) .. " built=") .. tostring(____hullBuilt_5)) .. " cache=") .. tostring(____cacheHit_6)) .. " isolated=") .. tostring(____cacheIsolated_7)) .. " dynamic=") .. tostring(____dynamicCreated_8)) .. " rotated=") .. tostring(____rotated_9)) .. " ray=") .. tostring(____rayHit_10)) .. " y=") .. (____opt_0 and __TS__NumberToFixed(hullBody and hullBody.position.y, 3) or "nan")) .. " load=") .. __TS__NumberToFixed(loadTime, 3)) .. " screenshot=") .. screenshot -- 133
			Content:save(output .. "/result.txt", summary) -- 134
			print(summary) -- 135
		end -- 135
	end -- 135
	ImGui.SetNextWindowPos( -- 139
		Vec2(12, 12), -- 139
		"Always" -- 139
	) -- 139
	ImGui.SetNextWindowSize( -- 140
		Vec2(380, 0), -- 140
		"Always" -- 140
	) -- 140
	ImGui.SetNextWindowBgAlpha(0.78) -- 141
	ImGui.Begin( -- 142
		"JOLT-C Dynamic Convex Hull", -- 142
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 142
		function() -- 142
			ImGui.Text("Phase: " .. phase) -- 143
			ImGui.Text(("Content + cook: " .. __TS__NumberToFixed(loadTime, 3)) .. "s") -- 144
			ImGui.Text((("Hull built/cache: " .. tostring(hullBuilt)) .. "/") .. tostring(cacheHit)) -- 145
			ImGui.Text("Mesh cache isolated: " .. tostring(cacheIsolated)) -- 146
			ImGui.Text((((("Dynamic/rotated/ray: " .. tostring(dynamicCreated)) .. "/") .. tostring(rotated)) .. "/") .. tostring(rayHit)) -- 147
			local ____ImGui_Text_15 = ImGui.Text -- 148
			local ____opt_11 = hullBody -- 148
			____ImGui_Text_15("Body Y: " .. (____opt_11 and __TS__NumberToFixed(hullBody and hullBody.position.y, 2) or "n/a")) -- 148
		end -- 142
	) -- 142
	return false -- 150
end) -- 94
return ____exports -- 94