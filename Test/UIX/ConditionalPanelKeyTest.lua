-- [tsx]: ConditionalPanelKeyTest.tsx
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
local Panel = ____UIX.Panel -- 4
local resultFile = Path(Content.writablePath, "UIXConditionalPanelKeyTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXConditionalPanelKeyTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local settingsOpen = signal(true) -- 21
local settingsRef = reference() -- 22
local skillsRef = reference() -- 23
root:render(function() -- 25
	local ____React_createElement_2 = React.createElement -- 25
	local ____temp_1 = {windowRoot = true, style = {padding = 8}} -- 25
	local ____settingsOpen_value_0 -- 27
	if settingsOpen.value then -- 27
		____settingsOpen_value_0 = React.createElement(Panel, {key = "settings-panel", ref = settingsRef, title = "Settings", style = { -- 27
			position = "absolute", -- 32
			left = 18, -- 32
			top = 142, -- 32
			width = 360, -- 32
			height = 150 -- 32
		}}) -- 32
	else -- 32
		____settingsOpen_value_0 = nil -- 33
	end -- 33
	return ____React_createElement_2( -- 25
		"align-node", -- 25
		____temp_1, -- 25
		____settingsOpen_value_0, -- 25
		React.createElement(Panel, {key = "skills-panel", ref = skillsRef, title = "Skills", style = { -- 25
			position = "absolute", -- 38
			right = 18, -- 38
			bottom = 18, -- 38
			width = 286, -- 38
			height = 128 -- 38
		}}) -- 38
	) -- 38
end) -- 25
Director.systemScheduler:schedule(once(function() -- 43
	expect(settingsRef.current ~= nil, "settings panel was not mounted") -- 44
	expect(skillsRef.current ~= nil, "skills panel was not mounted") -- 45
	local firstSkills = skillsRef.current -- 46
	settingsOpen.value = false -- 47
	Director.systemScheduler:schedule(once(function() -- 48
		expect(skillsRef.current == firstSkills, "keyed skills panel should be preserved after removing previous conditional sibling") -- 49
		expect(settingsRef.current == nil, "settings panel ref should be cleared after unmount") -- 50
		Content:save(resultFile, "passed") -- 51
		Log("Info", "[UIXConditionalPanelKeyTest] passed") -- 52
		host:removeFromParent(true) -- 53
		root:unmount() -- 54
	end)) -- 48
end)) -- 43
return ____exports -- 43