-- @preview-file on clear
local Vec2 <const> = require("Vec2")
local BodyDef <const> = require("BodyDef")
local Body <const> = require("Body")
local PhysicsWorld <const> = require("PhysicsWorld")
local threadLoop <const> = require("threadLoop")

local gravity <const> = Vec2(0, -10)
local groupZero <const> = 0
local groupOne <const> = 1
local groupTwo <const> = 2

local terrainDef = BodyDef()
terrainDef.type = "Static"
terrainDef:attachPolygon(800, 10, 1, 0.8, 0.2)

local polygonDef = BodyDef()
polygonDef.type = "Dynamic"
polygonDef.linearAcceleration = gravity
polygonDef:attachPolygon({
	Vec2(60, 0),
	Vec2(30, -30),
	Vec2(-30, -30),
	Vec2(-60, 0),
	Vec2(-30, 30),
	Vec2(30, 30)
}, 1, 0.4, 0.4)

local diskDef = BodyDef()
diskDef.type = "Dynamic"
diskDef.linearAcceleration = gravity
diskDef:attachDisk(60, 1, 0.4, 0.4)

local world = PhysicsWorld()
world.y = -200
world:setShouldContact(groupZero, groupOne, false)
world:setShouldContact(groupZero, groupTwo, true)
world:setShouldContact(groupOne, groupTwo, true)
world.showDebug = true

local body = Body(terrainDef, world, Vec2.zero)
body.group = groupTwo
world:addChild(body)

body = Body(polygonDef, world, Vec2(0, 500), 15)
body.group = groupOne
world:addChild(body)

body = Body(diskDef, world, Vec2(50, 800))
body.group = groupZero
body.angularRate = 90
world:addChild(body)

-- example codes ends here, some test ui below --

local ImGui <const> = require("ImGui")
local App <const> = require("App")

local windowFlags = {
	"NoDecoration",
	"AlwaysAutoResize",
	"NoSavedSettings",
	"NoFocusOnAppearing",
	"NoNav",
	"NoMove"
}
threadLoop(function(): boolean
	local width = App.visualSize.width
	ImGui.SetNextWindowBgAlpha(0.35)
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0))
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver")
	ImGui.Begin("Body", windowFlags, function()
		ImGui.Text("Body (Teal)")
		ImGui.Separator()
		ImGui.TextWrapped("Basic usage to create physics bodies!")
	end)
end)
