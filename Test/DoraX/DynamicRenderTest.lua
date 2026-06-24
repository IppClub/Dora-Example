-- [tsx]: DynamicRenderTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXDynamicRenderTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXDynamicRenderTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local labelRef = useRef() -- 20
local firstNodeRef = useRef() -- 21
local secondNodeRef = useRef() -- 22
local keyedBRef = useRef() -- 23
local keyedARef = useRef() -- 24
local drawRef = useRef() -- 25
local buttonRef = useRef() -- 26
local buttonLabelRef = useRef() -- 27
local value = signal(1) -- 28
local buttonClicks = signal(0) -- 29
local function TestButton(props) -- 39
	local fillColor = props.count > 0 and 3003583 or 3900150 -- 40
	return React.createElement( -- 41
		"node", -- 41
		{ -- 41
			key = "button", -- 41
			ref = props.ref, -- 41
			width = 160, -- 41
			height = 54, -- 41
			touchEnabled = true, -- 41
			onTapped = props.onClick -- 41
		}, -- 41
		React.createElement( -- 41
			"draw-node", -- 41
			nil, -- 41
			React.createElement("rect-shape", { -- 41
				width = 160, -- 41
				height = 54, -- 41
				fillColor = fillColor, -- 41
				borderWidth = 2, -- 41
				borderColor = 4294967295 -- 41
			}) -- 41
		), -- 41
		React.createElement( -- 41
			"label", -- 41
			{ -- 41
				key = "button-label", -- 41
				ref = props.labelRef, -- 41
				fontName = "sarasa-mono-sc-regular", -- 41
				fontSize = 20, -- 41
				text = (props.title .. ": ") .. tostring(props.count), -- 41
				color3 = 16777215 -- 41
			} -- 41
		) -- 41
	) -- 41
end -- 39
root:render(function() return React.createElement( -- 65
	"node", -- 65
	nil, -- 65
	React.createElement("label", { -- 65
		key = "label", -- 65
		ref = labelRef, -- 65
		fontName = "sarasa-mono-sc-regular", -- 65
		fontSize = 20, -- 65
		text = "one", -- 65
		x = 10 -- 65
	}), -- 65
	React.createElement("node", {key = "first", ref = firstNodeRef, x = 1}), -- 65
	React.createElement("node", {key = "second", ref = secondNodeRef, x = 2}), -- 65
	React.createElement( -- 65
		"draw-node", -- 65
		{key = "shape", ref = drawRef}, -- 65
		React.createElement("rect-shape", {width = 24, height = 16, fillColor = 4294967295}) -- 65
	), -- 65
	React.createElement( -- 65
		TestButton, -- 73
		{ -- 73
			title = "Clicks", -- 73
			count = buttonClicks.value, -- 73
			ref = buttonRef, -- 73
			labelRef = buttonLabelRef, -- 73
			onClick = function() -- 73
				buttonClicks.value = buttonClicks.value + 1 -- 79
			end -- 78
		} -- 78
	) -- 78
) end) -- 78
local firstLabel = labelRef.current -- 85
local firstNode = firstNodeRef.current -- 86
local secondNode = secondNodeRef.current -- 87
expect(firstLabel ~= nil, "label was not mounted") -- 88
expect(firstNode ~= nil, "first node was not mounted") -- 89
expect(secondNode ~= nil, "second node was not mounted") -- 90
expect(drawRef.current ~= nil, "draw-node was not mounted") -- 91
expect(buttonRef.current ~= nil, "button was not mounted") -- 92
expect(buttonLabelRef.current ~= nil, "button label was not mounted") -- 93
expect(buttonRef.current.touchEnabled, "button touch was not enabled") -- 94
expect(buttonLabelRef.current.text == "Clicks: 0", "initial button label text was not rendered") -- 95
expect(firstLabel.text == "one", "initial label text was not applied") -- 96
expect(firstLabel.x == 10, "initial label x was not applied") -- 97
local firstButton = buttonRef.current -- 99
buttonRef.current:emit("Tapped") -- 100
Director.systemScheduler:schedule(once(function() -- 102
	expect(buttonRef.current ~= firstButton, "button event update should recreate event-bound node") -- 103
	expect(buttonLabelRef.current ~= nil, "button label was not remounted") -- 104
	expect(buttonLabelRef.current.text == "Clicks: 1", "button click did not update label text") -- 105
	root:render(React.createElement( -- 107
		"node", -- 107
		nil, -- 107
		React.createElement("label", { -- 107
			key = "label", -- 107
			ref = labelRef, -- 107
			fontName = "sarasa-mono-sc-regular", -- 107
			fontSize = 20, -- 107
			text = "two", -- 107
			x = 30 -- 107
		}), -- 107
		React.createElement("node", {key = "second", ref = keyedBRef, x = 20}), -- 107
		React.createElement("node", {key = "first", ref = keyedARef, x = 10}) -- 107
	)) -- 107
	expect(labelRef.current == firstLabel, "same keyed label should be reused") -- 115
	expect(labelRef.current.text == "two", "label text was not patched") -- 116
	expect(labelRef.current.x == 30, "label x was not patched") -- 117
	expect(keyedBRef.current == secondNode, "keyed second node should be reused after reorder") -- 118
	expect(keyedARef.current == firstNode, "keyed first node should be reused after reorder") -- 119
	expect(keyedBRef.current.x == 20, "reordered second node x was not patched") -- 120
	expect(keyedARef.current.x == 10, "reordered first node x was not patched") -- 121
	root:render(function() return React.createElement( -- 123
		"node", -- 123
		nil, -- 123
		React.createElement("label", {key = "signal-label", ref = labelRef, fontName = "sarasa-mono-sc-regular", fontSize = 20}, value.value) -- 123
	) end) -- 123
	local signalLabel = labelRef.current -- 129
	expect(signalLabel ~= nil, "signal label was not mounted") -- 130
	expect(signalLabel ~= firstLabel, "label with a different key should be recreated") -- 131
	expect(signalLabel.text == "1", "initial signal label text was not rendered") -- 132
	value.value = 7 -- 134
	Director.systemScheduler:schedule(once(function() -- 136
		expect(labelRef.current == signalLabel, "signal update should reuse label node") -- 137
		expect(labelRef.current.text == "7", "signal update did not patch label text") -- 138
		root:unmount() -- 139
		expect(not host.hasChildren, "root unmount did not remove rendered children") -- 140
		host:removeFromParent(true) -- 141
		Content:save(resultFile, "passed") -- 142
		Log("Info", "[DoraXDynamicRenderTest] passed") -- 143
	end)) -- 136
end)) -- 102
return ____exports -- 102