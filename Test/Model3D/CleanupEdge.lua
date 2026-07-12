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
local cases = {{name = "Specular", file = "Test/Model3D/Assets/Model/SpecularTest.glb", scale = 1}, {name = "Helmet", file = "Test/Model3D/Assets/Model/DamagedHelmet.glb", scale = 1.8}, {name = "Fox", file = "Test/Model3D/Assets/Model/Fox.glb", scale = 0.015, animation = "Run"}} -- 15
local view = View3D() -- 21
Director.entry:addChild(view) -- 22
local camera = Camera3D() -- 24
camera:lookAt( -- 25
	Vec3(0, 0.45, 4), -- 25
	Vec3(0, 0.15, 0) -- 25
) -- 25
Director:pushCamera(camera) -- 26
view:setEnvironmentMap("Test/Model3D/Assets/Env/studio.png") -- 28
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 29
local model -- 31
local oldModel -- 32
local index = 0 -- 33
local elapsed = 0 -- 34
local switches = 0 -- 35
local function verifyCleanupWithParent() -- 37
	local probe = Node3D() -- 38
	view.scene:addChild(probe) -- 39
	probe:cleanup() -- 40
	assert(probe.parent == nil, "Node3D.cleanup() should clear its parent") -- 41
	local hierarchy = view.scene -- 42
	assert(not hierarchy.hasChildren, "Node3D.cleanup() should remove the parent child reference") -- 43
	view.scene:removeAllChildren(false) -- 44
	print("cleanup_edge parent_cleanup_success=true") -- 45
end -- 37
local function loadNext() -- 48
	if oldModel then -- 48
		oldModel:cleanup() -- 50
		oldModel = nil -- 51
	end -- 51
	if model then -- 51
		model:removeFromParent(true) -- 54
		oldModel = model -- 55
		model = nil -- 56
	end -- 56
	local item = cases[index + 1] -- 59
	index = (index + 1) % #cases -- 60
	local start = App.runningTime -- 61
	model = Model3D(item.file) -- 62
	assert(model ~= nil, "failed to load " .. item.file) -- 63
	view.scene:addChild(model) -- 64
	model.scaleX = item.scale -- 65
	model.scaleY = item.scale -- 66
	model.scaleZ = item.scale -- 67
	if item.animation then -- 67
		model:play(item.animation, true) -- 69
	end -- 69
	switches = switches + 1 -- 71
	print((((("cleanup_edge switch=" .. tostring(switches)) .. " case=") .. item.name) .. " load=") .. __TS__NumberToFixed(App.runningTime - start, 3)) -- 72
end -- 48
verifyCleanupWithParent() -- 75
loadNext() -- 76
threadLoop(function() -- 78
	elapsed = elapsed + App.deltaTime -- 79
	if model then -- 79
		model.angleY = model.angleY + App.deltaTime * 30 -- 81
	end -- 81
	if elapsed > 0.6 then -- 81
		elapsed = 0 -- 84
		loadNext() -- 85
	end -- 85
	return false -- 87
end) -- 78
return ____exports -- 78