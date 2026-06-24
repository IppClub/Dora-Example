-- [tsx]: ButtonInteractionDemo.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local DNode = ____Dora.Node -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local function Button(props) -- 14
	local width = 220 -- 15
	local height = 64 -- 16
	local fillColor = props.pressed and 4280640491 or 4279203438 -- 17
	local borderColor = props.pressed and 4290763774 or 4291623921 -- 18
	return React.createElement( -- 20
		"node", -- 20
		{ -- 20
			key = "button", -- 20
			width = width, -- 20
			height = height, -- 20
			touchEnabled = true, -- 20
			onTapBegan = props.onPress, -- 20
			onTapEnded = props.onRelease, -- 20
			onTapped = props.onTap -- 20
		}, -- 20
		React.createElement( -- 20
			"draw-node", -- 20
			{key = "background"}, -- 20
			React.createElement("rect-shape", { -- 20
				centerX = width / 2, -- 20
				centerY = height / 2, -- 20
				width = width, -- 20
				height = height, -- 20
				fillColor = fillColor, -- 20
				borderWidth = 3, -- 20
				borderColor = borderColor -- 20
			}) -- 20
		), -- 20
		React.createElement( -- 20
			"label", -- 20
			{ -- 20
				sdf = true, -- 20
				key = "button-text", -- 20
				x = width / 2, -- 20
				y = height / 2, -- 20
				fontName = "sarasa-mono-sc-regular", -- 20
				fontSize = 24, -- 20
				text = (props.text .. ": ") .. tostring(props.count), -- 20
				color3 = 16777215 -- 20
			} -- 20
		) -- 20
	) -- 20
end -- 14
local host = DNode() -- 55
Director.entry:addChild(host) -- 56
local root = createRoot(host) -- 58
local clicks = signal(0) -- 59
local pressed = signal(false) -- 60
local function onTap() -- 62
	clicks.value = clicks.value + 1 -- 63
end -- 62
local function onPress() -- 66
	pressed.value = true -- 67
end -- 66
local function onRelease() -- 70
	pressed.value = false -- 71
end -- 70
root:render(function() return React.createElement( -- 74
	"node", -- 74
	{scaleX = 2, scaleY = 2}, -- 74
	React.createElement("label", { -- 74
		sdf = true, -- 74
		key = "title", -- 74
		fontName = "sarasa-mono-sc-regular", -- 74
		fontSize = 30, -- 74
		text = "DoraX Button Interaction", -- 74
		y = 110, -- 74
		color3 = 16777215 -- 74
	}), -- 74
	React.createElement(Button, { -- 74
		text = pressed.value and "Pressed" or "Tap", -- 74
		count = clicks.value, -- 74
		pressed = pressed.value, -- 74
		onTap = onTap, -- 74
		onPress = onPress, -- 74
		onRelease = onRelease -- 74
	}), -- 74
	React.createElement("label", { -- 74
		sdf = true, -- 74
		key = "hint", -- 74
		fontName = "sarasa-mono-sc-regular", -- 74
		fontSize = 18, -- 74
		text = "Tap the button to verify signal-driven TSX diff updates.", -- 74
		y = -100, -- 74
		color3 = 13751771 -- 74
	}) -- 74
) end) -- 74
host:onCleanup(function() -- 105
	root:unmount() -- 106
end) -- 105
Director.clearColor = Color(4279310375) -- 109
return ____exports -- 109