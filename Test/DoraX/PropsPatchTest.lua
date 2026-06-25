-- [tsx]: PropsPatchTest.tsx
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
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXPropsPatchTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXPropsPatchTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local function close(a, b) -- 16
	return math.abs(a - b) < 0.0001 -- 17
end -- 16
local host = DNode() -- 20
Director.entry:addChild(host) -- 21
local root = createRoot(host) -- 23
local nodeRef = useRef() -- 24
local targetRef = useRef() -- 25
local transformTargetRef = targetRef -- 26
local labelRef = useRef() -- 27
local eventRef = useRef() -- 28
root:render(React.createElement( -- 30
	"node", -- 30
	nil, -- 30
	React.createElement("node", {key = "target", ref = targetRef}), -- 30
	React.createElement("node", { -- 30
		key = "node", -- 30
		ref = nodeRef, -- 30
		x = 1, -- 30
		y = 2, -- 30
		scaleX = 1, -- 30
		scaleY = 1, -- 30
		angle = 0, -- 30
		anchorX = 0.1, -- 30
		anchorY = 0.2, -- 30
		opacity = 0.5, -- 30
		color3 = 16711680, -- 30
		width = 10, -- 30
		height = 20, -- 30
		tag = "initial", -- 30
		transformTarget = transformTargetRef -- 30
	}), -- 30
	React.createElement("label", { -- 30
		key = "label", -- 30
		ref = labelRef, -- 30
		fontName = "sarasa-mono-sc-regular", -- 30
		fontSize = 18, -- 30
		text = "small" -- 30
	}) -- 30
)) -- 30
local node = nodeRef.current -- 54
local label = labelRef.current -- 55
expect(node ~= nil, "node was not mounted") -- 56
expect(label ~= nil, "label was not mounted") -- 57
local initialOpacity = node.opacity -- 58
root:render(React.createElement( -- 60
	"node", -- 60
	nil, -- 60
	React.createElement("node", {key = "target", ref = targetRef}), -- 60
	React.createElement("node", { -- 60
		key = "node", -- 60
		ref = nodeRef, -- 60
		x = 11, -- 60
		y = 12, -- 60
		scaleX = 2, -- 60
		scaleY = 3, -- 60
		angle = 45, -- 60
		anchorX = 0.3, -- 60
		anchorY = 0.4, -- 60
		opacity = 0.75, -- 60
		color3 = 65280, -- 60
		width = 30, -- 60
		height = 40, -- 60
		tag = "patched", -- 60
		transformTarget = transformTargetRef -- 60
	}), -- 60
	React.createElement("label", { -- 60
		key = "label", -- 60
		ref = labelRef, -- 60
		fontName = "sarasa-mono-sc-regular", -- 60
		fontSize = 18, -- 60
		text = "patched" -- 60
	}) -- 60
)) -- 60
expect(nodeRef.current == node, "ordinary node should be reused while patching props") -- 84
expect(nodeRef.current.x == 11 and nodeRef.current.y == 12, "position props were not patched") -- 85
expect(nodeRef.current.scaleX == 2 and nodeRef.current.scaleY == 3, "scale props were not patched") -- 86
expect(nodeRef.current.angle == 45, "angle prop was not patched") -- 87
expect( -- 88
	close(nodeRef.current.anchor.x, 0.3) and close(nodeRef.current.anchor.y, 0.4), -- 88
	"anchor props were not patched" -- 88
) -- 88
expect(nodeRef.current.opacity ~= initialOpacity, "opacity prop was not patched") -- 89
expect(nodeRef.current.width == 30 and nodeRef.current.height == 40, "size props were not patched") -- 90
expect(nodeRef.current.tag == "patched", "tag prop was not patched") -- 91
expect(nodeRef.current.transformTarget == targetRef.current, "transformTarget ref was not patched") -- 92
expect(labelRef.current == label, "label should be reused when font construction props do not change") -- 93
expect(labelRef.current.text == "patched", "label text was not patched") -- 94
root:render(React.createElement( -- 96
	"node", -- 96
	nil, -- 96
	React.createElement("label", { -- 96
		key = "label", -- 96
		ref = labelRef, -- 96
		fontName = "sarasa-mono-sc-regular", -- 96
		fontSize = 30, -- 96
		text = "large" -- 96
	}) -- 96
)) -- 96
expect(labelRef.current ~= label, "label should be recreated when fontSize changes") -- 101
expect(labelRef.current.text == "large", "recreated label text was not applied") -- 102
local taps = 0 -- 104
local function firstHandler() -- 105
	taps = taps + 1 -- 106
end -- 105
local function secondHandler() -- 108
	taps = taps + 10 -- 109
end -- 108
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = firstHandler})) -- 112
local firstEventNode = eventRef.current -- 113
expect(firstEventNode ~= nil, "event node was not mounted") -- 114
firstEventNode:emit("Tapped") -- 115
expect(taps == 1, "first event handler was not called") -- 116
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = secondHandler})) -- 118
expect(eventRef.current == firstEventNode, "event handler change should patch node without recreation") -- 119
eventRef.current:emit("Tapped") -- 120
expect(taps == 11, "second event handler should replace first handler") -- 121
root:render(React.createElement("node", {key = "event", ref = eventRef})) -- 123
expect(eventRef.current == firstEventNode, "event handler removal should patch node without recreation") -- 124
eventRef.current:emit("Tapped") -- 125
expect(taps == 11, "removed event handler should clear slot callbacks") -- 126
Director.systemScheduler:schedule(once(function() -- 128
	root:unmount() -- 129
	host:removeFromParent(true) -- 130
	Content:save(resultFile, "passed") -- 131
	Log("Info", "[DoraXPropsPatchTest] passed") -- 132
end)) -- 128
return ____exports -- 128