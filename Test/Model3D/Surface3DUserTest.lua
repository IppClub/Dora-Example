-- [ts]: Surface3DUserTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 3
local Camera3D = ____Dora.Camera3D -- 5
local ClipNode = ____Dora.ClipNode -- 6
local Color = ____Dora.Color -- 7
local Color3 = ____Dora.Color3 -- 8
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 9
local Director = ____Dora.Director -- 10
local DrawNode = ____Dora.DrawNode -- 11
local Model3D = ____Dora.Model3D -- 12
local Node = ____Dora.Node -- 13
local Size = ____Dora.Size -- 14
local Surface3D = ____Dora.Surface3D -- 15
local Vec2 = ____Dora.Vec2 -- 16
local Vec3 = ____Dora.Vec3 -- 17
local threadLoop = ____Dora.threadLoop -- 18
local ImGui = require("ImGui") -- 21
local view = Director.entry -- 23
local camera = Camera3D() -- 24
camera:lookAt( -- 25
	Vec3(0, 2.5, 7.5), -- 25
	Vec3(0, 1.1, 0) -- 25
) -- 25
Director:pushCamera(camera) -- 26
view:setEnvironmentMap("") -- 27
view:setEnvironmentIntensity(0.22, 0.05, 1) -- 28
local light = DirectionalLight3D() -- 30
light.color = Color3(16773852) -- 31
light.intensity = 4 -- 32
light.angleX = -38 -- 33
light.angleY = 30 -- 34
view:addChild(light) -- 35
local ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 37
ground.position = Vec3(0, -0.72, 0) -- 38
view:addChild(ground) -- 39
local rearDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 41
rearDuck.position = Vec3(0.45, 0, -0.8) -- 42
rearDuck.scale = Vec3(0.9, 0.9, 0.9) -- 43
rearDuck.angleY = -25 -- 44
rearDuck:getMaterial(0).baseColor = Color(4284012173) -- 45
view:addChild(rearDuck) -- 46
local frontDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 48
frontDuck.position = Vec3(-0.35, 0, 1) -- 49
frontDuck.scale = Vec3(0.9, 0.9, 0.9) -- 50
frontDuck.angleY = 25 -- 51
frontDuck:getMaterial(0).baseColor = Color(4294934352) -- 52
view:addChild(frontDuck) -- 53
local function makePanel() -- 55
	local panel = DrawNode() -- 56
	panel:drawPolygon( -- 57
		{ -- 57
			Vec2(0, 0), -- 58
			Vec2(128, 0), -- 59
			Vec2(128, 88), -- 60
			Vec2(0, 88) -- 61
		}, -- 61
		Color(4280577021), -- 62
		3, -- 62
		Color(4290633982) -- 62
	) -- 62
	panel:drawDot( -- 63
		Vec2(25, 44), -- 63
		15, -- 63
		Color(4294934352) -- 63
	) -- 63
	panel:drawDot( -- 64
		Vec2(64, 44), -- 64
		15, -- 64
		Color(4294950411) -- 64
	) -- 64
	panel:drawDot( -- 65
		Vec2(103, 44), -- 65
		15, -- 65
		Color(4284012173) -- 65
	) -- 65
	return panel -- 66
end -- 55
local content = Node() -- 69
content.size = Size(128, 88) -- 70
content:addChild(makePanel()) -- 71
local surface = Surface3D( -- 73
	content, -- 73
	Size(3.2, 2.2), -- 73
	Size(256, 176) -- 73
) -- 73
if not surface then -- 73
	error("Surface3D creation failed") -- 74
end -- 74
surface.position = Vec3(0, 1.15, 0) -- 75
view:addChild(surface) -- 76
local modes = {"Direct DrawNode", "Dynamic ClipNode", "Generic Node fallback", "Grabber fallback"} -- 78
local billboards = {"None", "Screen", "Y axis"} -- 79
local mode = 1 -- 80
local billboard = 1 -- 81
local activeNode -- 82
local targetMode = "direct" -- 83
local function clearMode() -- 85
	content:grab(false) -- 86
	if activeNode then -- 86
		content:removeChild(activeNode, true) -- 88
		activeNode = nil -- 89
	end -- 89
end -- 85
local function setMode(next) -- 93
	clearMode() -- 94
	mode = next -- 95
	if mode == 2 then -- 95
		local stencil = DrawNode() -- 97
		stencil:drawDot( -- 98
			Vec2(64, 44), -- 98
			34, -- 98
			Color(4294967295) -- 98
		) -- 98
		local clip = ClipNode(stencil) -- 99
		local fill = DrawNode() -- 100
		fill:drawPolygon( -- 101
			{ -- 101
				Vec2(12, 6), -- 102
				Vec2(116, 6), -- 103
				Vec2(116, 82), -- 104
				Vec2(12, 82) -- 105
			}, -- 105
			Color(3723381547) -- 106
		) -- 106
		clip:addChild(fill) -- 107
		content:addChild(clip) -- 108
		activeNode = clip -- 109
		targetMode = "texture (ClipNode depth/stencil isolation)" -- 110
	elseif mode == 3 then -- 110
		local group = Node() -- 112
		local mark = DrawNode() -- 113
		mark:drawDot( -- 114
			Vec2(64, 44), -- 114
			27, -- 114
			Color(3724488104) -- 114
		) -- 114
		group:addChild(mark) -- 115
		content:addChild(group) -- 116
		activeNode = group -- 117
		targetMode = "texture (conservative generic-node fallback)" -- 118
	elseif mode == 4 then -- 118
		content:grab(true) -- 120
		targetMode = "texture (grabber owns a render pass)" -- 121
	else -- 121
		targetMode = "direct (depth-preserving Surface3D view)" -- 123
	end -- 123
end -- 93
local function setBillboard(next) -- 127
	billboard = next -- 128
	surface.billboard = next == 2 and "Screen" or (next == 3 and "YAxis" or "None") -- 129
end -- 127
setMode(mode) -- 132
print("SURFACE_3D_USER_TEST_READY") -- 133
threadLoop(function() -- 134
	frontDuck.angleY = frontDuck.angleY + App.deltaTime * 25 -- 135
	rearDuck.angleY = rearDuck.angleY - App.deltaTime * 18 -- 136
	ImGui.SetNextWindowPos( -- 138
		Vec2(12, 12), -- 138
		"Always" -- 138
	) -- 138
	ImGui.SetNextWindowSize( -- 139
		Vec2(390, 0), -- 139
		"Always" -- 139
	) -- 139
	ImGui.SetNextWindowBgAlpha(0.88) -- 140
	ImGui.Begin( -- 141
		"Surface3D User Test", -- 141
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 141
		function() -- 141
			ImGui.Text("The orange duck is in front of the 2D surface.") -- 142
			ImGui.Text("The green duck is behind it.") -- 143
			ImGui.Text("Their overlap verifies shared 3D depth.") -- 144
			ImGui.Separator() -- 145
			local changed = false -- 147
			changed, mode = ImGui.Combo("2D subtree", mode, modes) -- 148
			if changed then -- 148
				setMode(mode) -- 149
			end -- 149
			changed, billboard = ImGui.Combo("Billboard", billboard, billboards) -- 150
			if changed then -- 150
				setBillboard(billboard) -- 151
			end -- 151
			if ImGui.Button( -- 151
				"Rotate -30 deg", -- 153
				Vec2(175, 30) -- 153
			) then -- 153
				surface.angleY = surface.angleY - 30 -- 153
			end -- 153
			ImGui.SameLine() -- 154
			if ImGui.Button( -- 154
				"Rotate +30 deg", -- 155
				Vec2(175, 30) -- 155
			) then -- 155
				surface.angleY = surface.angleY + 30 -- 155
			end -- 155
			if ImGui.Button( -- 155
				"Reset", -- 156
				Vec2(-1, 30) -- 156
			) then -- 156
				surface.angleY = 0 -- 157
				setBillboard(1) -- 158
				setMode(1) -- 159
			end -- 159
			ImGui.Separator() -- 162
			ImGui.Text("Expected: " .. targetMode) -- 163
			ImGui.Text("Actual backend: " .. (surface.usingTexture and "texture" or "direct")) -- 164
			ImGui.Text(("Surface yaw: " .. __TS__NumberToFixed(surface.angleY, 0)) .. " deg") -- 165
			ImGui.Text("Draw calls: " .. tostring(view.stats.drawCalls)) -- 166
			local backendMatches = surface.usingTexture == (mode ~= 1) -- 167
			ImGui.Text("Backend selection: " .. (backendMatches and "PASS" or "UPDATING")) -- 168
		end -- 141
	) -- 141
	return false -- 170
end) -- 134
return ____exports -- 134