-- [ts]: PickingRegression.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Cache = ____Dora.Cache -- 4
local Camera3D = ____Dora.Camera3D -- 5
local Color3 = ____Dora.Color3 -- 6
local Content = ____Dora.Content -- 7
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Director = ____Dora.Director -- 9
local Model3D = ____Dora.Model3D -- 10
local Node = ____Dora.Node -- 11
local Vec2 = ____Dora.Vec2 -- 12
local Vec3 = ____Dora.Vec3 -- 13
local View = ____Dora.View -- 14
local sleep = ____Dora.sleep -- 15
local thread = ____Dora.thread -- 16
local modelFile = "Test/Model3D/Assets/Model/DamagedHelmet.glb" -- 19
local outputDir = "/tmp/dora-3d-picking" -- 20
local resultPath = outputDir .. "/result.txt" -- 21
local results = {} -- 22
local view = Director.entry -- 23
local function emit(message) -- 25
	print(message) -- 26
	results[#results + 1] = message -- 27
end -- 25
local function finish(status, reason) -- 30
	if reason == nil then -- 30
		reason = "" -- 30
	end -- 30
	emit(("PICKING_SUMMARY status=" .. status) .. (reason ~= "" and " reason=" .. reason or "")) -- 31
	Content:save( -- 32
		resultPath, -- 32
		table.concat(results, "\n") .. "\n" -- 32
	) -- 32
	App.devMode = false -- 33
	App:shutdown() -- 34
end -- 30
local function pointOnRay(origin, direction, distance) -- 37
	return Vec3(origin.x + direction.x * distance, origin.y + direction.y * distance, origin.z + direction.z * distance) -- 38
end -- 37
Content:remove(resultPath) -- 45
Cache:unload(modelFile) -- 46
if not Cache:load(modelFile) then -- 46
	finish("FAIL", "model_load_failed") -- 48
else -- 48
	local camera = Camera3D() -- 50
	Director:pushCamera(camera) -- 51
	camera:lookAt( -- 52
		Vec3(0, 0, 8), -- 52
		Vec3(0, 0, 0) -- 52
	) -- 52
	view:setEnvironmentMap("") -- 53
	view:setEnvironmentIntensity(0, 0, 1) -- 54
	local light = DirectionalLight3D() -- 56
	light.color = Color3(16777215) -- 57
	light.intensity = 3 -- 58
	light.angleX = -25 -- 59
	light.angleY = 30 -- 60
	view:addChild(light) -- 61
	local input = Node() -- 63
	input.size = View.size -- 64
	input:onTapped(function(touch) -- 65
		local hit = view:pick(touch.viewLocation) -- 66
		if hit then -- 66
			hit.scale = Vec3(1.8, 1.8, 1.8) -- 68
			emit((("PICKING_TOUCH hit=true x=" .. __TS__NumberToFixed(touch.viewLocation.x, 1)) .. " y=") .. __TS__NumberToFixed(touch.viewLocation.y, 1)) -- 69
		else -- 69
			emit((("PICKING_TOUCH hit=false x=" .. __TS__NumberToFixed(touch.viewLocation.x, 1)) .. " y=") .. __TS__NumberToFixed(touch.viewLocation.y, 1)) -- 71
		end -- 71
	end) -- 65
	view:addChild(input) -- 74
	thread(function() -- 76
		do -- 76
			local i = 0 -- 77
			while i < 3 do -- 77
				sleep() -- 77
				i = i + 1 -- 77
			end -- 77
		end -- 77
		local point = Vec2(View.size.width * 0.5, View.size.height * 0.5) -- 79
		local origin = view:getRayOrigin(point) -- 80
		local direction = view:getRayDirection(point) -- 81
		local length = math.sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z) -- 82
		emit((((((("PICKING_RAY origin=" .. __TS__NumberToFixed(origin.x, 3)) .. ",") .. __TS__NumberToFixed(origin.y, 3)) .. ",") .. __TS__NumberToFixed(origin.z, 3)) .. " ") .. (((((("direction=" .. __TS__NumberToFixed(direction.x, 3)) .. ",") .. __TS__NumberToFixed(direction.y, 3)) .. ",") .. __TS__NumberToFixed(direction.z, 3)) .. " length=") .. __TS__NumberToFixed(length, 4)) -- 85
		if math.abs(length - 1) > 0.001 then -- 85
			finish("FAIL", "ray_not_normalized") -- 90
			return -- 91
		end -- 91
		if math.abs(direction.x) > 0.001 or math.abs(direction.y) > 0.001 or direction.z > -0.999 then -- 91
			finish("FAIL", "center_ray_not_camera_forward") -- 94
			return -- 95
		end -- 95
		local nearModel = Model3D(modelFile) -- 98
		local farModel = Model3D(modelFile) -- 99
		if not nearModel or not farModel then -- 99
			finish("FAIL", "model_instance_failed") -- 101
			return -- 102
		end -- 102
		nearModel.position = pointOnRay(origin, direction, 3) -- 104
		farModel.position = pointOnRay(origin, direction, 5) -- 105
		nearModel.tag = "near" -- 106
		farModel.tag = "far" -- 107
		nearModel.scale = Vec3(1.5, 1.5, 1.5) -- 108
		farModel.scale = Vec3(1.5, 1.5, 1.5) -- 109
		view:addChild(farModel) -- 110
		view:addChild(nearModel) -- 111
		do -- 111
			local i = 0 -- 112
			while i < 3 do -- 112
				sleep() -- 112
				i = i + 1 -- 112
			end -- 112
		end -- 112
		local nearestHit = view:pick(point) -- 114
		emit("PICKING_NEAREST_HIT tag=" .. (nearestHit and nearestHit.tag or "none")) -- 115
		if (nearestHit and nearestHit.tag) ~= "near" then -- 115
			finish("FAIL", "nearest_model_not_selected_" .. (nearestHit and nearestHit.tag or "none")) -- 117
			return -- 118
		end -- 118
		emit("PICKING_NEAREST status=PASS") -- 120
		nearModel.visible = false -- 122
		sleep() -- 123
		local ____opt_6 = view:pick(point) -- 123
		if (____opt_6 and ____opt_6.tag) ~= "far" then -- 123
			finish("FAIL", "hidden_model_not_skipped") -- 125
			return -- 126
		end -- 126
		emit("PICKING_VISIBILITY status=PASS") -- 128
		farModel.visible = false -- 130
		sleep() -- 131
		if view:pick(point) ~= nil then -- 131
			finish("FAIL", "miss_expected") -- 133
			return -- 134
		end -- 134
		emit("PICKING_MISS status=PASS") -- 136
		finish("PASS") -- 137
	end) -- 76
end -- 76
return ____exports -- 76