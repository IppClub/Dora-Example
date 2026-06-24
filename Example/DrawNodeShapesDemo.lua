-- [tsx]: DrawNodeShapesDemo.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local DNode = ____Dora.Node -- 2
local Vec2 = ____Dora.Vec2 -- 2
local loop = ____Dora.loop -- 2
local sleep = ____Dora.sleep -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local host = DNode() -- 5
Director.entry:addChild(host) -- 6
local root = createRoot(host) -- 8
local tick = signal(0) -- 9
local function shapeColor(index) -- 11
	local palette = { -- 12
		4294929259, -- 12
		4283354564, -- 12
		4294955366, -- 12
		4289170426, -- 12
		4294538006 -- 12
	} -- 12
	return palette[(tick.value + index) % #palette + 1] -- 13
end -- 11
root:render(function() return React.createElement( -- 16
	"node", -- 16
	nil, -- 16
	React.createElement("label", { -- 16
		key = "title", -- 16
		fontName = "sarasa-mono-sc-regular", -- 16
		fontSize = 28, -- 16
		text = "DoraX DrawNode Shapes", -- 16
		y = 135, -- 16
		color3 = 16777215 -- 16
	}), -- 16
	React.createElement( -- 16
		"draw-node", -- 16
		{key = "draw-" .. tostring(tick.value)}, -- 16
		React.createElement( -- 16
			"dot-shape", -- 16
			{ -- 16
				x = -150, -- 16
				y = 10, -- 16
				radius = 20 + tick.value % 8, -- 16
				color = shapeColor(0) -- 16
			} -- 16
		), -- 16
		React.createElement( -- 16
			"segment-shape", -- 16
			{ -- 16
				startX = -90, -- 16
				startY = -24, -- 16
				stopX = -40, -- 16
				stopY = 48, -- 16
				radius = 5, -- 16
				color = shapeColor(1) -- 16
			} -- 16
		), -- 16
		React.createElement( -- 16
			"rect-shape", -- 16
			{ -- 16
				centerX = 35, -- 16
				centerY = 12, -- 16
				width = 54, -- 16
				height = 54, -- 16
				fillColor = shapeColor(2), -- 16
				borderWidth = 3, -- 16
				borderColor = 4294967295 -- 16
			} -- 16
		), -- 16
		React.createElement( -- 16
			"polygon-shape", -- 16
			{ -- 16
				verts = { -- 16
					Vec2(110, -28), -- 31
					Vec2(164, -18), -- 31
					Vec2(142, 42) -- 31
				}, -- 31
				fillColor = shapeColor(3), -- 31
				borderWidth = 3, -- 31
				borderColor = 4294967295 -- 31
			} -- 31
		), -- 31
		React.createElement( -- 31
			"verts-shape", -- 31
			{verts = { -- 31
				{ -- 36
					Vec2(-22, -90), -- 36
					shapeColor(4) -- 36
				}, -- 36
				{ -- 36
					Vec2(22, -90), -- 36
					shapeColor(1) -- 36
				}, -- 36
				{ -- 36
					Vec2(0, -46), -- 36
					shapeColor(3) -- 36
				} -- 36
			}} -- 36
		) -- 36
	), -- 36
	React.createElement( -- 36
		"label", -- 36
		{ -- 36
			key = "hint", -- 36
			fontName = "sarasa-mono-sc-regular", -- 36
			fontSize = 18, -- 36
			text = "shape refresh " .. tostring(tick.value), -- 36
			y = -135, -- 36
			color3 = 13751771 -- 36
		} -- 36
	) -- 36
) end) -- 36
host:schedule(loop(function() -- 49
	sleep(0.6) -- 50
	tick.value = tick.value + 1 -- 51
	return false -- 52
end)) -- 49
host:onCleanup(function() -- 55
	host:unschedule() -- 56
	root:unmount() -- 57
end) -- 55
Director.clearColor = Color(4279179050) -- 60
return ____exports -- 60