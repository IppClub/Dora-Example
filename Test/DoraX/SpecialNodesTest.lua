-- [tsx]: SpecialNodesTest.tsx
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
local resultFile = Path(Content.writablePath, "DoraXSpecialNodesTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXSpecialNodesTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local drawRef = useRef() -- 20
local clipRef = useRef() -- 21
local customRef = useRef() -- 22
local customCreatedA = DNode() -- 23
local customCreatedB = DNode() -- 24
local createA = 0 -- 25
local createB = 0 -- 26
local function makeA() -- 28
	createA = createA + 1 -- 29
	return customCreatedA -- 30
end -- 28
local function makeB() -- 33
	createB = createB + 1 -- 34
	return customCreatedB -- 35
end -- 33
root:render(React.createElement( -- 38
	"node", -- 38
	nil, -- 38
	React.createElement( -- 38
		"draw-node", -- 38
		{key = "draw", ref = drawRef}, -- 38
		React.createElement("dot-shape", {x = 0, y = 0, radius = 4, color = 4294967295}), -- 38
		React.createElement("segment-shape", { -- 38
			startX = -10, -- 38
			startY = -10, -- 38
			stopX = 10, -- 38
			stopY = 10, -- 38
			radius = 2, -- 38
			color = 4294967295 -- 38
		}), -- 38
		React.createElement("rect-shape", { -- 38
			width = 20, -- 38
			height = 10, -- 38
			fillColor = 4294967295, -- 38
			borderWidth = 1, -- 38
			borderColor = 4278190080 -- 38
		}), -- 38
		React.createElement( -- 38
			"polygon-shape", -- 38
			{ -- 38
				verts = { -- 38
					Vec2(-8, -8), -- 44
					Vec2(8, -8), -- 44
					Vec2(0, 8) -- 44
				}, -- 44
				fillColor = 4294967295 -- 44
			} -- 44
		), -- 44
		React.createElement( -- 44
			"verts-shape", -- 44
			{verts = { -- 44
				{ -- 45
					Vec2(-4, 4), -- 45
					4294967295 -- 45
				}, -- 45
				{ -- 45
					Vec2(4, 4), -- 45
					4294967295 -- 45
				}, -- 45
				{ -- 45
					Vec2(0, -4), -- 45
					4294967295 -- 45
				} -- 45
			}} -- 45
		) -- 45
	), -- 45
	React.createElement( -- 45
		"clip-node", -- 45
		{ -- 45
			key = "clip", -- 45
			ref = clipRef, -- 45
			stencil = React.createElement( -- 45
				"draw-node", -- 45
				nil, -- 45
				React.createElement("rect-shape", {width = 12, height = 12, fillColor = 4294967295}) -- 45
			) -- 45
		}, -- 45
		React.createElement("node", nil) -- 45
	), -- 45
	React.createElement("custom-node", {key = "custom", ref = customRef, onCreate = makeA}) -- 45
)) -- 45
local draw = drawRef.current -- 58
local clip = clipRef.current -- 59
local custom = customRef.current -- 60
expect(draw ~= nil, "draw-node was not mounted") -- 61
expect(clip ~= nil, "clip-node was not mounted") -- 62
expect(custom == customCreatedA, "custom-node did not use onCreate result") -- 63
expect(createA == 1, "custom-node onCreate should run once on initial mount") -- 64
expect(clip.hasChildren, "clip-node child was not mounted") -- 65
root:render(React.createElement( -- 67
	"node", -- 67
	nil, -- 67
	React.createElement( -- 67
		"draw-node", -- 67
		{key = "draw", ref = drawRef}, -- 67
		React.createElement("rect-shape", {width = 30, height = 20, fillColor = 4278255360}) -- 67
	), -- 67
	React.createElement("custom-node", {key = "custom", ref = customRef, onCreate = makeB}) -- 67
)) -- 67
expect(drawRef.current ~= draw, "draw-node should recreate when its shape definition changes") -- 76
expect(customRef.current == customCreatedB, "custom-node should recreate when onCreate changes") -- 77
expect(createB == 1, "new custom-node onCreate should run once") -- 78
root:unmount() -- 80
expect(not host.hasChildren, "special nodes unmount did not clear host") -- 81
host:removeFromParent(true) -- 82
Content:save(resultFile, "passed") -- 83
Log("Info", "[DoraXSpecialNodesTest] passed") -- 84
return ____exports -- 84