-- [tsx]: DrawNodeShapesTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Color = ____Dora.Color -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local DrawNode = ____Dora.DrawNode -- 1
local Log = ____Dora.Log -- 1
local Node = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local Rect = ____Dora.Rect -- 1
local Vec2 = ____Dora.Vec2 -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local toNode = ____DoraX.toNode -- 3
local resultFile = Path(Content.writablePath, "DoraXDrawNodeShapesTest.result") -- 7
Content:save(resultFile, "running") -- 8
local drawRef = reference() -- 9
local fill = 2151727359 -- 10
local border = 3237969984 -- 11
local verts = { -- 12
	Vec2(-95, -20), -- 12
	Vec2(-80, -45), -- 12
	Vec2(-65, -15) -- 12
} -- 12
local function shapes(x, radius) -- 14
	return React.createElement( -- 15
		"draw-node", -- 15
		{x = x, ref = drawRef}, -- 15
		React.createElement("circle-shape", {centerX = -80, centerY = 70, radius = radius, color = fill}), -- 15
		React.createElement("ellipse-shape", { -- 15
			centerX = 0, -- 15
			centerY = 70, -- 15
			radiusX = 28, -- 15
			radiusY = 16, -- 15
			color = fill -- 15
		}), -- 15
		React.createElement("rounded-rect-shape", { -- 15
			centerX = 80, -- 15
			centerY = 70, -- 15
			width = 48, -- 15
			height = 36, -- 15
			cornerRadius = 9, -- 15
			fillColor = fill, -- 15
			borderWidth = 3, -- 15
			borderColor = border -- 15
		}), -- 15
		React.createElement("ring-shape", { -- 15
			centerX = -80, -- 15
			innerRadius = 12, -- 15
			outerRadius = 25, -- 15
			fillColor = fill, -- 15
			borderWidth = 3, -- 15
			borderColor = border -- 15
		}), -- 15
		React.createElement("sector-shape", { -- 15
			radius = 25, -- 15
			startAngle = 35, -- 15
			endAngle = -235, -- 15
			fillColor = fill, -- 15
			borderWidth = 4, -- 15
			borderColor = border -- 15
		}), -- 15
		React.createElement("arc-shape", { -- 15
			centerX = 80, -- 15
			radius = 25, -- 15
			startAngle = -25, -- 15
			endAngle = 245, -- 15
			lineRadius = 4, -- 15
			color = border -- 15
		}), -- 15
		React.createElement("polyline-shape", {verts = verts, radius = 4, color = fill, closed = true}), -- 15
		React.createElement("quadratic-bezier-shape", { -- 15
			startX = -25, -- 15
			startY = -75, -- 15
			controlX = 0, -- 15
			controlY = -15, -- 15
			stopX = 25, -- 15
			stopY = -65, -- 15
			radius = 4, -- 15
			color = border -- 15
		}), -- 15
		React.createElement("cubic-bezier-shape", { -- 15
			startX = 55, -- 15
			startY = -65, -- 15
			control1X = 60, -- 15
			control1Y = -10, -- 15
			control2X = 100, -- 15
			control2Y = -110, -- 15
			stopX = 105, -- 15
			stopY = -65, -- 15
			radius = 4, -- 15
			color = border -- 15
		}), -- 15
		React.createElement("rect-shape", { -- 15
			centerX = -80, -- 15
			centerY = -110, -- 15
			width = 36, -- 15
			height = 20, -- 15
			fillColor = fill, -- 15
			borderWidth = 2, -- 15
			borderColor = border -- 15
		}), -- 15
		React.createElement("circle-shape", {radius = 3}), -- 15
		React.createElement("ellipse-shape", {radiusX = 5, radiusY = 2}), -- 15
		React.createElement("rounded-rect-shape", {centerY = -110, width = 20, height = 15, cornerRadius = 4}), -- 15
		React.createElement("ring-shape", {centerX = 80, centerY = -110, innerRadius = 5, outerRadius = 10}), -- 15
		React.createElement("sector-shape", { -- 15
			centerY = -145, -- 15
			radius = 10, -- 15
			startAngle = 0, -- 15
			endAngle = 360, -- 15
			fillColor = 0, -- 15
			borderWidth = 2 -- 15
		}), -- 15
		React.createElement( -- 15
			"polyline-shape", -- 15
			{ -- 15
				verts = { -- 15
					Vec2(60, -145), -- 32
					Vec2(80, -135), -- 32
					Vec2(100, -145) -- 32
				}, -- 32
				radius = 2 -- 32
			} -- 32
		), -- 32
		React.createElement("arc-shape", {radius = 7, startAngle = 0, endAngle = 180, lineRadius = 1}), -- 32
		React.createElement("quadratic-bezier-shape", { -- 32
			startX = -10, -- 32
			startY = -170, -- 32
			controlX = 0, -- 32
			controlY = -150, -- 32
			stopX = 10, -- 32
			stopY = -170, -- 32
			radius = 1 -- 32
		}), -- 32
		React.createElement("cubic-bezier-shape", { -- 32
			startX = 65, -- 32
			startY = -170, -- 32
			control1X = 70, -- 32
			control1Y = -150, -- 32
			control2X = 90, -- 32
			control2Y = -190, -- 32
			stopX = 95, -- 32
			stopY = -170, -- 32
			radius = 1 -- 32
		}) -- 32
	) -- 32
end -- 14
local function expect(condition, message) -- 39
	if not condition then -- 39
		error("[DoraXDrawNodeShapesTest] " .. message) -- 40
	end -- 40
end -- 39
local staticNode = toNode(shapes(-300, 24)) -- 43
expect(staticNode ~= nil, "static draw-node missing") -- 44
expect(not staticNode.hasChildren, "static shape tags must not create scene children") -- 45
Director.entry:addChild(staticNode) -- 46
local host = Node() -- 48
Director.entry:addChild(host) -- 49
local root = createRoot(host) -- 50
root:render(shapes(0, 8)) -- 51
local first = drawRef.current -- 52
expect(first ~= nil, "dynamic draw-node missing") -- 53
root:render(shapes(0, 24)) -- 54
expect(drawRef.current ~= first, "shape updates must redraw geometry") -- 55
expect(not drawRef.current.hasChildren, "dynamic shape tags must not create scene children") -- 56
local ____expect_2 = expect -- 57
local ____opt_0 = host.children -- 57
____expect_2((____opt_0 and ____opt_0.count) == 1, "update must replace the old draw-node") -- 57
local direct = DrawNode() -- 59
direct.x = 300 -- 60
direct:drawCircle( -- 61
	Vec2(-80, 70), -- 61
	24, -- 61
	Color(fill) -- 61
) -- 61
direct:drawEllipse( -- 62
	Vec2(0, 70), -- 62
	28, -- 62
	16, -- 62
	Color(fill) -- 62
) -- 62
direct:drawRoundedRect( -- 63
	Rect(56, 52, 48, 36), -- 63
	9, -- 63
	Color(fill), -- 63
	3, -- 63
	Color(border) -- 63
) -- 63
direct:drawRing( -- 64
	Vec2(-80, 0), -- 64
	12, -- 64
	25, -- 64
	Color(fill), -- 64
	3, -- 64
	Color(border) -- 64
) -- 64
direct:drawSector( -- 65
	Vec2.zero, -- 65
	25, -- 65
	35, -- 65
	-235, -- 65
	Color(fill), -- 65
	4, -- 65
	Color(border) -- 65
) -- 65
direct:drawArc( -- 66
	Vec2(80, 0), -- 66
	25, -- 66
	-25, -- 66
	245, -- 66
	4, -- 66
	Color(border) -- 66
) -- 66
direct:drawPolyline( -- 67
	verts, -- 67
	4, -- 67
	Color(fill), -- 67
	true -- 67
) -- 67
direct:drawQuadraticBezier( -- 68
	Vec2(-25, -75), -- 68
	Vec2(0, -15), -- 68
	Vec2(25, -65), -- 68
	4, -- 68
	Color(border) -- 68
) -- 68
direct:drawCubicBezier( -- 69
	Vec2(55, -65), -- 69
	Vec2(60, -10), -- 69
	Vec2(100, -110), -- 69
	Vec2(105, -65), -- 69
	4, -- 69
	Color(border) -- 69
) -- 69
direct:drawRect( -- 70
	Rect(-98, -120, 36, 20), -- 70
	Color(fill), -- 70
	2, -- 70
	Color(border) -- 70
) -- 70
direct:drawCircle( -- 71
	Vec2.zero, -- 71
	3, -- 71
	Color(4294967295) -- 71
) -- 71
direct:drawEllipse( -- 72
	Vec2.zero, -- 72
	5, -- 72
	2, -- 72
	Color(4294967295) -- 72
) -- 72
direct:drawRoundedRect( -- 73
	Rect(-10, -117.5, 20, 15), -- 73
	4, -- 73
	Color(4294967295), -- 73
	0, -- 73
	Color(4294967295) -- 73
) -- 73
direct:drawRing( -- 74
	Vec2(80, -110), -- 74
	5, -- 74
	10, -- 74
	Color(4294967295), -- 74
	0, -- 74
	Color(4294967295) -- 74
) -- 74
direct:drawSector( -- 75
	Vec2(0, -145), -- 75
	10, -- 75
	0, -- 75
	360, -- 75
	Color(0), -- 75
	2, -- 75
	Color(4294967295) -- 75
) -- 75
direct:drawPolyline( -- 76
	{ -- 76
		Vec2(60, -145), -- 76
		Vec2(80, -135), -- 76
		Vec2(100, -145) -- 76
	}, -- 76
	2, -- 76
	Color(4294967295), -- 76
	false -- 76
) -- 76
direct:drawArc( -- 77
	Vec2.zero, -- 77
	7, -- 77
	0, -- 77
	180, -- 77
	1, -- 77
	Color(4294967295) -- 77
) -- 77
direct:drawQuadraticBezier( -- 78
	Vec2(-10, -170), -- 78
	Vec2(0, -150), -- 78
	Vec2(10, -170), -- 78
	1, -- 78
	Color(4294967295) -- 78
) -- 78
direct:drawCubicBezier( -- 79
	Vec2(65, -170), -- 79
	Vec2(70, -150), -- 79
	Vec2(90, -190), -- 79
	Vec2(95, -170), -- 79
	1, -- 79
	Color(4294967295) -- 79
) -- 79
Director.entry:addChild(direct) -- 80
local cleanupHost = Node() -- 83
local cleanupRoot = createRoot(cleanupHost) -- 84
cleanupRoot:render(shapes(0, 24)) -- 85
cleanupRoot:unmount() -- 86
expect(not cleanupHost.hasChildren, "unmount must clear geometry and children") -- 87
expect(drawRef.current == nil, "unmount must clear the reference") -- 88
Content:save(resultFile, "passed") -- 89
Log("Info", "[DoraXDrawNodeShapesTest] passed") -- 90
return ____exports -- 90
