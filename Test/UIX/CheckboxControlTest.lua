-- [tsx]: CheckboxControlTest.tsx
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
local Checkbox = ____UIX.Checkbox -- 4
local Column = ____UIX.Column -- 4
local resultFile = Path(Content.writablePath, "UIXCheckboxControlTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXCheckboxControlTest] " .. message) -- 11
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
local partial = signal(false) -- 22
local disabledValue = signal(true) -- 23
local checkboxRef = reference() -- 24
local partialRef = reference() -- 25
local disabledRef = reference() -- 26
root:render(function() return React.createElement( -- 28
	"align-node", -- 28
	{windowRoot = true, style = {padding = 8}}, -- 28
	React.createElement( -- 28
		Column, -- 30
		{style = {width = 260, gap = 10}}, -- 30
		React.createElement( -- 30
			Checkbox, -- 31
			{ -- 31
				key = "checkbox-basic", -- 31
				ref = checkboxRef, -- 31
				checked = enabled.value, -- 31
				label = "Enable loot hints", -- 31
				onChange = function(value) -- 31
					local ____value_0 = value -- 36
					enabled.value = ____value_0 -- 36
					return ____value_0 -- 36
				end -- 36
			} -- 36
		), -- 36
		React.createElement( -- 36
			Checkbox, -- 38
			{ -- 38
				key = "checkbox-partial", -- 38
				ref = partialRef, -- 38
				checked = partial.value, -- 38
				indeterminate = not partial.value, -- 38
				label = "Mixed objectives", -- 38
				onChange = function(value) -- 38
					local ____value_1 = value -- 44
					partial.value = ____value_1 -- 44
					return ____value_1 -- 44
				end -- 44
			} -- 44
		), -- 44
		React.createElement( -- 44
			Checkbox, -- 46
			{ -- 46
				key = "checkbox-disabled", -- 46
				ref = disabledRef, -- 46
				checked = disabledValue.value, -- 46
				disabled = true, -- 46
				label = "Locked option", -- 46
				onChange = function(value) -- 46
					local ____value_2 = value -- 52
					disabledValue.value = ____value_2 -- 52
					return ____value_2 -- 52
				end -- 52
			} -- 52
		) -- 52
	) -- 52
) end) -- 52
Director.systemScheduler:schedule(once(function() -- 58
	expect(checkboxRef.current ~= nil, "checkbox ref missing") -- 59
	expect(partialRef.current ~= nil, "indeterminate checkbox ref missing") -- 60
	expect(disabledRef.current ~= nil, "disabled checkbox ref missing") -- 61
	checkboxRef.current:emit("Tapped") -- 62
	expect(enabled.value == true, "checkbox did not emit checked value") -- 63
	partialRef.current:emit("Tapped") -- 64
	expect(partial.value == true, "indeterminate checkbox did not emit checked value") -- 65
	disabledRef.current:emit("Tapped") -- 66
	expect(disabledValue.value == true, "disabled checkbox should ignore tap") -- 67
	Content:save(resultFile, "passed") -- 68
	Log("Info", "[UIXCheckboxControlTest] passed") -- 69
	host:removeFromParent(true) -- 70
	root:unmount() -- 71
end)) -- 58
return ____exports -- 58