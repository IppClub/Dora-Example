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
local reference = ____DoraX.reference -- 3
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
local nodeRef = reference() -- 24
local replacementRef = reference() -- 25
local targetRef = reference() -- 26
local transformTargetRef = targetRef -- 27
local labelRef = reference() -- 28
local eventRef = reference() -- 29
local updateRef = reference() -- 30
local inputRef = reference() -- 31
root:render(React.createElement( -- 33
	"node", -- 33
	nil, -- 33
	React.createElement("node", {key = "target", ref = targetRef}), -- 33
	React.createElement("node", { -- 33
		key = "node", -- 33
		ref = nodeRef, -- 33
		x = 1, -- 33
		y = 2, -- 33
		scaleX = 1, -- 33
		scaleY = 1, -- 33
		angle = 0, -- 33
		anchorX = 0.1, -- 33
		anchorY = 0.2, -- 33
		opacity = 0.5, -- 33
		color3 = 16711680, -- 33
		width = 10, -- 33
		height = 20, -- 33
		tag = "initial", -- 33
		transformTarget = transformTargetRef -- 33
	}), -- 33
	React.createElement("label", { -- 33
		key = "label", -- 33
		ref = labelRef, -- 33
		fontName = "sarasa-mono-sc-regular", -- 33
		fontSize = 18, -- 33
		text = "small" -- 33
	}) -- 33
)) -- 33
local node = nodeRef.current -- 57
local label = labelRef.current -- 58
expect(node ~= nil, "node was not mounted") -- 59
expect(label ~= nil, "label was not mounted") -- 60
local initialOpacity = node.opacity -- 61
root:render(React.createElement( -- 63
	"node", -- 63
	nil, -- 63
	React.createElement("node", {key = "target", ref = targetRef}), -- 63
	React.createElement("node", { -- 63
		key = "node", -- 63
		ref = nodeRef, -- 63
		x = 11, -- 63
		y = 12, -- 63
		scaleX = 2, -- 63
		scaleY = 3, -- 63
		angle = 45, -- 63
		anchorX = 0.3, -- 63
		anchorY = 0.4, -- 63
		opacity = 0.75, -- 63
		color3 = 65280, -- 63
		width = 30, -- 63
		height = 40, -- 63
		tag = "patched", -- 63
		transformTarget = transformTargetRef -- 63
	}), -- 63
	React.createElement("label", { -- 63
		key = "label", -- 63
		ref = labelRef, -- 63
		fontName = "sarasa-mono-sc-regular", -- 63
		fontSize = 18, -- 63
		text = "patched" -- 63
	}) -- 63
)) -- 63
expect(nodeRef.current == node, "ordinary node should be reused while patching props") -- 87
expect(nodeRef.current.x == 11 and nodeRef.current.y == 12, "position props were not patched") -- 88
expect(nodeRef.current.scaleX == 2 and nodeRef.current.scaleY == 3, "scale props were not patched") -- 89
expect(nodeRef.current.angle == 45, "angle prop was not patched") -- 90
expect( -- 91
	close(nodeRef.current.anchor.x, 0.3) and close(nodeRef.current.anchor.y, 0.4), -- 91
	"anchor props were not patched" -- 91
) -- 91
expect(nodeRef.current.opacity ~= initialOpacity, "opacity prop was not patched") -- 92
expect(nodeRef.current.width == 30 and nodeRef.current.height == 40, "size props were not patched") -- 93
expect(nodeRef.current.tag == "patched", "tag prop was not patched") -- 94
expect(nodeRef.current.transformTarget == targetRef.current, "transformTarget ref was not patched") -- 95
expect(labelRef.current == label, "label should be reused when font construction props do not change") -- 96
expect(labelRef.current.text == "patched", "label text was not patched") -- 97
root:render(React.createElement( -- 99
	"node", -- 99
	nil, -- 99
	React.createElement("node", {key = "target", ref = targetRef}), -- 99
	React.createElement("node", { -- 99
		key = "node", -- 99
		ref = replacementRef, -- 99
		x = 11, -- 99
		y = 12, -- 99
		scaleX = 2, -- 99
		scaleY = 3, -- 99
		angle = 45, -- 99
		anchorX = 0.3, -- 99
		anchorY = 0.4, -- 99
		opacity = 0.75, -- 99
		color3 = 65280, -- 99
		width = 30, -- 99
		height = 40, -- 99
		tag = "patched", -- 99
		transformTarget = transformTargetRef -- 99
	}), -- 99
	React.createElement("label", { -- 99
		key = "label", -- 99
		ref = labelRef, -- 99
		fontName = "sarasa-mono-sc-regular", -- 99
		fontSize = 18, -- 99
		text = "patched" -- 99
	}) -- 99
)) -- 99
expect(nodeRef.current == nil, "old ref should clear when ref changes") -- 122
expect(replacementRef.current == node, "new ref should point to reused node") -- 123
root:render(React.createElement( -- 125
	"node", -- 125
	nil, -- 125
	React.createElement("node", {key = "target", ref = targetRef}), -- 125
	React.createElement("node", { -- 125
		key = "node", -- 125
		x = 11, -- 125
		y = 12, -- 125
		scaleX = 2, -- 125
		scaleY = 3, -- 125
		angle = 45, -- 125
		anchorX = 0.3, -- 125
		anchorY = 0.4, -- 125
		opacity = 0.75, -- 125
		color3 = 65280, -- 125
		width = 30, -- 125
		height = 40, -- 125
		tag = "patched", -- 125
		transformTarget = transformTargetRef -- 125
	}), -- 125
	React.createElement("label", { -- 125
		key = "label", -- 125
		ref = labelRef, -- 125
		fontName = "sarasa-mono-sc-regular", -- 125
		fontSize = 18, -- 125
		text = "patched" -- 125
	}) -- 125
)) -- 125
expect(replacementRef.current == nil, "removed ref should clear old ref") -- 147
root:render(React.createElement( -- 149
	"node", -- 149
	nil, -- 149
	React.createElement("node", {key = "target", ref = targetRef}), -- 149
	React.createElement("node", { -- 149
		key = "node", -- 149
		ref = nodeRef, -- 149
		x = 11, -- 149
		y = 12, -- 149
		scaleX = 2, -- 149
		scaleY = 3, -- 149
		angle = 45, -- 149
		anchorX = 0.3, -- 149
		anchorY = 0.4, -- 149
		opacity = 0.75, -- 149
		color3 = 65280, -- 149
		width = 30, -- 149
		height = 40, -- 149
		tag = "patched", -- 149
		transformTarget = transformTargetRef -- 149
	}), -- 149
	React.createElement("label", { -- 149
		key = "label", -- 149
		ref = labelRef, -- 149
		fontName = "sarasa-mono-sc-regular", -- 149
		fontSize = 18, -- 149
		text = "patched" -- 149
	}) -- 149
)) -- 149
expect(nodeRef.current == node, "ref should bind again after being removed") -- 172
root:render(React.createElement( -- 174
	"node", -- 174
	nil, -- 174
	React.createElement("node", {key = "target", ref = targetRef}), -- 174
	React.createElement("node", { -- 174
		key = "node", -- 174
		ref = nodeRef, -- 174
		x = 11, -- 174
		y = 12, -- 174
		scaleX = 2, -- 174
		scaleY = 3, -- 174
		angle = 45, -- 174
		opacity = 0.75, -- 174
		color3 = 65280, -- 174
		width = 30, -- 174
		height = 40, -- 174
		tag = "patched" -- 174
	}), -- 174
	React.createElement("label", { -- 174
		key = "label", -- 174
		ref = labelRef, -- 174
		fontName = "sarasa-mono-sc-regular", -- 174
		fontSize = 18, -- 174
		text = "smooth", -- 174
		smoothLower = 0.2, -- 174
		smoothUpper = 0.8 -- 174
	}) -- 174
)) -- 174
expect( -- 203
	close(nodeRef.current.anchor.x, 0.3) and close(nodeRef.current.anchor.y, 0.4), -- 203
	"removed anchor props should keep previous values" -- 203
) -- 203
expect(nodeRef.current.transformTarget == nil, "removed transformTarget should clear to undefined") -- 204
expect(labelRef.current == label, "label should still be reused when smooth props change") -- 205
expect( -- 206
	close(labelRef.current.smooth.x, 0.2) and close(labelRef.current.smooth.y, 0.8), -- 206
	"smooth props were not patched" -- 206
) -- 206
root:render(React.createElement( -- 208
	"node", -- 208
	nil, -- 208
	React.createElement("node", {key = "target", ref = targetRef}), -- 208
	React.createElement("node", { -- 208
		key = "node", -- 208
		ref = nodeRef, -- 208
		x = 11, -- 208
		y = 12, -- 208
		scaleX = 2, -- 208
		scaleY = 3, -- 208
		angle = 45, -- 208
		opacity = 0.75, -- 208
		color3 = 65280, -- 208
		width = 30, -- 208
		height = 40, -- 208
		tag = "patched", -- 208
		transformTarget = transformTargetRef -- 208
	}), -- 208
	React.createElement("label", { -- 208
		key = "label", -- 208
		ref = labelRef, -- 208
		fontName = "sarasa-mono-sc-regular", -- 208
		fontSize = 18, -- 208
		text = "default-smooth" -- 208
	}) -- 208
)) -- 208
expect( -- 230
	close(labelRef.current.smooth.x, 0.2) and close(labelRef.current.smooth.y, 0.8), -- 230
	"removed smooth props should keep previous values" -- 230
) -- 230
root:render(React.createElement( -- 232
	"node", -- 232
	nil, -- 232
	React.createElement("label", { -- 232
		key = "label", -- 232
		ref = labelRef, -- 232
		fontName = "sarasa-mono-sc-regular", -- 232
		fontSize = 30, -- 232
		text = "large" -- 232
	}) -- 232
)) -- 232
expect(labelRef.current ~= label, "label should be recreated when fontSize changes") -- 237
expect(labelRef.current.text == "large", "recreated label text was not applied") -- 238
local taps = 0 -- 240
local function firstHandler() -- 241
	taps = taps + 1 -- 242
end -- 241
local function secondHandler() -- 244
	taps = taps + 10 -- 245
end -- 244
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = firstHandler})) -- 248
local firstEventNode = eventRef.current -- 249
expect(firstEventNode ~= nil, "event node was not mounted") -- 250
firstEventNode:emit("Tapped") -- 251
expect(taps == 1, "first event handler was not called") -- 252
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = secondHandler})) -- 254
expect(eventRef.current == firstEventNode, "event handler change should patch node without recreation") -- 255
eventRef.current:emit("Tapped") -- 256
expect(taps == 11, "second event handler should replace first handler") -- 257
root:render(React.createElement("node", {key = "event", ref = eventRef})) -- 259
expect(eventRef.current == firstEventNode, "event handler removal should patch node without recreation") -- 260
eventRef.current:emit("Tapped") -- 261
expect(taps == 11, "removed event handler should clear slot callbacks") -- 262
root:render(React.createElement( -- 264
	"node", -- 264
	{ -- 264
		key = "update", -- 264
		ref = updateRef, -- 264
		onUpdate = function() return false end -- 264
	} -- 264
)) -- 264
local firstUpdateNode = updateRef.current -- 265
expect(firstUpdateNode ~= nil, "update node was not mounted") -- 266
root:render(React.createElement( -- 268
	"node", -- 268
	{ -- 268
		key = "update", -- 268
		ref = updateRef, -- 268
		onUpdate = function() return true end -- 268
	} -- 268
)) -- 268
expect(updateRef.current == firstUpdateNode, "onUpdate change should patch node without recreation") -- 269
root:render(React.createElement("node", {key = "update", ref = updateRef})) -- 271
expect(updateRef.current == firstUpdateNode, "onUpdate removal should patch node without recreation") -- 272
root:render(React.createElement("node", {key = "input", ref = inputRef})) -- 274
local inputNode = inputRef.current -- 275
expect(inputNode ~= nil, "input node was not mounted") -- 276
expect(not inputNode.touchEnabled, "input node should start without touch enabled") -- 277
expect(not inputNode.keyboardEnabled, "input node should start without keyboard enabled") -- 278
expect(not inputNode.controllerEnabled, "input node should start without controller enabled") -- 279
root:render(React.createElement( -- 281
	"node", -- 281
	{ -- 281
		key = "input", -- 281
		ref = inputRef, -- 281
		onTapped = function() -- 281
		end -- 281
	} -- 281
)) -- 281
expect(inputRef.current == inputNode, "adding tap event should patch input node") -- 282
expect(inputNode.touchEnabled, "adding tap event should auto-enable touch") -- 283
root:render(React.createElement( -- 285
	"node", -- 285
	{ -- 285
		key = "input", -- 285
		ref = inputRef, -- 285
		onKeyDown = function() -- 285
		end -- 285
	} -- 285
)) -- 285
expect(inputRef.current == inputNode, "adding key event should patch input node") -- 286
expect(inputNode.keyboardEnabled, "adding key event should auto-enable keyboard") -- 287
root:render(React.createElement( -- 289
	"node", -- 289
	{ -- 289
		key = "input", -- 289
		ref = inputRef, -- 289
		onButtonDown = function() -- 289
		end -- 289
	} -- 289
)) -- 289
expect(inputRef.current == inputNode, "adding controller event should patch input node") -- 290
expect(inputNode.controllerEnabled, "adding controller event should auto-enable controller") -- 291
Director.systemScheduler:schedule(once(function() -- 293
	root:unmount() -- 294
	host:removeFromParent(true) -- 295
	Content:save(resultFile, "passed") -- 296
	Log("Info", "[DoraXPropsPatchTest] passed") -- 297
end)) -- 293
return ____exports -- 293