-- @preview-file on clear
local Vec2 <const> = require("Vec2")
local PhysicsWorld <const> = require("PhysicsWorld")
local Label <const> = require("Label")
local BodyDef <const> = require("BodyDef")
local Body <const> = require("Body")
local Line <const> = require("Line")
local App <const> = require("App")
local threadLoop <const> = require("threadLoop")

local gravity <const> = Vec2(0, -10)

local world = PhysicsWorld()
world:setShouldContact(0, 0, true)
world.showDebug = true

local label = Label("sarasa-mono-sc-regular", 30)
if label is nil then
	return
end
label:addTo(world)

local terrainDef = BodyDef()
local count <const> = 50
local radius <const> = 300
local vertices = {}
local index = 1
for i = 1, count + 1 do
	local angle = 2 * math.pi * i / count
	vertices[index] = Vec2(radius * math.cos(angle), radius * math.sin(angle))
	index = index + 1
end
terrainDef:attachChain(vertices, 0.4, 0)
terrainDef:attachDiskSensor(99, Vec2(80, 80), 100)
local terrain = Body(terrainDef, world)
terrain:onBodyEnter(function(other: Body.Type, sensorTag: integer)
	if sensorTag == 99 then
		other.velocity = other.velocity * 0.5
	end
end)
terrain:addTo(world)

local platformDef = BodyDef()
platformDef:attachPolygon(Vec2(0, -80), 120, 30, 0, 1, 0, 1.0)

local platform = Body(platformDef, world)
platform:onContactFilter(function(body: Body.Type): boolean
	return body.velocityY < 0
end)
platform:addTo(world)

local drawNode = Line({
	Vec2(-20, 0),
	Vec2(20, 0),
	Vec2.zero,
	Vec2(0, -20),
	Vec2(0, 20)
}, App.themeColor)
drawNode:addTo(world)

local diskDef = BodyDef()
diskDef.type = "Dynamic"
diskDef.linearAcceleration = gravity
diskDef:attachDisk(20, 5, 0.8, 1)

local disk = Body(diskDef, world, Vec2(100, 200))
disk:addTo(world)
disk.angularRate = -1800
disk:onContactStart(function(_: Body.Type, point: Vec2.Type, _normal: Vec2.Type, enabled: boolean)
	if enabled then
		drawNode.position = point
		label.text = string.format("Contact: [%.0f,%.0f]", point.x, point.y)
	end
end)

-- example codes ends here, some test ui below --

local ImGui <const> = require("ImGui")

local windowFlags = {
	"NoDecoration",
	"AlwaysAutoResize",
	"NoSavedSettings",
	"NoFocusOnAppearing",
	"NoNav",
	"NoMove"
}
local receivingContact = disk.receivingContact
threadLoop(function(): boolean
	local width = App.visualSize.width
	ImGui.SetNextWindowBgAlpha(0.35)
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0))
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver")
	ImGui.Begin("Contact", windowFlags, function()
		ImGui.Text("Contact (Teal)")
		ImGui.Separator()
		ImGui.TextWrapped("Receive events when physics bodies contact.")
		local changed = false
		changed, receivingContact = ImGui.Checkbox("Receiving Contact", receivingContact)
		if changed then
			disk.receivingContact = receivingContact
			label.text = ""
		end
	end)
end)
