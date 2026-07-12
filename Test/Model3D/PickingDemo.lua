-- [ts]: PickingDemo.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 4
local Color3 = ____Dora.Color3 -- 5
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 6
local Director = ____Dora.Director -- 7
local Model3D = ____Dora.Model3D -- 8
local Vec2 = ____Dora.Vec2 -- 9
local Vec3 = ____Dora.Vec3 -- 10
local View = ____Dora.View -- 11
local sleep = ____Dora.sleep -- 12
local thread = ____Dora.thread -- 13
local threadLoop = ____Dora.threadLoop -- 14
local ImGui = require("ImGui") -- 17
local modelFile = "Test/Model3D/Assets/Model/Duck.glb" -- 19
local view = Director.entry -- 21
local models = {} -- 23
local selected -- 24
local selectedName = "None" -- 25
local loading = false -- 26
local lastPoint = Vec2.zero -- 27
local showAABB = true -- 28
local camera = Camera3D() -- 30
camera:lookAt( -- 31
	Vec3(0, 1.1, 8), -- 31
	Vec3(0, 0.8, 0) -- 31
) -- 31
Director:pushCamera(camera) -- 32
view:setEnvironmentMap("") -- 34
view:setEnvironmentIntensity(0, 0, 1) -- 35
view.showAABB = showAABB -- 36
local light = DirectionalLight3D() -- 38
light.color = Color3(16777215) -- 39
light.intensity = 3.5 -- 40
light.angleX = -30 -- 41
light.angleY = 35 -- 42
view:addChild(light) -- 43
local function select(model) -- 45
	if selected then -- 45
		selected.scale = Vec3(0.8, 0.8, 0.8) -- 46
	end -- 46
	selected = model -- 47
	selectedName = model and model.tag or "None" -- 48
	if selected then -- 48
		selected.scale = Vec3(1, 1, 1) -- 49
	end -- 49
end -- 45
view:onTapped(function(touch) -- 52
	lastPoint = touch.viewLocation -- 53
	select(view:pick(touch.viewLocation)) -- 54
end) -- 52
local placements = { -- 57
	{ -- 58
		name = "Left", -- 58
		position = Vec3(-2.2, 0, 0), -- 58
		angle = 25 -- 58
	}, -- 58
	{ -- 59
		name = "Center", -- 59
		position = Vec3(0, 0, 0), -- 59
		angle = 0 -- 59
	}, -- 59
	{ -- 60
		name = "Right", -- 60
		position = Vec3(2.2, 0, 0), -- 60
		angle = -25 -- 60
	} -- 60
} -- 60
for ____, item in ipairs(placements) do -- 62
	local model = Model3D(modelFile) -- 63
	model.tag = item.name -- 64
	model.position = item.position -- 65
	model.angleY = item.angle -- 66
	model.scale = Vec3(0.8, 0.8, 0.8) -- 67
	view:addChild(model) -- 68
	models[#models + 1] = model -- 69
end -- 69
print((("PICKING_DEMO_READY models=" .. tostring(#models)) .. " showAABB=") .. tostring(showAABB)) -- 71
thread(function() -- 72
	do -- 72
		local i = 0 -- 73
		while i < 30 do -- 73
			sleep() -- 73
			i = i + 1 -- 73
		end -- 73
	end -- 73
	local stats = view.stats -- 74
	print((("PICKING_DEMO_RENDER visible=" .. tostring(stats.visibleVisuals)) .. " draws=") .. tostring(stats.drawCalls)) -- 75
end) -- 72
threadLoop(function() -- 78
	if selected then -- 78
		selected.angleY = selected.angleY + App.deltaTime * 45 -- 79
	end -- 79
	ImGui.SetNextWindowPos( -- 81
		Vec2(View.size.width - 12, 12), -- 81
		"FirstUseEver", -- 81
		Vec2(1, 0) -- 81
	) -- 81
	ImGui.SetNextWindowSize( -- 82
		Vec2(300, 0), -- 82
		"FirstUseEver" -- 82
	) -- 82
	ImGui.SetNextWindowBgAlpha(0.7) -- 83
	ImGui.Begin( -- 84
		"Model3D Picking", -- 84
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 84
		function() -- 84
			ImGui.Text("State: " .. (loading and "Loading" or "Ready")) -- 85
			ImGui.Text("Selected: " .. selectedName) -- 86
			ImGui.Text((("View Point: " .. __TS__NumberToFixed(lastPoint.x, 1)) .. ", ") .. __TS__NumberToFixed(lastPoint.y, 1)) -- 87
			ImGui.Text("Models: " .. tostring(#models)) -- 88
			local changed = false -- 89
			changed, showAABB = ImGui.Checkbox("Show AABB", showAABB) -- 90
			if changed then -- 90
				view.showAABB = showAABB -- 91
			end -- 91
			if ImGui.Button( -- 91
				"Clear Selection", -- 92
				Vec2(-1, 30) -- 92
			) then -- 92
				select(nil) -- 92
			end -- 92
		end -- 84
	) -- 84
	return false -- 95
end) -- 78
return ____exports -- 78
