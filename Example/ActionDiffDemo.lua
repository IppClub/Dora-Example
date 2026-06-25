-- [tsx]: ActionDiffDemo.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local Ease = ____Dora.Ease -- 2
local DNode = ____Dora.Node -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local function Button(props) -- 14
	local width = 190 -- 15
	local height = 52 -- 16
	return React.createElement( -- 17
		"node", -- 17
		{ -- 17
			key = props.key, -- 17
			x = props.x, -- 17
			y = props.y, -- 17
			width = width, -- 17
			height = height, -- 17
			touchEnabled = true, -- 17
			onTapped = props.onTap -- 17
		}, -- 17
		React.createElement( -- 17
			"draw-node", -- 17
			{key = "face"}, -- 17
			React.createElement("rect-shape", { -- 17
				centerX = width / 2, -- 17
				centerY = height / 2, -- 17
				width = width, -- 17
				height = height, -- 17
				fillColor = props.color, -- 17
				borderWidth = 2, -- 17
				borderColor = 4294967295 -- 17
			}) -- 17
		), -- 17
		React.createElement("label", { -- 17
			key = "text", -- 17
			sdf = true, -- 17
			x = width / 2, -- 17
			y = height / 2, -- 17
			fontName = "sarasa-mono-sc-regular", -- 17
			fontSize = 20, -- 17
			color3 = 16777215, -- 17
			text = props.text -- 17
		}) -- 17
	) -- 17
end -- 14
local function Actor(props) -- 54
	local targetX = props.trigger % 2 == 0 and -150 or 150 -- 55
	local fillColor = props.exclusive and 4294538006 or 4279548070 -- 56
	return React.createElement( -- 57
		"node", -- 57
		{key = props.key, x = props.x, y = props.y}, -- 57
		React.createElement("label", { -- 57
			key = "title", -- 57
			sdf = true, -- 57
			y = 72, -- 57
			fontName = "sarasa-mono-sc-regular", -- 57
			fontSize = 22, -- 57
			color3 = 16777215, -- 57
			text = props.title -- 57
		}), -- 57
		React.createElement("label", { -- 57
			key = "hint", -- 57
			sdf = true, -- 57
			y = 42, -- 57
			fontName = "sarasa-mono-sc-regular", -- 57
			fontSize = 16, -- 57
			color3 = 13358561, -- 57
			text = props.hint -- 57
		}), -- 57
		React.createElement( -- 57
			"node", -- 57
			{key = "actor"}, -- 57
			React.createElement( -- 57
				"draw-node", -- 57
				{key = "shape"}, -- 57
				React.createElement("rect-shape", { -- 57
					centerX = 0, -- 57
					centerY = 0, -- 57
					width = 72, -- 57
					height = 72, -- 57
					fillColor = fillColor, -- 57
					borderWidth = 3, -- 57
					borderColor = 4294967295 -- 57
				}) -- 57
			), -- 57
			React.createElement("move-x", { -- 57
				exclusive = props.exclusive, -- 57
				time = 0.75, -- 57
				start = 0, -- 57
				stop = targetX, -- 57
				easing = Ease.OutQuad -- 57
			}), -- 57
			React.createElement("angle", { -- 57
				exclusive = props.exclusive, -- 57
				time = 0.75, -- 57
				start = 0, -- 57
				stop = props.trigger * 10, -- 57
				easing = Ease.OutQuad -- 57
			}) -- 57
		), -- 57
		React.createElement( -- 57
			"label", -- 57
			{ -- 57
				key = "count", -- 57
				sdf = true, -- 57
				y = -72, -- 57
				fontName = "sarasa-mono-sc-regular", -- 57
				fontSize = 16, -- 57
				color3 = 14870768, -- 57
				text = "trigger " .. tostring(props.trigger) -- 57
			} -- 57
		) -- 57
	) -- 57
end -- 54
local host = DNode() -- 105
Director.entry:addChild(host) -- 106
local normalTrigger = signal(0) -- 108
local exclusiveTrigger = signal(0) -- 109
local root = createRoot(host) -- 110
root:render(function() return React.createElement( -- 112
	"node", -- 112
	{scaleX = 1.6, scaleY = 1.6}, -- 112
	React.createElement("label", { -- 112
		key = "headline", -- 112
		sdf = true, -- 112
		y = 170, -- 112
		fontName = "sarasa-mono-sc-regular", -- 112
		fontSize = 28, -- 112
		color3 = 16777215, -- 112
		text = "DoraX Action Diff" -- 112
	}), -- 112
	React.createElement(Actor, { -- 112
		key = "normal", -- 112
		x = -210, -- 112
		y = 20, -- 112
		title = "runAction", -- 112
		hint = "tap quickly: actions can overlap", -- 112
		trigger = normalTrigger.value -- 112
	}), -- 112
	React.createElement(Actor, { -- 112
		key = "exclusive", -- 112
		x = 210, -- 112
		y = 20, -- 112
		title = "exclusive", -- 112
		hint = "tap quickly: perform replaces old action", -- 112
		trigger = exclusiveTrigger.value, -- 112
		exclusive = true -- 112
	}), -- 112
	React.createElement( -- 112
		Button, -- 140
		{ -- 140
			key = "normal-button", -- 140
			x = -305, -- 140
			y = -145, -- 140
			text = "Run Action", -- 140
			color = 4279203438, -- 140
			onTap = function() -- 140
				normalTrigger.value = normalTrigger.value + 1 -- 147
			end -- 146
		} -- 146
	), -- 146
	React.createElement( -- 146
		Button, -- 150
		{ -- 150
			key = "exclusive-button", -- 150
			x = 115, -- 150
			y = -145, -- 150
			text = "Exclusive", -- 150
			color = 4290920716, -- 150
			onTap = function() -- 150
				exclusiveTrigger.value = exclusiveTrigger.value + 1 -- 157
			end -- 156
		} -- 156
	) -- 156
) end) -- 156
host:onCleanup(function() -- 163
	root:unmount() -- 164
end) -- 163
Director.clearColor = Color(4279310375) -- 167
return ____exports -- 167