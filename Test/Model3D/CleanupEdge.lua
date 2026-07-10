-- [ts]: CleanupEdge.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Node3D = ____Dora.Node3D -- 2
local Vec3 = ____Dora.Vec3 -- 2
local View3D = ____Dora.View3D -- 2
local threadLoop = ____Dora.threadLoop -- 2
local cases = {{name = "Specular", file = "Test/Model3D/Assets/Model/SpecularTest.glb", scale = 1}, {name = "Helmet", file = "Test/Model3D/Assets/Model/DamagedHelmet.glb", scale = 1.8}, {name = "Fox", file = "Test/Model3D/Assets/Model/Fox.glb", scale = 0.015, animation = "Run"}} -- 11
local view = View3D() -- 17
Director.entry:addChild(view) -- 18
local camera = Camera3D() -- 20
camera:lookAt( -- 21
	Vec3(0, 0.45, 4), -- 21
	Vec3(0, 0.15, 0) -- 21
) -- 21
Director:pushCamera(camera) -- 22
view:setEnvironmentMap("Test/Model3D/Assets/Env/studio.png") -- 24
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 25
local model -- 27
local oldModel -- 28
local index = 0 -- 29
local elapsed = 0 -- 30
local switches = 0 -- 31
local function verifyCleanupMisuse() -- 33
	local probe = Node3D() -- 34
	view.scene:addChild(probe) -- 35
	local ok = pcall(function() -- 36
		probe:cleanup() -- 37
	end) -- 36
	assert(not ok, "Node3D.cleanup() with a parent should fail") -- 39
	print("cleanup_edge parent_cleanup_error=true") -- 40
	probe:removeFromParent(true) -- 41
end -- 33
local function loadNext() -- 44
	if oldModel then -- 44
		oldModel:cleanup() -- 46
		oldModel = nil -- 47
	end -- 47
	if model then -- 47
		model:removeFromParent(true) -- 50
		oldModel = model -- 51
		model = nil -- 52
	end -- 52
	local item = cases[index + 1] -- 55
	index = (index + 1) % #cases -- 56
	local start = App.runningTime -- 57
	model = Model3D(item.file) -- 58
	assert(model ~= nil, "failed to load " .. item.file) -- 59
	view.scene:addChild(model) -- 60
	model.scaleX = item.scale -- 61
	model.scaleY = item.scale -- 62
	model.scaleZ = item.scale -- 63
	if item.animation then -- 63
		model:play(item.animation, true) -- 65
	end -- 65
	switches = switches + 1 -- 67
	print((((("cleanup_edge switch=" .. tostring(switches)) .. " case=") .. item.name) .. " load=") .. __TS__NumberToFixed(App.runningTime - start, 3)) -- 68
end -- 44
verifyCleanupMisuse() -- 71
loadNext() -- 72
threadLoop(function() -- 74
	elapsed = elapsed + App.deltaTime -- 75
	if model then -- 75
		model.angleY = model.angleY + App.deltaTime * 30 -- 77
	end -- 77
	if elapsed > 0.6 then -- 77
		elapsed = 0 -- 80
		loadNext() -- 81
	end -- 81
	return false -- 83
end) -- 74
return ____exports -- 74