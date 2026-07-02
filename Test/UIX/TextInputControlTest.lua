-- [tsx]: TextInputControlTest.tsx
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
local TextInput = ____UIX.TextInput -- 4
local resultFile = Path(Content.writablePath, "UIXTextInputControlTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXTextInputControlTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local value = signal("") -- 21
local submitted = signal("") -- 22
local disabledValue = signal("locked") -- 23
local limitedValue = signal("") -- 24
local inputRef = reference() -- 25
local disabledRef = reference() -- 26
local limitedRef = reference() -- 27
root:render(function() return React.createElement( -- 29
	"align-node", -- 29
	{windowRoot = true, style = {padding = 8}}, -- 29
	React.createElement( -- 29
		Column, -- 31
		{style = {width = 260, gap = 10}}, -- 31
		React.createElement( -- 31
			TextInput, -- 32
			{ -- 32
				key = "name-input", -- 32
				ref = inputRef, -- 32
				value = value.value, -- 32
				placeholder = "Name", -- 32
				prefixIcon = "gear", -- 32
				onValueChange = function(next) -- 32
					local ____next_0 = next -- 38
					value.value = ____next_0 -- 38
					return ____next_0 -- 38
				end, -- 38
				onSubmit = function(next) -- 38
					local ____next_1 = next -- 39
					submitted.value = ____next_1 -- 39
					return ____next_1 -- 39
				end -- 39
			} -- 39
		), -- 39
		React.createElement( -- 39
			TextInput, -- 41
			{ -- 41
				key = "disabled-input", -- 41
				ref = disabledRef, -- 41
				value = disabledValue.value, -- 41
				disabled = true, -- 41
				onValueChange = function(next) -- 41
					local ____next_2 = next -- 46
					disabledValue.value = ____next_2 -- 46
					return ____next_2 -- 46
				end -- 46
			} -- 46
		), -- 46
		React.createElement( -- 46
			TextInput, -- 48
			{ -- 48
				key = "limited-input", -- 48
				ref = limitedRef, -- 48
				value = limitedValue.value, -- 48
				maxLength = 10, -- 48
				onValueChange = function(next) -- 48
					local ____next_3 = next -- 53
					limitedValue.value = ____next_3 -- 53
					return ____next_3 -- 53
				end -- 53
			} -- 53
		) -- 53
	) -- 53
) end) -- 53
Director.systemScheduler:schedule(once(function() -- 59
	expect(inputRef.current ~= nil, "input ref missing") -- 60
	expect(disabledRef.current ~= nil, "disabled input ref missing") -- 61
	expect(limitedRef.current ~= nil, "limited input ref missing") -- 62
	inputRef.current:emit("Tapped") -- 63
	inputRef.current:emit("TextInput", "Do") -- 64
	Director.systemScheduler:schedule(once(function() -- 65
		expect(value.value == "Do", "text input did not append text") -- 66
		inputRef.current:emit("TextInput", "ra") -- 67
		inputRef.current:emit("KeyPressed", "BackSpace") -- 68
		Director.systemScheduler:schedule(once(function() -- 69
			expect(value.value == "Dor", "backspace did not remove one UTF-8 character") -- 70
			inputRef.current:emit("TextInput", "a") -- 71
			inputRef.current:emit("KeyPressed", "Return") -- 72
			Director.systemScheduler:schedule(once(function() -- 73
				expect(value.value == "Dora", "final text value mismatch") -- 74
				expect(submitted.value == "Dora", "return did not submit current value") -- 75
				disabledRef.current:emit("TextInput", "x") -- 76
				Director.systemScheduler:schedule(once(function() -- 77
					expect(disabledValue.value == "locked", "disabled input should ignore text") -- 78
					limitedValue.value = "123456789" -- 79
					Director.systemScheduler:schedule(once(function() -- 80
						limitedRef.current:emit("TextEditing", "abcdef") -- 81
						Director.systemScheduler:schedule(once(function() -- 82
							expect(limitedValue.value == "123456789a", "IME preview should keep existing text and clamp to max length") -- 83
							limitedRef.current:emit("TextInput", "abcdef") -- 84
							Director.systemScheduler:schedule(once(function() -- 85
								expect(limitedValue.value == "123456789a", "IME commit should append only remaining text at max length") -- 86
								Content:save(resultFile, "passed") -- 87
								Log("Info", "[UIXTextInputControlTest] passed") -- 88
								host:removeFromParent(true) -- 89
								root:unmount() -- 90
							end)) -- 85
						end)) -- 82
					end)) -- 80
				end)) -- 77
			end)) -- 73
		end)) -- 69
	end)) -- 65
end)) -- 59
return ____exports -- 59