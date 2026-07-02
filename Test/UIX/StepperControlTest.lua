-- [tsx]: StepperControlTest.tsx
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
local Stepper = ____UIX.Stepper -- 4
local resultFile = Path(Content.writablePath, "UIXStepperControlTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXStepperControlTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local amount = signal(2) -- 21
local disabledAmount = signal(4) -- 22
local decRef = reference() -- 23
local incRef = reference() -- 24
local disabledIncRef = reference() -- 25
root:render(function() return React.createElement( -- 27
	"align-node", -- 27
	{windowRoot = true, style = {padding = 8}}, -- 27
	React.createElement( -- 27
		Column, -- 29
		{style = {width = 280, gap = 10}}, -- 29
		React.createElement( -- 29
			Stepper, -- 30
			{ -- 30
				value = amount.value, -- 30
				min = 1, -- 30
				max = 3, -- 30
				step = 1, -- 30
				decreaseRef = decRef, -- 30
				increaseRef = incRef, -- 30
				onValueChange = function(value) -- 30
					local ____value_0 = value -- 37
					amount.value = ____value_0 -- 37
					return ____value_0 -- 37
				end -- 37
			} -- 37
		), -- 37
		React.createElement( -- 37
			Stepper, -- 39
			{ -- 39
				value = disabledAmount.value, -- 39
				min = 1, -- 39
				max = 5, -- 39
				disabled = true, -- 39
				increaseRef = disabledIncRef, -- 39
				onValueChange = function(value) -- 39
					local ____value_1 = value -- 45
					disabledAmount.value = ____value_1 -- 45
					return ____value_1 -- 45
				end -- 45
			} -- 45
		) -- 45
	) -- 45
) end) -- 45
Director.systemScheduler:schedule(once(function() -- 51
	expect(decRef.current ~= nil, "decrease ref missing") -- 52
	expect(incRef.current ~= nil, "increase ref missing") -- 53
	expect(disabledIncRef.current ~= nil, "disabled increase ref missing") -- 54
	incRef.current:emit("Tapped") -- 55
	expect(amount.value == 3, "stepper did not increment") -- 56
	Director.systemScheduler:schedule(once(function() -- 57
		incRef.current:emit("Tapped") -- 58
		expect(amount.value == 3, "stepper should clamp at max") -- 59
		decRef.current:emit("Tapped") -- 60
		expect(amount.value == 2, "stepper did not decrement") -- 61
		Director.systemScheduler:schedule(once(function() -- 62
			decRef.current:emit("Tapped") -- 63
			expect(amount.value == 1, "stepper did not reach min") -- 64
			Director.systemScheduler:schedule(once(function() -- 65
				decRef.current:emit("Tapped") -- 66
				expect(amount.value == 1, "stepper should clamp at min") -- 67
				disabledIncRef.current:emit("Tapped") -- 68
				expect(disabledAmount.value == 4, "disabled stepper should ignore tap") -- 69
				Content:save(resultFile, "passed") -- 70
				Log("Info", "[UIXStepperControlTest] passed") -- 71
				host:removeFromParent(true) -- 72
				root:unmount() -- 73
			end)) -- 65
		end)) -- 62
	end)) -- 57
end)) -- 51
return ____exports -- 51