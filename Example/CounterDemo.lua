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
local count = signal(0) -- 10
local function renderBars(value) -- 12
	local bars = {} -- 13
	local active = value % 10 -- 14
	for i = 0, 9 do -- 14
		local ____React_createElement_4 = React.createElement -- 14
		local ____temp_3 = { -- 14
			key = i, -- 14
			x = (i - 4.5) * 24, -- 14
			y = -72, -- 14
			width = 16, -- 14
			height = 24 + i * 4, -- 14
			anchorX = 0.5, -- 14
			anchorY = 0, -- 14
			color3 = i <= active and 5621759 or 4871528, -- 14
			opacity = i <= active and 1 or 0.35 -- 14
		} -- 14
		local ____React_createElement_2 = React.createElement -- 14
		local ____React_createElement_result_1 = React.createElement("rect-shape", {width = 16, height = 24 + i * 4, fillColor = 4294967295}) -- 14
		local ____temp_0 -- 30
		if i == active then -- 30
			____temp_0 = React.createElement( -- 30
				React.Fragment, -- 30
				nil, -- 30
				React.createElement("scale", { -- 30
					exclusive = true, -- 30
					time = 0.2, -- 30
					start = 1.35, -- 30
					stop = 1, -- 30
					easing = Ease.OutBack -- 30
				}), -- 30
				React.createElement("angle", { -- 30
					exclusive = true, -- 30
					time = 0.2, -- 30
					start = count.value % 2 == 0 and -8 or 8, -- 30
					stop = 0, -- 30
					easing = Ease.OutQuad -- 30
				}) -- 30
			) -- 30
		else -- 30
			____temp_0 = nil -- 34
		end -- 34
		bars[#bars + 1] = ____React_createElement_4( -- 16
			"node", -- 16
			____temp_3, -- 16
			____React_createElement_2("draw-node", nil, ____React_createElement_result_1, ____temp_0) -- 16
		) -- 16
	end -- 16
	return bars -- 40
end -- 12
root:render(function() return React.createElement( -- 43
	"node", -- 43
	nil, -- 43
	React.createElement("label", { -- 43
		key = "title", -- 43
		fontName = "sarasa-mono-sc-regular", -- 43
		fontSize = 32, -- 43
		text = "DoraX Counter", -- 43
		y = 72, -- 43
		color3 = 16777215 -- 43
	}), -- 43
	React.createElement( -- 43
		"label", -- 43
		{ -- 43
			key = "count", -- 43
			fontName = "sarasa-mono-sc-regular", -- 43
			fontSize = 52, -- 43
			text = tostring(count.value), -- 43
			color3 = 16765286 -- 43
		}, -- 43
		React.createElement("scale", { -- 43
			exclusive = true, -- 43
			time = 0.2, -- 43
			start = 1.35, -- 43
			stop = 1, -- 43
			easing = Ease.OutBack -- 43
		}), -- 43
		React.createElement("angle", { -- 43
			exclusive = true, -- 43
			time = 0.2, -- 43
			start = count.value % 2 == 0 and -8 or 8, -- 43
			stop = 0, -- 43
			easing = Ease.OutQuad -- 43
		}) -- 43
	), -- 43
	renderBars(count.value) -- 63
) end) -- 63
host:schedule(loop(function() -- 67
	sleep(0.5) -- 68
	count.value = count.value + 1 -- 69
	return false -- 70
end)) -- 67
host:onCleanup(function() -- 73
	host:unschedule() -- 74
	root:unmount() -- 75
end) -- 73
Director.clearColor = Color(4280232247) -- 78
return ____exports -- 78