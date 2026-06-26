-- [tsx]: PanelScrollTest.tsx
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
local Button = ____UIX.Button -- 4
local Column = ____UIX.Column -- 4
local Panel = ____UIX.Panel -- 4
local Text = ____UIX.Text -- 4
local resultFile = Path(Content.writablePath, "UIXPanelScrollTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXPanelScrollTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local panelRef = reference() -- 21
local offset = signal(0) -- 22
root:render(function() return React.createElement( -- 24
	"align-node", -- 24
	{windowRoot = true, style = {padding = 8}}, -- 24
	React.createElement( -- 24
		Panel, -- 26
		{ -- 26
			ref = panelRef, -- 26
			title = "Bag", -- 26
			padding = 8, -- 26
			headerHeight = 24, -- 26
			scroll = true, -- 26
			scrollContentHeight = 180, -- 26
			scrollWheelSpeed = 20, -- 26
			onScroll = function(value) -- 26
				local ____value_0 = value -- 34
				offset.value = ____value_0 -- 34
				return ____value_0 -- 34
			end, -- 34
			style = {width = 180, height = 120} -- 34
		}, -- 34
		React.createElement( -- 34
			Column, -- 37
			{key = "panel-scroll-content", style = {gap = 6, width = "100%"}}, -- 37
			React.createElement(Text, {text = "Inventory", style = {width = 160, height = 28}}), -- 37
			React.createElement(Button, {key = "a", style = {width = 140, height = 36}}, "Loot"), -- 37
			React.createElement(Button, {key = "b", style = {width = 140, height = 36}}, "Trade"), -- 37
			React.createElement(Button, {key = "c", style = {width = 140, height = 36}}, "Drop") -- 37
		) -- 37
	) -- 37
) end) -- 37
Director.systemScheduler:schedule(once(function() -- 47
	expect(panelRef.current ~= nil, "panel did not mount") -- 48
	expect(panelRef.current.children ~= nil and panelRef.current.children.count >= 3, "panel scroll child missing") -- 49
	local scrollNode = panelRef.current.children:get(3) -- 50
	expect(scrollNode.children ~= nil and scrollNode.children.count == 3, "panel scroll input layers missing") -- 51
	expect(scrollNode.width > 0 and scrollNode.height > 0, "panel scroll hit size was not synced") -- 52
	local inputOverlay = scrollNode.children:get(2) -- 53
	expect(inputOverlay.width > 0 and inputOverlay.height > 0, "panel scroll input overlay hit size was not synced") -- 54
	inputOverlay:emit( -- 55
		"MouseWheel", -- 55
		Vec2(0, 1) -- 55
	) -- 55
	Director.systemScheduler:schedule(once(function() -- 56
		expect(offset.value == 20, "panel scroll did not forward wheel offset") -- 57
		Content:save(resultFile, "passed") -- 58
		Log("Info", "[UIXPanelScrollTest] passed") -- 59
		host:removeFromParent(true) -- 60
		root:unmount() -- 61
	end)) -- 56
end)) -- 47
return ____exports -- 47