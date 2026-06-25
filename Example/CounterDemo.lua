-- [tsx]: CounterDemo.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local Ease = ____Dora.Ease -- 2
local DNode = ____Dora.Node -- 2
local loop = ____Dora.loop -- 2
local sleep = ____Dora.sleep -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local host = DNode() -- 5
Director.entry:addChild(host) -- 6
local root = createRoot(host) -- 8
local function renderBars(value) -- 10
	local bars = {} -- 11
	local active = value % 10 -- 12
	for i = 0, 9 do -- 12
		bars[#bars + 1] = React.createElement( -- 14
			"node", -- 14
			{ -- 14
				key = i, -- 14
				x = (i - 4.5) * 24, -- 14
				y = -72, -- 14
				width = 16, -- 14
				height = 24 + i * 4, -- 14
				anchorX = 0.5, -- 14
				anchorY = 0, -- 14
				color3 = i <= active and 5621759 or 4871528, -- 14
				opacity = i <= active and 1 or 0.35 -- 14
			}, -- 14
			React.createElement( -- 14
				"draw-node", -- 14
				nil, -- 14
				React.createElement("rect-shape", {width = 16, height = 24 + i * 4, fillColor = 4294967295}) -- 14
			) -- 14
		) -- 14
	end -- 14
	return bars -- 32
end -- 10
local count = signal(0) -- 35
root:render(function() return React.createElement( -- 37
	"node", -- 37
	nil, -- 37
	React.createElement("label", { -- 37
		key = "title", -- 37
		fontName = "sarasa-mono-sc-regular", -- 37
		fontSize = 32, -- 37
		text = "DoraX Counter", -- 37
		y = 72, -- 37
		color3 = 16777215 -- 37
	}), -- 37
	React.createElement( -- 37
		"label", -- 37
		{ -- 37
			key = "count", -- 37
			fontName = "sarasa-mono-sc-regular", -- 37
			fontSize = 52, -- 37
			text = tostring(count.value), -- 37
			color3 = 16765286 -- 37
		}, -- 37
		React.createElement("scale", { -- 37
			exclusive = true, -- 37
			time = 0.2, -- 37
			start = 1.35, -- 37
			stop = 1, -- 37
			easing = Ease.OutBack -- 37
		}), -- 37
		React.createElement("angle", { -- 37
			exclusive = true, -- 37
			time = 0.2, -- 37
			start = count.value % 2 == 0 and -8 or 8, -- 37
			stop = 0, -- 37
			easing = Ease.OutQuad -- 37
		}) -- 37
	), -- 37
	renderBars(count.value) -- 57
) end) -- 57
host:schedule(loop(function() -- 61
	sleep(0.5) -- 62
	count.value = count.value + 1 -- 63
	return false -- 64
end)) -- 61
host:onCleanup(function() -- 67
	host:unschedule() -- 68
	root:unmount() -- 69
end) -- 67
Director.clearColor = Color(4280232247) -- 72
return ____exports -- 72