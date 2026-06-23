-- [ts]: ContactTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Body = ____Dora.Body -- 4
local BodyDef = ____Dora.BodyDef -- 4
local Label = ____Dora.Label -- 4
local Line = ____Dora.Line -- 4
local PhysicsWorld = ____Dora.PhysicsWorld -- 4
local Vec2 = ____Dora.Vec2 -- 4
local threadLoop = ____Dora.threadLoop -- 4
local gravity = Vec2(0, -10) -- 6
local world = PhysicsWorld() -- 8
world:setShouldContact(0, 0, true) -- 9
world.showDebug = true -- 10
local ____opt_0 = Label("sarasa-mono-sc-regular", 30) -- 10
local label = ____opt_0 and ____opt_0:addTo(world) -- 12
local terrainDef = BodyDef() -- 14
local count = 50 -- 15
local radius = 300 -- 16
local vertices = {} -- 17
for i = 0, count + 1 do -- 17
	local angle = 2 * math.pi * i / count -- 19
	vertices[#vertices + 1] = Vec2( -- 20
		radius * math.cos(angle), -- 20
		radius * math.sin(angle) -- 20
	) -- 20
end -- 20
terrainDef:attachChain(vertices, 0.4, 0) -- 22
terrainDef:attachDisk( -- 23
	Vec2(0, -270), -- 23
	30, -- 23
	1, -- 23
	0, -- 23
	1 -- 23
) -- 23
terrainDef:attachPolygon( -- 24
	Vec2(0, 80), -- 24
	120, -- 24
	30, -- 24
	0, -- 24
	1, -- 24
	0, -- 24
	1 -- 24
) -- 24
local terrain = Body(terrainDef, world) -- 26
terrain:addTo(world) -- 27
local drawNode = Line( -- 29
	{ -- 29
		Vec2(-20, 0), -- 30
		Vec2(20, 0), -- 31
		Vec2.zero, -- 32
		Vec2(0, -20), -- 33
		Vec2(0, 20) -- 34
	}, -- 34
	App.themeColor -- 35
) -- 35
drawNode:addTo(world) -- 36
local diskDef = BodyDef() -- 38
diskDef.type = "Dynamic" -- 39
diskDef.linearAcceleration = gravity -- 40
diskDef:attachDisk(20, 5, 0.8, 1) -- 41
local disk = Body( -- 43
	diskDef, -- 43
	world, -- 43
	Vec2(100, 200) -- 43
) -- 43
disk:addTo(world) -- 44
disk.angularRate = -1800 -- 45
disk:onContactStart(function(_, point) -- 46
	drawNode.position = point -- 47
	if label ~= nil then -- 47
		label.text = string.format("Contact: [%.0f,%.0f]", point.x, point.y) -- 49
	end -- 49
end) -- 46
local windowFlags = { -- 52
	"NoDecoration", -- 53
	"AlwaysAutoResize", -- 54
	"NoSavedSettings", -- 55
	"NoFocusOnAppearing", -- 56
	"NoMove" -- 57
} -- 57
local receivingContact = disk.receivingContact -- 59
threadLoop(function() -- 60
	local ____App_visualSize_2 = App.visualSize -- 61
	local width = ____App_visualSize_2.width -- 61
	ImGui.SetNextWindowBgAlpha(0.35) -- 62
	ImGui.SetNextWindowPos( -- 63
		Vec2(width - 10, 10), -- 63
		"Always", -- 63
		Vec2(1, 0) -- 63
	) -- 63
	ImGui.SetNextWindowSize( -- 64
		Vec2(240, 0), -- 64
		"FirstUseEver" -- 64
	) -- 64
	ImGui.Begin( -- 65
		"Contact", -- 65
		windowFlags, -- 65
		function() -- 65
			ImGui.Text("Contact (TypeScript)") -- 66
			ImGui.Separator() -- 67
			ImGui.TextWrapped("Receive events when physics bodies contact.") -- 68
			local changed = false -- 69
			changed, receivingContact = ImGui.Checkbox("Receiving Contact", receivingContact) -- 70
			if changed then -- 70
				disk.receivingContact = receivingContact -- 72
				if label ~= nil then -- 72
					label.text = "" -- 73
				end -- 73
			end -- 73
		end -- 65
	) -- 65
	return false -- 76
end) -- 60
return ____exports -- 60