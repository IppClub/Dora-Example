-- [tsx]: SecondaryControlsTest.tsx
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
local ____UIX = require("UIX") -- 4
local Column = ____UIX.Column -- 4
local Slider = ____UIX.Slider -- 4
local Tabs = ____UIX.Tabs -- 4
local Toggle = ____UIX.Toggle -- 4
local resultFile = Path(Content.writablePath, "UIXSecondaryControlsTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXSecondaryControlsTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local enabled = signal(false) -- 21
local tab = signal("stats") -- 22
local sliderValue = signal(0.35) -- 23
local toggleRef = reference() -- 24
local tabsRef = reference() -- 25
root:render(function() return React.createElement( -- 27
	"align-node", -- 27
	{windowRoot = true, style = {padding = 8}}, -- 27
	React.createElement( -- 27
		Column, -- 29
		{style = {width = 260, gap = 10}}, -- 29
		React.createElement( -- 29
			Toggle, -- 30
			{ -- 30
				ref = toggleRef, -- 30
				checked = enabled.value, -- 30
				label = "Enabled", -- 30
				onChange = function(value) -- 30
					local ____value_0 = value -- 34
					enabled.value = ____value_0 -- 34
					return ____value_0 -- 34
				end -- 34
			} -- 34
		), -- 34
		React.createElement( -- 34
			Slider, -- 36
			{ -- 36
				value = sliderValue.value, -- 36
				min = 0, -- 36
				max = 1, -- 36
				showValue = true, -- 36
				onValueChange = function(value) -- 36
					local ____value_1 = value -- 41
					sliderValue.value = ____value_1 -- 41
					return ____value_1 -- 41
				end -- 41
			} -- 41
		), -- 41
		React.createElement( -- 41
			Tabs, -- 43
			{ -- 43
				ref = tabsRef, -- 43
				value = tab.value, -- 43
				items = {{id = "stats", label = "Stats"}, {id = "gear", label = "Gear"}}, -- 43
				onValueChange = function(value) -- 43
					local ____value_2 = value -- 50
					tab.value = ____value_2 -- 50
					return ____value_2 -- 50
				end -- 50
			} -- 50
		) -- 50
	) -- 50
) end) -- 50
Director.systemScheduler:schedule(once(function() -- 56
	expect(toggleRef.current ~= nil, "toggle ref missing") -- 57
	expect(tabsRef.current ~= nil, "tabs ref missing") -- 58
	toggleRef.current:emit("Tapped") -- 59
	expect(enabled.value == true, "toggle did not emit changed value") -- 60
	local tabChildren = tabsRef.current.children -- 61
	expect(tabChildren ~= nil and tabChildren.count >= 2, "tabs did not mount item buttons") -- 62
	tabChildren:get(2):emit("Tapped") -- 63
	expect(tab.value == "gear", "tabs did not emit selected value") -- 64
	expect(sliderValue.value == 0.35, "slider controlled value should remain unchanged without touch input") -- 65
	Content:save(resultFile, "passed") -- 66
	Log("Info", "[UIXSecondaryControlsTest] passed") -- 67
	host:removeFromParent(true) -- 68
	root:unmount() -- 69
end)) -- 56
return ____exports -- 56