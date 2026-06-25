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
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local resultFile = Path(Content.writablePath, "DoraXDynamicRenderTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXDynamicRenderTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local host = DNode() -- 17
Director.entry:addChild(host) -- 18
local root = createRoot(host) -- 20
local labelRef = reference() -- 21
local firstNodeRef = reference() -- 22
local secondNodeRef = reference() -- 23
local keyedBRef = reference() -- 24
local keyedARef = reference() -- 25
local drawRef = reference() -- 26
local buttonRef = reference() -- 27
local buttonLabelRef = reference() -- 28
local value = signal(1) -- 29
local buttonClicks = signal(0) -- 30
local function TestButton(props) -- 40
	local fillColor = props.count > 0 and 3003583 or 3900150 -- 41
	return React.createElement( -- 42
		"node", -- 42
		{ -- 42
			key = "button", -- 42
			ref = props.ref, -- 42
			width = 160, -- 42
			height = 54, -- 42
			touchEnabled = true, -- 42
			onTapped = props.onClick -- 42
		}, -- 42
		React.createElement( -- 42
			"draw-node", -- 42
			nil, -- 42
			React.createElement("rect-shape", { -- 42
				width = 160, -- 42
				height = 54, -- 42
				fillColor = fillColor, -- 42
				borderWidth = 2, -- 42
				borderColor = 4294967295 -- 42
			}) -- 42
		), -- 42
		React.createElement( -- 42
			"label", -- 42
			{ -- 42
				key = "button-label", -- 42
				ref = props.labelRef, -- 42
				fontName = "sarasa-mono-sc-regular", -- 42
				fontSize = 20, -- 42
				text = (props.title .. ": ") .. tostring(props.count), -- 42
				color3 = 16777215 -- 42
			} -- 42
		) -- 42
	) -- 42
end -- 40
root:render(function() return React.createElement( -- 66
	"node", -- 66
	nil, -- 66
	React.createElement("label", { -- 66
		key = "label", -- 66
		ref = labelRef, -- 66
		fontName = "sarasa-mono-sc-regular", -- 66
		fontSize = 20, -- 66
		text = "one", -- 66
		x = 10 -- 66
	}), -- 66
	React.createElement("node", {key = "first", ref = firstNodeRef, x = 1}), -- 66
	React.createElement("node", {key = "second", ref = secondNodeRef, x = 2}), -- 66
	React.createElement( -- 66
		"draw-node", -- 66
		{key = "shape", ref = drawRef}, -- 66
		React.createElement("rect-shape", {width = 24, height = 16, fillColor = 4294967295}) -- 66
	), -- 66
	React.createElement( -- 66
		TestButton, -- 74
		{ -- 74
			title = "Clicks", -- 74
			count = buttonClicks.value, -- 74
			ref = buttonRef, -- 74
			labelRef = buttonLabelRef, -- 74
			onClick = function() -- 74
				buttonClicks.value = buttonClicks.value + 1 -- 80
			end -- 79
		} -- 79
	) -- 79
) end) -- 79
local firstLabel = labelRef.current -- 86
local firstNode = firstNodeRef.current -- 87
local secondNode = secondNodeRef.current -- 88
expect(firstLabel ~= nil, "label was not mounted") -- 89
expect(firstNode ~= nil, "first node was not mounted") -- 90
expect(secondNode ~= nil, "second node was not mounted") -- 91
expect(drawRef.current ~= nil, "draw-node was not mounted") -- 92
expect(buttonRef.current ~= nil, "button was not mounted") -- 93
expect(buttonLabelRef.current ~= nil, "button label was not mounted") -- 94
expect(buttonRef.current.touchEnabled, "button touch was not enabled") -- 95
expect(buttonLabelRef.current.text == "Clicks: 0", "initial button label text was not rendered") -- 96
expect(firstLabel.text == "one", "initial label text was not applied") -- 97
expect(firstLabel.x == 10, "initial label x was not applied") -- 98
local firstButton = buttonRef.current -- 100
buttonRef.current:emit("Tapped") -- 101
Director.systemScheduler:schedule(once(function() -- 103
	expect(buttonRef.current == firstButton, "button event update should patch event-bound node") -- 104
	expect(buttonLabelRef.current ~= nil, "button label was not remounted") -- 105
	expect(buttonLabelRef.current.text == "Clicks: 1", "button click did not update label text") -- 106
	root:render(React.createElement( -- 108
		"node", -- 108
		nil, -- 108
		React.createElement("label", { -- 108
			key = "label", -- 108
			ref = labelRef, -- 108
			fontName = "sarasa-mono-sc-regular", -- 108
			fontSize = 20, -- 108
			text = "two", -- 108
			x = 30 -- 108
		}), -- 108
		React.createElement("node", {key = "second", ref = keyedBRef, x = 20}), -- 108
		React.createElement("node", {key = "first", ref = keyedARef, x = 10}) -- 108
	)) -- 108
	expect(labelRef.current == firstLabel, "same keyed label should be reused") -- 116
	expect(labelRef.current.text == "two", "label text was not patched") -- 117
	expect(labelRef.current.x == 30, "label x was not patched") -- 118
	expect(keyedBRef.current == secondNode, "keyed second node should be reused after reorder") -- 119
	expect(keyedARef.current == firstNode, "keyed first node should be reused after reorder") -- 120
	expect(keyedBRef.current.x == 20, "reordered second node x was not patched") -- 121
	expect(keyedARef.current.x == 10, "reordered first node x was not patched") -- 122
	root:render(function() return React.createElement( -- 124
		"node", -- 124
		nil, -- 124
		React.createElement("label", {key = "signal-label", ref = labelRef, fontName = "sarasa-mono-sc-regular", fontSize = 20}, value.value) -- 124
	) end) -- 124
	local signalLabel = labelRef.current -- 130
	expect(signalLabel ~= nil, "signal label was not mounted") -- 131
	expect(signalLabel ~= firstLabel, "label with a different key should be recreated") -- 132
	expect(signalLabel.text == "1", "initial signal label text was not rendered") -- 133
	value.value = 7 -- 135
	Director.systemScheduler:schedule(once(function() -- 137
		expect(labelRef.current == signalLabel, "signal update should reuse label node") -- 138
		expect(labelRef.current.text == "7", "signal update did not patch label text") -- 139
		root:unmount() -- 140
		expect(not host.hasChildren, "root unmount did not remove rendered children") -- 141
		host:removeFromParent(true) -- 142
		Content:save(resultFile, "passed") -- 143
		Log("Info", "[DoraXDynamicRenderTest] passed") -- 144
	end)) -- 137
end)) -- 103
return ____exports -- 103