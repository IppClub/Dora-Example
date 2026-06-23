-- [ts]: BodyTS.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Body = ____Dora.Body -- 2
local BodyDef = ____Dora.BodyDef -- 2
local PhysicsWorld = ____Dora.PhysicsWorld -- 2
local Vec2 = ____Dora.Vec2 -- 2
local threadLoop = ____Dora.threadLoop -- 2
local ImGui = require("ImGui") -- 3
local gravity = Vec2(0, -10) -- 6
local groupZero = 0 -- 7
local groupOne = 1 -- 8
local groupTwo = 2 -- 9
local terrainDef = BodyDef() -- 11
terrainDef.type = "Static" -- 12
terrainDef:attachPolygon( -- 13
	800, -- 13
	10, -- 13
	1, -- 13
	0.8, -- 13
	0.2 -- 13
) -- 13
local polygonDef = BodyDef() -- 15
polygonDef.type = "Dynamic" -- 16
polygonDef.linearAcceleration = gravity -- 17
polygonDef:attachPolygon( -- 18
	{ -- 18
		Vec2(60, 0), -- 19
		Vec2(30, -30), -- 20
		Vec2(-30, -30), -- 21
		Vec2(-60, 0), -- 22
		Vec2(-30, 30), -- 23
		Vec2(30, 30) -- 24
	}, -- 24
	1, -- 25
	0.4, -- 25
	0.4 -- 25
) -- 25
local diskDef = BodyDef() -- 27
diskDef.type = "Dynamic" -- 28
diskDef.linearAcceleration = gravity -- 29
diskDef:attachDisk(60, 1, 0.4, 0.4) -- 30
local world = PhysicsWorld() -- 32
world.y = -200 -- 33
world:setShouldContact(groupZero, groupOne, false) -- 34
world:setShouldContact(groupZero, groupTwo, true) -- 35
world:setShouldContact(groupOne, groupTwo, true) -- 36
world.showDebug = true -- 37
local body = Body(terrainDef, world, Vec2.zero) -- 39
body.group = groupTwo -- 40
world:addChild(body) -- 41
local bodyP = Body( -- 43
	polygonDef, -- 43
	world, -- 43
	Vec2(0, 500), -- 43
	15 -- 43
) -- 43
bodyP.group = groupOne -- 44
world:addChild(bodyP) -- 45
local bodyD = Body( -- 47
	diskDef, -- 47
	world, -- 47
	Vec2(50, 800) -- 47
) -- 47
bodyD.group = groupZero -- 48
bodyD.angularRate = 90 -- 49
world:addChild(bodyD) -- 50
local windowFlags = { -- 52
	"NoDecoration", -- 53
	"AlwaysAutoResize", -- 54
	"NoSavedSettings", -- 55
	"NoFocusOnAppearing", -- 56
	"NoMove" -- 57
} -- 57
threadLoop(function() -- 59
	local ____App_visualSize_0 = App.visualSize -- 60
	local width = ____App_visualSize_0.width -- 60
	ImGui.SetNextWindowBgAlpha(0.35) -- 61
	ImGui.SetNextWindowPos( -- 62
		Vec2(width - 10, 10), -- 62
		"Always", -- 62
		Vec2(1, 0) -- 62
	) -- 62
	ImGui.SetNextWindowSize( -- 63
		Vec2(240, 0), -- 63
		"FirstUseEver" -- 63
	) -- 63
	ImGui.Begin( -- 64
		"Body", -- 64
		windowFlags, -- 64
		function() -- 64
			ImGui.Text("Body (TypeScript)") -- 65
			ImGui.Separator() -- 66
			ImGui.TextWrapped("Basic usage to create physics bodies!") -- 67
		end -- 64
	) -- 64
	return false -- 69
end) -- 59
return ____exports -- 59