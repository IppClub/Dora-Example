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
root:render(function() return React.createElement( -- 25
	"align-node", -- 25
	{windowRoot = true, style = {padding = 8}}, -- 25
	React.createElement( -- 25
		Text, -- 27
		{ -- 27
			text = "Tick " .. tostring(rerenderTick.value), -- 27
			style = {width = 100, height = 24} -- 27
		} -- 27
	), -- 27
	React.createElement( -- 27
		ScrollView, -- 28
		{ -- 28
			ref = scrollRef, -- 28
			width = 160, -- 28
			height = 64, -- 28
			contentHeight = 168, -- 28
			wheelSpeed = 20, -- 28
			onScroll = function(value) -- 28
				local ____value_0 = value -- 34
				offset.value = ____value_0 -- 34
				return ____value_0 -- 34
			end -- 34
		}, -- 34
		React.createElement( -- 34
			Column, -- 36
			{style = {gap = 4, width = 160}}, -- 36
			React.createElement(Text, {text = "Row A", style = {width = 150, height = 28}}), -- 36
			React.createElement(Text, {text = "Row B", style = {width = 150, height = 28}}), -- 36
			React.createElement(Text, {text = "Row C", style = {width = 150, height = 28}}), -- 36
			React.createElement(Text, {text = "Row D", style = {width = 150, height = 28}}), -- 36
			React.createElement(Text, {text = "Row E", style = {width = 150, height = 28}}) -- 36
		) -- 36
	) -- 36
) end) -- 36
Director.systemScheduler:schedule(once(function() -- 47
	expect(scrollRef.current ~= nil, "scroll view did not mount") -- 48
	expect(scrollRef.current.children ~= nil and scrollRef.current.children.count == 3, "scroll content or input layers missing") -- 49
	expect(scrollRef.current.width == 160 and scrollRef.current.height == 64, "scroll view hit size was not synced") -- 50
	local originalScrollNode = scrollRef.current -- 51
	local contentNode = scrollRef.current.children:get(1) -- 52
	local inputOverlay = scrollRef.current.children:get(2) -- 53
	expect(inputOverlay.width == 160 and inputOverlay.height == 64, "scroll input overlay hit size was not synced") -- 54
	inputOverlay:emit( -- 55
		"MouseWheel", -- 55
		Vec2(0, 1) -- 55
	) -- 55
	Director.systemScheduler:schedule(once(function() -- 56
		expect(offset.value == 20, "mouse wheel did not update scroll offset") -- 57
		contentNode = scrollRef.current.children:get(1) -- 58
		expect(contentNode.y == 20, "scroll content y did not follow offset direction") -- 59
		inputOverlay = scrollRef.current.children:get(2) -- 60
		inputOverlay:emit( -- 61
			"MouseWheel", -- 61
			Vec2(0, 100) -- 61
		) -- 61
		Director.systemScheduler:schedule(once(function() -- 62
			expect(offset.value == 104, "scroll offset did not clamp to max") -- 63
			local dragCapture = scrollRef.current.children:get(3) -- 64
			expect(dragCapture.width == 160 and dragCapture.height == 64, "scroll drag capture hit size was not synced") -- 65
			expect(dragCapture.swallowTouches == false, "scroll drag capture should not swallow button taps by default") -- 66
			local touch = { -- 67
				first = true, -- 67
				enabled = true, -- 67
				location = Vec2(40, 48), -- 67
				delta = Vec2(0, -30) -- 67
			} -- 67
			dragCapture:emit("TapFilter", touch) -- 68
			expect(touch.enabled == true, "drag touch was rejected inside scroll view") -- 69
			dragCapture:emit("TapMoved", touch) -- 70
			Director.systemScheduler:schedule(once(function() -- 71
				expect(offset.value == 74, "tap drag did not update scroll offset") -- 72
				contentNode = scrollRef.current.children:get(1) -- 73
				expect(contentNode.y == 74, "scroll content y did not follow tap drag") -- 74
				rerenderTick.value = rerenderTick.value + 1 -- 75
				Director.systemScheduler:schedule(once(function() -- 76
					expect(scrollRef.current == originalScrollNode, "scroll view node was recreated by parent rerender") -- 77
					expect(offset.value == 74, "scroll offset changed after parent rerender") -- 78
					contentNode = scrollRef.current.children:get(1) -- 79
					expect(contentNode.y == 74, "scroll content y changed after parent rerender") -- 80
					Content:save(resultFile, "passed") -- 81
					Log("Info", "[UIXScrollViewTest] passed") -- 82
					host:removeFromParent(true) -- 83
					root:unmount() -- 84
				end)) -- 76
			end)) -- 71
		end)) -- 62
	end)) -- 56
end)) -- 47
return ____exports -- 47