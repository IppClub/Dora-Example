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
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXPhysicsNodesTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local host = DNode() -- 17
Director.entry:addChild(host) -- 18
local root = createRoot(host) -- 20
local worldRef = useRef() -- 21
local bodyRef = useRef() -- 22
local movingRef = useRef() -- 23
local contactFilterCalls = 0 -- 24
root:render(React.createElement( -- 26
	"physics-world", -- 26
	{ref = worldRef, showDebug = true}, -- 26
	React.createElement("contact", {groupA = 1, groupB = 2, enabled = true}), -- 26
	React.createElement( -- 26
		"body", -- 26
		{key = "terrain", ref = bodyRef, type = "Static", group = 1}, -- 26
		React.createElement("rect-fixture", {width = 160, height = 12, friction = 0.8, restitution = 0.1}), -- 26
		React.createElement( -- 26
			"chain-fixture", -- 26
			{ -- 26
				verts = { -- 26
					Vec2(-80, 20), -- 31
					Vec2(0, 40), -- 31
					Vec2(80, 20) -- 31
				}, -- 31
				friction = 0.2 -- 31
			} -- 31
		) -- 31
	), -- 31
	React.createElement( -- 31
		"body", -- 31
		{ -- 31
			key = "moving", -- 31
			ref = movingRef, -- 31
			type = "Dynamic", -- 31
			group = 2, -- 31
			y = 120, -- 31
			linearAcceleration = Vec2(0, -10), -- 31
			onContactFilter = function() -- 31
				contactFilterCalls = contactFilterCalls + 1 -- 41
				return true -- 42
			end -- 40
		}, -- 40
		React.createElement("disk-fixture", {radius = 20, density = 1, friction = 0.4, restitution = 0.2}), -- 40
		React.createElement( -- 40
			"polygon-fixture", -- 40
			{ -- 40
				verts = { -- 40
					Vec2(-12, -12), -- 46
					Vec2(12, -12), -- 46
					Vec2(0, 12) -- 46
				}, -- 46
				sensorTag = 3 -- 46
			} -- 46
		) -- 46
	) -- 46
)) -- 46
local world = worldRef.current -- 51
local terrain = bodyRef.current -- 52
local moving = movingRef.current -- 53
expect(world ~= nil, "physics-world was not mounted") -- 54
expect(terrain ~= nil, "static body was not mounted") -- 55
expect(moving ~= nil, "dynamic body was not mounted") -- 56
expect(host.hasChildren, "physics-world was not added to host") -- 57
expect(contactFilterCalls == 0, "contact filter should not run during mount") -- 58
root:render(React.createElement( -- 60
	"physics-world", -- 60
	{ref = worldRef, showDebug = false}, -- 60
	React.createElement( -- 60
		"body", -- 60
		{ -- 60
			key = "terrain", -- 60
			ref = bodyRef, -- 60
			type = "Dynamic", -- 60
			group = 1, -- 60
			y = 20 -- 60
		}, -- 60
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 60
	) -- 60
)) -- 60
expect(worldRef.current == world, "physics-world should patch contact config without recreating") -- 68
expect(bodyRef.current ~= terrain, "body should recreate when move type changes") -- 69
expect(movingRef.current == nil, "removed body ref should be cleared") -- 70
local patchedWorld = worldRef.current -- 72
local patchedBody = bodyRef.current -- 73
root:render(React.createElement( -- 74
	"physics-world", -- 74
	{ref = worldRef, showDebug = true}, -- 74
	React.createElement( -- 74
		"body", -- 74
		{ -- 74
			key = "terrain", -- 74
			ref = bodyRef, -- 74
			type = "Dynamic", -- 74
			group = 2, -- 74
			y = 40 -- 74
		}, -- 74
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 74
	) -- 74
)) -- 74
expect(worldRef.current == patchedWorld, "physics-world should patch when contact config is unchanged") -- 82
expect(bodyRef.current == patchedBody, "body should patch non-structural props without recreating") -- 83
expect(bodyRef.current.y == 40, "body y prop was not patched") -- 84
expect(bodyRef.current.group == 2, "body group prop was not patched") -- 85
root:render(React.createElement( -- 87
	"physics-world", -- 87
	{ref = worldRef, showDebug = true}, -- 87
	React.createElement( -- 87
		"body", -- 87
		{ -- 87
			key = "terrain", -- 87
			ref = bodyRef, -- 87
			type = "Dynamic", -- 87
			group = 2, -- 87
			y = 40, -- 87
			onContactFilter = function() return false end -- 87
		}, -- 87
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 87
	) -- 87
)) -- 87
expect(bodyRef.current == patchedBody, "adding contact filter should patch body without recreating") -- 101
root:render(React.createElement( -- 103
	"physics-world", -- 103
	{ref = worldRef, showDebug = true}, -- 103
	React.createElement( -- 103
		"body", -- 103
		{ -- 103
			key = "terrain", -- 103
			ref = bodyRef, -- 103
			type = "Dynamic", -- 103
			group = 2, -- 103
			y = 40, -- 103
			onContactFilter = function() return true end -- 103
		}, -- 103
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 103
	) -- 103
)) -- 103
expect(bodyRef.current == patchedBody, "changing contact filter should patch body without recreating") -- 117
root:render(React.createElement( -- 119
	"physics-world", -- 119
	{ref = worldRef, showDebug = true}, -- 119
	React.createElement( -- 119
		"body", -- 119
		{ -- 119
			key = "terrain", -- 119
			ref = bodyRef, -- 119
			type = "Dynamic", -- 119
			group = 2, -- 119
			y = 40 -- 119
		}, -- 119
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 119
	) -- 119
)) -- 119
expect(bodyRef.current == patchedBody, "removing contact filter should patch body without recreating") -- 126
expect(not bodyRef.current.receivingContact, "body should start without receiving contact after contact event removal") -- 127
root:render(React.createElement( -- 129
	"physics-world", -- 129
	{ref = worldRef, showDebug = true}, -- 129
	React.createElement( -- 129
		"body", -- 129
		{ -- 129
			key = "terrain", -- 129
			ref = bodyRef, -- 129
			type = "Dynamic", -- 129
			group = 2, -- 129
			y = 40, -- 129
			onContactStart = function() -- 129
			end -- 137
		}, -- 137
		React.createElement("rect-fixture", {width = 120, height = 20, friction = 0.5, restitution = 0.3}) -- 137
	) -- 137
)) -- 137
expect(bodyRef.current == patchedBody, "adding contact event should patch body without recreating") -- 143
expect(bodyRef.current.receivingContact, "adding contact event should auto-enable receivingContact") -- 144
root:unmount() -- 146
expect(not host.hasChildren, "physics nodes unmount did not clear host") -- 147
host:removeFromParent(true) -- 148
Content:save(resultFile, "passed") -- 149
Log("Info", "[DoraXPhysicsNodesTest] passed") -- 150
return ____exports -- 150