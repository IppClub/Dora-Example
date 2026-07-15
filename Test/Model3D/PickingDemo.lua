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
local view = Director.entry -- 20
local models = {} -- 21
local selected -- 22
local selectedName = "None" -- 23
local loading = false -- 24
local lastPoint = Vec2.zero -- 25
local showAABB = true -- 26
local camera = Camera3D() -- 28
camera:lookAt( -- 29
	Vec3(0, 1.1, 8), -- 29
	Vec3(0, 0.8, 0) -- 29
) -- 29
Director:pushCamera(camera) -- 30
view:setEnvironmentMap("") -- 32
view:setEnvironmentIntensity(0, 0, 1) -- 33
view.showAABB = showAABB -- 34
local light = DirectionalLight3D() -- 36
light.color = Color3(16777215) -- 37
light.intensity = 3.5 -- 38
light.angleX = -30 -- 39
light.angleY = 35 -- 40
view:addChild(light) -- 41
local function select(model) -- 43
	if selected then -- 43
		selected.scale = Vec3(0.8, 0.8, 0.8) -- 44
	end -- 44
	selected = model -- 45
	selectedName = model and model.tag or "None" -- 46
	if selected then -- 46
		selected.scale = Vec3(1, 1, 1) -- 47
	end -- 47
end -- 43
view:onTapped(function(touch) -- 50
	lastPoint = touch.viewLocation -- 51
	select(view:pick(touch.viewLocation)) -- 52
end) -- 50
local placements = { -- 55
	{ -- 56
		name = "Left", -- 56
		position = Vec3(-2.2, 0, 0), -- 56
		angle = 25 -- 56
	}, -- 56
	{ -- 57
		name = "Center", -- 57
		position = Vec3(0, 0, 0), -- 57
		angle = 0 -- 57
	}, -- 57
	{ -- 58
		name = "Right", -- 58
		position = Vec3(2.2, 0, 0), -- 58
		angle = -25 -- 58
	} -- 58
} -- 58
for ____, item in ipairs(placements) do -- 60
	local model = Model3D(modelFile) -- 61
	model.tag = item.name -- 62
	model.position = item.position -- 63
	model.angleY = item.angle -- 64
	model.scale = Vec3(0.8, 0.8, 0.8) -- 65
	view:addChild(model) -- 66
	models[#models + 1] = model -- 67
end -- 67
print((("PICKING_DEMO_READY models=" .. tostring(#models)) .. " showAABB=") .. tostring(showAABB)) -- 69
thread(function() -- 70
	do -- 70
		local i = 0 -- 71
		while i < 30 do -- 71
			sleep() -- 71
			i = i + 1 -- 71
		end -- 71
	end -- 71
	local stats = view.stats -- 72
	print((("PICKING_DEMO_RENDER visible=" .. tostring(stats.visibleVisuals)) .. " draws=") .. tostring(stats.drawCalls)) -- 73
end) -- 70
threadLoop(function() -- 76
	if selected then -- 76
		selected.angleY = selected.angleY + App.deltaTime * 45 -- 77
	end -- 77
	ImGui.SetNextWindowPos( -- 79
		Vec2(View.size.width - 12, 12), -- 79
		"FirstUseEver", -- 79
		Vec2(1, 0) -- 79
	) -- 79
	ImGui.SetNextWindowSize( -- 80
		Vec2(300, 0), -- 80
		"FirstUseEver" -- 80
	) -- 80
	ImGui.SetNextWindowBgAlpha(0.7) -- 81
	ImGui.Begin( -- 82
		"Model3D Picking", -- 82
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 82
		function() -- 82
			ImGui.Text("State: " .. (loading and "Loading" or "Ready")) -- 83
			ImGui.Text("Selected: " .. selectedName) -- 84
			ImGui.Text((("View Point: " .. __TS__NumberToFixed(lastPoint.x, 1)) .. ", ") .. __TS__NumberToFixed(lastPoint.y, 1)) -- 85
			ImGui.Text("Models: " .. tostring(#models)) -- 86
			local changed = false -- 87
			changed, showAABB = ImGui.Checkbox("Show AABB", showAABB) -- 88
			if changed then -- 88
				view.showAABB = showAABB -- 89
			end -- 89
			if ImGui.Button( -- 89
				"Clear Selection", -- 90
				Vec2(-1, 30) -- 90
			) then -- 90
				select(nil) -- 90
			end -- 90
		end -- 82
	) -- 82
	return false -- 93
end) -- 76
return ____exports -- 76