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
local renderHost = DNode() -- 21
Director.entry:addChild(host) -- 22
Director.entry:addChild(renderHost) -- 23
local root = createRoot(host) -- 25
local renderRoot = createRoot(renderHost) -- 26
local nodeRef = reference() -- 27
local replacementRef = reference() -- 28
local targetRef = reference() -- 29
local transformTargetRef = targetRef -- 30
local labelRef = reference() -- 31
local eventRef = reference() -- 32
local updateRef = reference() -- 33
local renderRef = reference() -- 34
local inputRef = reference() -- 35
root:render(React.createElement( -- 37
	"node", -- 37
	nil, -- 37
	React.createElement("node", {key = "target", ref = targetRef}), -- 37
	React.createElement("node", { -- 37
		key = "node", -- 37
		ref = nodeRef, -- 37
		x = 1, -- 37
		y = 2, -- 37
		scaleX = 1, -- 37
		scaleY = 1, -- 37
		angle = 0, -- 37
		anchorX = 0.1, -- 37
		anchorY = 0.2, -- 37
		opacity = 0.5, -- 37
		color3 = 16711680, -- 37
		width = 10, -- 37
		height = 20, -- 37
		tag = "initial", -- 37
		transformTarget = transformTargetRef -- 37
	}), -- 37
	React.createElement("label", { -- 37
		key = "label", -- 37
		ref = labelRef, -- 37
		fontName = "sarasa-mono-sc-regular", -- 37
		fontSize = 18, -- 37
		text = "small" -- 37
	}) -- 37
)) -- 37
local node = nodeRef.current -- 61
local label = labelRef.current -- 62
expect(node ~= nil, "node was not mounted") -- 63
expect(label ~= nil, "label was not mounted") -- 64
local initialOpacity = node.opacity -- 65
root:render(React.createElement( -- 67
	"node", -- 67
	nil, -- 67
	React.createElement("node", {key = "target", ref = targetRef}), -- 67
	React.createElement("node", { -- 67
		key = "node", -- 67
		ref = nodeRef, -- 67
		x = 11, -- 67
		y = 12, -- 67
		scaleX = 2, -- 67
		scaleY = 3, -- 67
		angle = 45, -- 67
		anchorX = 0.3, -- 67
		anchorY = 0.4, -- 67
		opacity = 0.75, -- 67
		color3 = 65280, -- 67
		width = 30, -- 67
		height = 40, -- 67
		tag = "patched", -- 67
		transformTarget = transformTargetRef -- 67
	}), -- 67
	React.createElement("label", { -- 67
		key = "label", -- 67
		ref = labelRef, -- 67
		fontName = "sarasa-mono-sc-regular", -- 67
		fontSize = 18, -- 67
		text = "patched" -- 67
	}) -- 67
)) -- 67
expect(nodeRef.current == node, "ordinary node should be reused while patching props") -- 91
expect(nodeRef.current.x == 11 and nodeRef.current.y == 12, "position props were not patched") -- 92
expect(nodeRef.current.scaleX == 2 and nodeRef.current.scaleY == 3, "scale props were not patched") -- 93
expect(nodeRef.current.angle == 45, "angle prop was not patched") -- 94
expect( -- 95
	close(nodeRef.current.anchor.x, 0.3) and close(nodeRef.current.anchor.y, 0.4), -- 95
	"anchor props were not patched" -- 95
) -- 95
expect(nodeRef.current.opacity ~= initialOpacity, "opacity prop was not patched") -- 96
expect(nodeRef.current.width == 30 and nodeRef.current.height == 40, "size props were not patched") -- 97
expect(nodeRef.current.tag == "patched", "tag prop was not patched") -- 98
expect(nodeRef.current.transformTarget == targetRef.current, "transformTarget ref was not patched") -- 99
expect(labelRef.current == label, "label should be reused when font construction props do not change") -- 100
expect(labelRef.current.text == "patched", "label text was not patched") -- 101
root:render(React.createElement( -- 103
	"node", -- 103
	nil, -- 103
	React.createElement("node", {key = "target", ref = targetRef}), -- 103
	React.createElement("node", { -- 103
		key = "node", -- 103
		ref = replacementRef, -- 103
		x = 11, -- 103
		y = 12, -- 103
		scaleX = 2, -- 103
		scaleY = 3, -- 103
		angle = 45, -- 103
		anchorX = 0.3, -- 103
		anchorY = 0.4, -- 103
		opacity = 0.75, -- 103
		color3 = 65280, -- 103
		width = 30, -- 103
		height = 40, -- 103
		tag = "patched", -- 103
		transformTarget = transformTargetRef -- 103
	}), -- 103
	React.createElement("label", { -- 103
		key = "label", -- 103
		ref = labelRef, -- 103
		fontName = "sarasa-mono-sc-regular", -- 103
		fontSize = 18, -- 103
		text = "patched" -- 103
	}) -- 103
)) -- 103
expect(nodeRef.current == nil, "old ref should clear when ref changes") -- 126
expect(replacementRef.current == node, "new ref should point to reused node") -- 127
root:render(React.createElement( -- 129
	"node", -- 129
	nil, -- 129
	React.createElement("node", {key = "target", ref = targetRef}), -- 129
	React.createElement("node", { -- 129
		key = "node", -- 129
		x = 11, -- 129
		y = 12, -- 129
		scaleX = 2, -- 129
		scaleY = 3, -- 129
		angle = 45, -- 129
		anchorX = 0.3, -- 129
		anchorY = 0.4, -- 129
		opacity = 0.75, -- 129
		color3 = 65280, -- 129
		width = 30, -- 129
		height = 40, -- 129
		tag = "patched", -- 129
		transformTarget = transformTargetRef -- 129
	}), -- 129
	React.createElement("label", { -- 129
		key = "label", -- 129
		ref = labelRef, -- 129
		fontName = "sarasa-mono-sc-regular", -- 129
		fontSize = 18, -- 129
		text = "patched" -- 129
	}) -- 129
)) -- 129
expect(replacementRef.current == nil, "removed ref should clear old ref") -- 151
root:render(React.createElement( -- 153
	"node", -- 153
	nil, -- 153
	React.createElement("node", {key = "target", ref = targetRef}), -- 153
	React.createElement("node", { -- 153
		key = "node", -- 153
		ref = nodeRef, -- 153
		x = 11, -- 153
		y = 12, -- 153
		scaleX = 2, -- 153
		scaleY = 3, -- 153
		angle = 45, -- 153
		anchorX = 0.3, -- 153
		anchorY = 0.4, -- 153
		opacity = 0.75, -- 153
		color3 = 65280, -- 153
		width = 30, -- 153
		height = 40, -- 153
		tag = "patched", -- 153
		transformTarget = transformTargetRef -- 153
	}), -- 153
	React.createElement("label", { -- 153
		key = "label", -- 153
		ref = labelRef, -- 153
		fontName = "sarasa-mono-sc-regular", -- 153
		fontSize = 18, -- 153
		text = "patched" -- 153
	}) -- 153
)) -- 153
expect(nodeRef.current == node, "ref should bind again after being removed") -- 176
root:render(React.createElement( -- 178
	"node", -- 178
	nil, -- 178
	React.createElement("node", {key = "target", ref = targetRef}), -- 178
	React.createElement("node", { -- 178
		key = "node", -- 178
		ref = nodeRef, -- 178
		x = 11, -- 178
		y = 12, -- 178
		scaleX = 2, -- 178
		scaleY = 3, -- 178
		angle = 45, -- 178
		opacity = 0.75, -- 178
		color3 = 65280, -- 178
		width = 30, -- 178
		height = 40, -- 178
		tag = "patched" -- 178
	}), -- 178
	React.createElement("label", { -- 178
		key = "label", -- 178
		ref = labelRef, -- 178
		fontName = "sarasa-mono-sc-regular", -- 178
		fontSize = 18, -- 178
		text = "smooth", -- 178
		smoothLower = 0.2, -- 178
		smoothUpper = 0.8 -- 178
	}) -- 178
)) -- 178
expect( -- 207
	close(nodeRef.current.anchor.x, 0.3) and close(nodeRef.current.anchor.y, 0.4), -- 207
	"removed anchor props should keep previous values" -- 207
) -- 207
expect(nodeRef.current.transformTarget == nil, "removed transformTarget should clear to undefined") -- 208
expect(labelRef.current == label, "label should still be reused when smooth props change") -- 209
expect( -- 210
	close(labelRef.current.smooth.x, 0.2) and close(labelRef.current.smooth.y, 0.8), -- 210
	"smooth props were not patched" -- 210
) -- 210
root:render(React.createElement( -- 212
	"node", -- 212
	nil, -- 212
	React.createElement("node", {key = "target", ref = targetRef}), -- 212
	React.createElement("node", { -- 212
		key = "node", -- 212
		ref = nodeRef, -- 212
		x = 11, -- 212
		y = 12, -- 212
		scaleX = 2, -- 212
		scaleY = 3, -- 212
		angle = 45, -- 212
		opacity = 0.75, -- 212
		color3 = 65280, -- 212
		width = 30, -- 212
		height = 40, -- 212
		tag = "patched", -- 212
		transformTarget = transformTargetRef -- 212
	}), -- 212
	React.createElement("label", { -- 212
		key = "label", -- 212
		ref = labelRef, -- 212
		fontName = "sarasa-mono-sc-regular", -- 212
		fontSize = 18, -- 212
		text = "default-smooth" -- 212
	}) -- 212
)) -- 212
expect( -- 234
	close(labelRef.current.smooth.x, 0.2) and close(labelRef.current.smooth.y, 0.8), -- 234
	"removed smooth props should keep previous values" -- 234
) -- 234
root:render(React.createElement( -- 236
	"node", -- 236
	nil, -- 236
	React.createElement("label", { -- 236
		key = "label", -- 236
		ref = labelRef, -- 236
		fontName = "sarasa-mono-sc-regular", -- 236
		fontSize = 30, -- 236
		text = "large" -- 236
	}) -- 236
)) -- 236
expect(labelRef.current ~= label, "label should be recreated when fontSize changes") -- 241
expect(labelRef.current.text == "large", "recreated label text was not applied") -- 242
local taps = 0 -- 244
local function firstHandler() -- 245
	taps = taps + 1 -- 246
end -- 245
local function secondHandler() -- 248
	taps = taps + 10 -- 249
end -- 248
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = firstHandler})) -- 252
local firstEventNode = eventRef.current -- 253
expect(firstEventNode ~= nil, "event node was not mounted") -- 254
firstEventNode:emit("Tapped") -- 255
expect(taps == 1, "first event handler was not called") -- 256
root:render(React.createElement("node", {key = "event", ref = eventRef, onTapped = secondHandler})) -- 258
expect(eventRef.current == firstEventNode, "event handler change should patch node without recreation") -- 259
eventRef.current:emit("Tapped") -- 260
expect(taps == 11, "second event handler should replace first handler") -- 261
root:render(React.createElement("node", {key = "event", ref = eventRef})) -- 263
expect(eventRef.current == firstEventNode, "event handler removal should patch node without recreation") -- 264
eventRef.current:emit("Tapped") -- 265
expect(taps == 11, "removed event handler should clear slot callbacks") -- 266
root:render(React.createElement( -- 268
	"node", -- 268
	{ -- 268
		key = "update", -- 268
		ref = updateRef, -- 268
		onUpdate = function() return false end -- 268
	} -- 268
)) -- 268
local firstUpdateNode = updateRef.current -- 269
expect(firstUpdateNode ~= nil, "update node was not mounted") -- 270
root:render(React.createElement( -- 272
	"node", -- 272
	{ -- 272
		key = "update", -- 272
		ref = updateRef, -- 272
		onUpdate = function() return true end -- 272
	} -- 272
)) -- 272
expect(updateRef.current == firstUpdateNode, "onUpdate change should patch node without recreation") -- 273
root:render(React.createElement("node", {key = "update", ref = updateRef})) -- 275
expect(updateRef.current == firstUpdateNode, "onUpdate removal should patch node without recreation") -- 276
local firstRenders = 0 -- 278
local secondRenders = 0 -- 279
renderRoot:render(React.createElement( -- 280
	"node", -- 280
	{ -- 280
		key = "render", -- 280
		ref = renderRef, -- 280
		onRender = function() -- 280
			firstRenders = firstRenders + 1 -- 281
			return false -- 282
		end -- 280
	} -- 280
)) -- 280
local firstRenderNode = renderRef.current -- 284
expect(firstRenderNode ~= nil, "render node was not mounted") -- 285
root:render(React.createElement("node", {key = "input", ref = inputRef})) -- 287
local inputNode = inputRef.current -- 288
expect(inputNode ~= nil, "input node was not mounted") -- 289
expect(not inputNode.touchEnabled, "input node should start without touch enabled") -- 290
expect(not inputNode.keyboardEnabled, "input node should start without keyboard enabled") -- 291
expect(not inputNode.controllerEnabled, "input node should start without controller enabled") -- 292
root:render(React.createElement( -- 294
	"node", -- 294
	{ -- 294
		key = "input", -- 294
		ref = inputRef, -- 294
		onTapped = function() -- 294
		end -- 294
	} -- 294
)) -- 294
expect(inputRef.current == inputNode, "adding tap event should patch input node") -- 295
expect(inputNode.touchEnabled, "adding tap event should auto-enable touch") -- 296
root:render(React.createElement( -- 298
	"node", -- 298
	{ -- 298
		key = "input", -- 298
		ref = inputRef, -- 298
		onKeyDown = function() -- 298
		end -- 298
	} -- 298
)) -- 298
expect(inputRef.current == inputNode, "adding key event should patch input node") -- 299
expect(inputNode.keyboardEnabled, "adding key event should auto-enable keyboard") -- 300
root:render(React.createElement( -- 302
	"node", -- 302
	{ -- 302
		key = "input", -- 302
		ref = inputRef, -- 302
		onButtonDown = function() -- 302
		end -- 302
	} -- 302
)) -- 302
expect(inputRef.current == inputNode, "adding controller event should patch input node") -- 303
expect(inputNode.controllerEnabled, "adding controller event should auto-enable controller") -- 304
Director.systemScheduler:schedule(once(function() -- 306
	expect(firstRenders > 0, "initial onRender handler was not called") -- 307
	local firstRendersBeforePatch = firstRenders -- 308
	renderRoot:render(React.createElement( -- 309
		"node", -- 309
		{ -- 309
			key = "render", -- 309
			ref = renderRef, -- 309
			onRender = function() -- 309
				secondRenders = secondRenders + 1 -- 310
				return false -- 311
			end -- 309
		} -- 309
	)) -- 309
	expect(renderRef.current == firstRenderNode, "onRender change should patch node without recreation") -- 313
	Director.systemScheduler:schedule(once(function() -- 315
		expect(firstRenders == firstRendersBeforePatch, "old onRender handler should stop after patch") -- 316
		expect(secondRenders > 0, "patched onRender handler was not called") -- 317
		local secondRendersBeforeRemoval = secondRenders -- 318
		renderRoot:render(React.createElement("node", {key = "render", ref = renderRef})) -- 319
		expect(renderRef.current == firstRenderNode, "onRender removal should patch node without recreation") -- 320
		Director.systemScheduler:schedule(once(function() -- 322
			expect(secondRenders == secondRendersBeforeRemoval, "removed onRender handler should stop running") -- 323
			root:unmount() -- 324
			renderRoot:unmount() -- 325
			host:removeFromParent(true) -- 326
			renderHost:removeFromParent(true) -- 327
			Content:save(resultFile, "passed") -- 328
			Log("Info", "[DoraXPropsPatchTest] passed") -- 329
		end)) -- 322
	end)) -- 315
end)) -- 306
return ____exports -- 306