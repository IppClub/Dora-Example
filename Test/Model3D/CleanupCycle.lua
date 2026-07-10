-- [ts]: CleanupCycle.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Vec3 = ____Dora.Vec3 -- 2
local View3D = ____Dora.View3D -- 2
local threadLoop = ____Dora.threadLoop -- 2
local cases = {{name = "Specular", file = "Test/Model3D/Assets/Model/SpecularTest.glb", scale = 1}, {name = "Clearcoat", file = "Test/Model3D/Assets/Model/ClearCoatTest.glb", scale = 1}, {name = "Helmet", file = "Test/Model3D/Assets/Model/DamagedHelmet.glb", scale = 1.8}, {name = "Fox", file = "Test/Model3D/Assets/Model/Fox.glb", scale = 0.015, animation = "Run"}} -- 11
local view = View3D() -- 18
Director.entry:addChild(view) -- 19
local camera = Camera3D() -- 21
camera:lookAt( -- 22
	Vec3(0, 0.45, 4), -- 22
	Vec3(0, 0.15, 0) -- 22
) -- 22
Director:pushCamera(camera) -- 23
view:setEnvironmentMap("Test/Model3D/Assets/Env/warm.png") -- 25
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 26
local model -- 28
local index = 0 -- 29
local elapsed = 0 -- 30
local switches = 0 -- 31
local function loadNext() -- 33
	if model then -- 33
		model:removeFromParent(true) -- 35
		model = nil -- 36
	end -- 36
	index = index % #cases -- 38
	local item = cases[index + 1] -- 39
	index = index + 1 -- 40
	local start = App.runningTime -- 42
	model = Model3D(item.file) -- 43
	assert(model ~= nil, "failed to load " .. item.file) -- 44
	view.scene:addChild(model) -- 45
	model.scaleX = item.scale -- 46
	model.scaleY = item.scale -- 47
	model.scaleZ = item.scale -- 48
	if item.animation then -- 48
		model:play(item.animation, true) -- 50
	end -- 50
	switches = switches + 1 -- 52
	print((((("cleanup_cycle switch=" .. tostring(switches)) .. " case=") .. item.name) .. " load=") .. __TS__NumberToFixed(App.runningTime - start, 3)) -- 53
end -- 33
loadNext() -- 56
threadLoop(function() -- 58
	elapsed = elapsed + App.deltaTime -- 59
	if model then -- 59
		model.angleY = model.angleY + App.deltaTime * 30 -- 61
	end -- 61
	if elapsed > 0.8 then -- 61
		elapsed = 0 -- 64
		loadNext() -- 65
	end -- 65
	return false -- 67
end) -- 58
return ____exports -- 58