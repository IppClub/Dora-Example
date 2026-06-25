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
local reference = ____DoraX.reference -- 3
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
local drawRef = reference() -- 20
local clipRef = reference() -- 21
local particleRef = reference() -- 22
local alignRef = reference() -- 23
local lineRef = reference() -- 24
local customRef = reference() -- 25
local customCreatedA = DNode() -- 26
local customCreatedB = DNode() -- 27
local createA = 0 -- 28
local createB = 0 -- 29
local function makeA() -- 31
	createA = createA + 1 -- 32
	return customCreatedA -- 33
end -- 31
local function makeB() -- 36
	createB = createB + 1 -- 37
	return customCreatedB -- 38
end -- 36
root:render(React.createElement( -- 41
	"node", -- 41
	nil, -- 41
	React.createElement( -- 41
		"draw-node", -- 41
		{key = "draw", ref = drawRef}, -- 41
		React.createElement("dot-shape", {x = 0, y = 0, radius = 4, color = 4294967295}), -- 41
		React.createElement("segment-shape", { -- 41
			startX = -10, -- 41
			startY = -10, -- 41
			stopX = 10, -- 41
			stopY = 10, -- 41
			radius = 2, -- 41
			color = 4294967295 -- 41
		}), -- 41
		React.createElement("rect-shape", { -- 41
			width = 20, -- 41
			height = 10, -- 41
			fillColor = 4294967295, -- 41
			borderWidth = 1, -- 41
			borderColor = 4278190080 -- 41
		}), -- 41
		React.createElement( -- 41
			"polygon-shape", -- 41
			{ -- 41
				verts = { -- 41
					Vec2(-8, -8), -- 47
					Vec2(8, -8), -- 47
					Vec2(0, 8) -- 47
				}, -- 47
				fillColor = 4294967295 -- 47
			} -- 47
		), -- 47
		React.createElement( -- 47
			"verts-shape", -- 47
			{verts = { -- 47
				{ -- 48
					Vec2(-4, 4), -- 48
					4294967295 -- 48
				}, -- 48
				{ -- 48
					Vec2(4, 4), -- 48
					4294967295 -- 48
				}, -- 48
				{ -- 48
					Vec2(0, -4), -- 48
					4294967295 -- 48
				} -- 48
			}} -- 48
		) -- 48
	), -- 48
	React.createElement( -- 48
		"clip-node", -- 48
		{ -- 48
			key = "clip", -- 48
			ref = clipRef, -- 48
			stencil = React.createElement( -- 48
				"draw-node", -- 48
				nil, -- 48
				React.createElement("rect-shape", {width = 12, height = 12, fillColor = 4294967295}) -- 48
			) -- 48
		}, -- 48
		React.createElement("node", nil) -- 48
	), -- 48
	React.createElement("particle", {key = "particle", ref = particleRef, file = "Particle/heart.par", emit = true}), -- 48
	React.createElement("align-node", {key = "align", ref = alignRef, style = {width = 120, height = 40, margin = {1, 2, 3, 4}}}), -- 48
	React.createElement( -- 48
		"line", -- 48
		{ -- 48
			key = "line", -- 48
			ref = lineRef, -- 48
			verts = { -- 48
				Vec2(-4, 0), -- 59
				Vec2(4, 0) -- 59
			}, -- 59
			lineColor = 4294967295 -- 59
		} -- 59
	), -- 59
	React.createElement("custom-node", {key = "custom", ref = customRef, onCreate = makeA}) -- 59
)) -- 59
local draw = drawRef.current -- 64
local clip = clipRef.current -- 65
local particle = particleRef.current -- 66
local align = alignRef.current -- 67
local line = lineRef.current -- 68
local custom = customRef.current -- 69
expect(draw ~= nil, "draw-node was not mounted") -- 70
expect(clip ~= nil, "clip-node was not mounted") -- 71
expect(particle ~= nil, "particle was not mounted") -- 72
expect(align ~= nil, "align-node was not mounted") -- 73
expect(line ~= nil, "line was not mounted") -- 74
expect(custom == customCreatedA, "custom-node did not use onCreate result") -- 75
expect(createA == 1, "custom-node onCreate should run once on initial mount") -- 76
expect(clip.hasChildren, "clip-node child was not mounted") -- 77
expect(particle.active, "particle emit helper did not start particle") -- 78
root:render(React.createElement( -- 80
	"node", -- 80
	nil, -- 80
	React.createElement( -- 80
		"draw-node", -- 80
		{key = "draw", ref = drawRef}, -- 80
		React.createElement("rect-shape", {width = 30, height = 20, fillColor = 4278255360}) -- 80
	), -- 80
	React.createElement("particle", {key = "particle", ref = particleRef, file = "Particle/heart.par", emit = false}), -- 80
	React.createElement("align-node", {key = "align", ref = alignRef, style = {width = 180, height = 60, padding = {2, 4}}}), -- 80
	React.createElement( -- 80
		"line", -- 80
		{ -- 80
			key = "line", -- 80
			ref = lineRef, -- 80
			verts = { -- 80
				Vec2(-8, 0), -- 87
				Vec2(8, 0), -- 87
				Vec2(0, 8) -- 87
			}, -- 87
			lineColor = 4278255615 -- 87
		} -- 87
	), -- 87
	React.createElement("custom-node", {key = "custom", ref = customRef, onCreate = makeB}) -- 87
)) -- 87
expect(drawRef.current ~= draw, "draw-node should recreate when its shape definition changes") -- 92
expect(particleRef.current == particle, "particle emit change should patch without recreating") -- 93
expect(not particleRef.current.active, "particle emit=false should call stop during patch") -- 94
expect(alignRef.current == align, "align-node style change should patch without recreating") -- 95
expect(lineRef.current == line, "line verts change should patch without recreating") -- 96
expect(customRef.current == customCreatedB, "custom-node should recreate when onCreate changes") -- 97
expect(createB == 1, "new custom-node onCreate should run once") -- 98
root:unmount() -- 100
expect(not host.hasChildren, "special nodes unmount did not clear host") -- 101
host:removeFromParent(true) -- 102
Content:save(resultFile, "passed") -- 103
Log("Info", "[DoraXSpecialNodesTest] passed") -- 104
return ____exports -- 104