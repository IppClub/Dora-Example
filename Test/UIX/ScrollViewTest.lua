-- [tsx]: ScrollViewTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local Vec2 = ____Dora.Vec2 -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local Column = ____UIX.Column -- 4
local ScrollView = ____UIX.ScrollView -- 4
local Text = ____UIX.Text -- 4
local resultFile = Path(Content.writablePath, "UIXScrollViewTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXScrollViewTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local scrollRef = reference() -- 21
local offset = signal(0) -- 22
local rerenderTick = signal(0) -- 23
local scrollHeight = 64 -- 24
local contentHeight = 168 -- 25
local function expectedContentY(value) -- 27
	return value + scrollHeight - contentHeight / 2 -- 28
end -- 27
local function getContentNode() -- 31
	local menu = scrollRef.current.children:get(1) -- 32
	return menu.children:get(1) -- 33
end -- 31
root:render(function() return React.createElement( -- 36
	"align-node", -- 36
	{windowRoot = true, style = {padding = 8}}, -- 36
	React.createElement( -- 36
		Text, -- 38
		{ -- 38
			text = "Tick " .. tostring(rerenderTick.value), -- 38
			style = {width = 100, height = 24} -- 38
		} -- 38
	), -- 38
	React.createElement( -- 38
		ScrollView, -- 39
		{ -- 39
			ref = scrollRef, -- 39
			width = 160, -- 39
			height = scrollHeight, -- 39
			contentHeight = contentHeight, -- 39
			wheelSpeed = 20, -- 39
			onScroll = function(value) -- 39
				local ____value_0 = value -- 45
				offset.value = ____value_0 -- 45
				return ____value_0 -- 45
			end -- 45
		}, -- 45
		React.createElement( -- 45
			Column, -- 47
			{style = {gap = 4, width = 160}}, -- 47
			React.createElement(Text, {text = "Row A", style = {width = 150, height = 28}}), -- 47
			React.createElement(Text, {text = "Row B", style = {width = 150, height = 28}}), -- 47
			React.createElement(Text, {text = "Row C", style = {width = 150, height = 28}}), -- 47
			React.createElement(Text, {text = "Row D", style = {width = 150, height = 28}}), -- 47
			React.createElement(Text, {text = "Row E", style = {width = 150, height = 28}}) -- 47
		) -- 47
	) -- 47
) end) -- 47
Director.systemScheduler:schedule(once(function() -- 58
	expect(scrollRef.current ~= nil, "scroll view did not mount") -- 59
	expect(scrollRef.current.children ~= nil and scrollRef.current.children.count == 3, "scroll content or input layers missing") -- 60
	expect(scrollRef.current.width == 160 and scrollRef.current.height == 64, "scroll view hit size was not synced") -- 61
	local originalScrollNode = scrollRef.current -- 62
	local contentNode = getContentNode() -- 63
	local inputOverlay = scrollRef.current.children:get(2) -- 64
	expect(inputOverlay.width == 160 and inputOverlay.height == 64, "scroll input overlay hit size was not synced") -- 65
	inputOverlay:emit( -- 66
		"MouseWheel", -- 66
		Vec2(0, 1) -- 66
	) -- 66
	Director.systemScheduler:schedule(once(function() -- 67
		expect(offset.value == 20, "mouse wheel did not update scroll offset") -- 68
		contentNode = getContentNode() -- 69
		expect( -- 70
			contentNode.y == expectedContentY(20), -- 70
			"scroll content y did not follow offset direction" -- 70
		) -- 70
		inputOverlay = scrollRef.current.children:get(2) -- 71
		inputOverlay:emit( -- 72
			"MouseWheel", -- 72
			Vec2(0, 100) -- 72
		) -- 72
		Director.systemScheduler:schedule(once(function() -- 73
			expect(offset.value == 104, "scroll offset did not clamp to max") -- 74
			local dragCapture = scrollRef.current.children:get(3) -- 75
			expect(dragCapture.width == 160 and dragCapture.height == 64, "scroll drag capture hit size was not synced") -- 76
			expect(dragCapture.swallowTouches == false, "scroll drag capture should not swallow button taps by default") -- 77
			local touch = { -- 78
				first = true, -- 78
				enabled = true, -- 78
				location = Vec2(40, 48), -- 78
				delta = Vec2(0, -30) -- 78
			} -- 78
			dragCapture:emit("TapFilter", touch) -- 79
			expect(touch.enabled == true, "drag touch was rejected inside scroll view") -- 80
			dragCapture:emit("TapMoved", touch) -- 81
			Director.systemScheduler:schedule(once(function() -- 82
				expect(offset.value == 74, "tap drag did not update scroll offset") -- 83
				contentNode = getContentNode() -- 84
				expect( -- 85
					contentNode.y == expectedContentY(74), -- 85
					"scroll content y did not follow tap drag" -- 85
				) -- 85
				rerenderTick.value = rerenderTick.value + 1 -- 86
				Director.systemScheduler:schedule(once(function() -- 87
					expect(scrollRef.current == originalScrollNode, "scroll view node was recreated by parent rerender") -- 88
					expect(offset.value == 74, "scroll offset changed after parent rerender") -- 89
					contentNode = getContentNode() -- 90
					expect( -- 91
						contentNode.y == expectedContentY(74), -- 91
						"scroll content y changed after parent rerender" -- 91
					) -- 91
					Content:save(resultFile, "passed") -- 92
					Log("Info", "[UIXScrollViewTest] passed") -- 93
					host:removeFromParent(true) -- 94
					root:unmount() -- 95
				end)) -- 87
			end)) -- 82
		end)) -- 73
	end)) -- 67
end)) -- 58
return ____exports -- 58