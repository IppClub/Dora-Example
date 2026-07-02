-- [tsx]: RadioGroupControlTest.tsx
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
local RadioGroup = ____UIX.RadioGroup -- 4
local resultFile = Path(Content.writablePath, "UIXRadioGroupControlTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXRadioGroupControlTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local value = signal("assist") -- 21
local assistRef = reference() -- 22
local manualRef = reference() -- 23
local lockedRef = reference() -- 24
root:render(function() return React.createElement( -- 26
	"align-node", -- 26
	{windowRoot = true, style = {padding = 8}}, -- 26
	React.createElement( -- 26
		RadioGroup, -- 28
		{ -- 28
			value = value.value, -- 28
			direction = "row", -- 28
			itemWidth = 112, -- 28
			items = {{id = "assist", label = "Assist", icon = "heart", ref = assistRef}, {id = "manual", label = "Manual", icon = "warning", ref = manualRef}, { -- 28
				id = "locked", -- 35
				label = "Locked", -- 35
				icon = "lock", -- 35
				disabled = true, -- 35
				ref = lockedRef -- 35
			}}, -- 35
			onValueChange = function(next) -- 35
				local ____next_0 = next -- 37
				value.value = ____next_0 -- 37
				return ____next_0 -- 37
			end -- 37
		} -- 37
	) -- 37
) end) -- 37
Director.systemScheduler:schedule(once(function() -- 42
	expect(assistRef.current ~= nil, "assist radio ref missing") -- 43
	expect(manualRef.current ~= nil, "manual radio ref missing") -- 44
	expect(lockedRef.current ~= nil, "locked radio ref missing") -- 45
	manualRef.current:emit("Tapped") -- 46
	expect(value.value == "manual", "radio did not switch to manual") -- 47
	Director.systemScheduler:schedule(once(function() -- 48
		lockedRef.current:emit("Tapped") -- 49
		expect(value.value == "manual", "disabled radio should not change value") -- 50
		assistRef.current:emit("Tapped") -- 51
		expect(value.value == "assist", "radio did not switch back to assist") -- 52
		Content:save(resultFile, "passed") -- 53
		Log("Info", "[UIXRadioGroupControlTest] passed") -- 54
		host:removeFromParent(true) -- 55
		root:unmount() -- 56
	end)) -- 48
end)) -- 42
return ____exports -- 42