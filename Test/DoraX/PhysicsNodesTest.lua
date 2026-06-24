-- [tsx]: PhysicsNodesTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local Vec2 = ____Dora.Vec2 -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXPhysicsNodesTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXPhysicsNodesTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local worldRef = useRef() -- 20
local bodyRef = useRef() -- 21
local movingRef = useRef() -- 22
local contactFilterCalls = 0 -- 23
root:render(React.createElement( -- 25
	"physics-world", -- 25
	{ref = worldRef, showDebug = true}, -- 25
	React.createElement("contact", {groupA = 1, groupB = 2, enabled = true}), -- 25
	React.createElement( -- 25
		"body", -- 25
		{key = "terrain", ref = bodyRef, type = "Static", group = 1}, -- 25
		React.createElement("rect-fixture", {width = 160, height = 12, friction = 0.8, restitution = 0.1}), -- 25
		React.createElement( -- 25
			"chain-fixture", -- 25
			{ -- 25
				verts = { -- 25
					Vec2(-80, 20), -- 30
					Vec2(0, 40), -- 30
					Vec2(80, 20) -- 30
				}, -- 30
				friction = 0.2 -- 30
			} -- 30
		) -- 30
	), -- 30
	React.createElement( -- 30
		"body", -- 30
		{ -- 30
			key = "moving", -- 30
			ref = movingRef, -- 30
			type = "Dynamic", -- 30
			group = 2, -- 30
			y = 120, -- 30
			linearAcceleration = Vec2(0, -10), -- 30
			onContactFilter = function() -- 30
				contactFilterCalls = contactFilterCalls + 1 -- 40
				return true -- 41
			end -- 39
		}, -- 39
		React.createElement("disk-fixture", {radius = 20, density = 1, friction = 0.4, restitution = 0.2}), -- 39
		React.createElement( -- 39
			"polygon-fixture", -- 39
			{ -- 39
				verts = { -- 39
					Vec2(-12, -12), -- 45
					Vec2(12, -12), -- 45
					Vec2(0, 12) -- 45
				}, -- 45
				sensorTag = 3 -- 45
			} -- 45
		) -- 45
	) -- 45
)) -- 45
local world = worldRef.current -- 50
local terrain = bodyRef.current -- 51
local moving = movingRef.current -- 52
expect(world ~= nil, "physics-world was not mounted") -- 53
expect(terrain ~= nil, "static body was not mounted") -- 54
expect(moving ~= nil, "dynamic body was not mounted") -- 55
expect(host.hasChildren, "physics-world was not added to host") -- 56
expect(contactFilterCalls == 0, "contact filter should not run during mount") -- 57
root:render(React.createElement( -- 59
	"physics-world", -- 59
	{ref = worldRef, showDebug = false}, -- 59
	React.createElement( -- 59
		"body", -- 59
		{ -- 59
			key = "terrain", -- 59
			ref = bodyRef, -- 59
			type = "Dynamic", -- 59
			group = 1, -- 59
			y = 20 -- 59
		}, -- 59
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 59
	) -- 59
)) -- 59
expect(worldRef.current ~= world, "physics-world should recreate when contact config changes") -- 67
expect(bodyRef.current ~= terrain, "body should recreate when move type changes") -- 68
expect(movingRef.current == moving, "removed body ref should keep the last mounted node") -- 69
root:unmount() -- 71
expect(not host.hasChildren, "physics nodes unmount did not clear host") -- 72
host:removeFromParent(true) -- 73
Content:save(resultFile, "passed") -- 74
Log("Info", "[DoraXPhysicsNodesTest] passed") -- 75
return ____exports -- 75