-- [yue]: Example/EnhancedInput.yue
local _ENV = Dora -- 2
local require <const> = require -- 3
local Node <const> = Node -- 3
local print <const> = print -- 3
local ImGui <const> = ImGui -- 3
local loop <const> = loop -- 3
local App <const> = App -- 3
local Vec2 <const> = Vec2 -- 3
local threadLoop <const> = threadLoop -- 3
local InputManager = require("InputManager") -- 6
local Trigger = InputManager.Trigger -- 7
local QTEContext -- 23
QTEContext = function(keyName, buttonName, timeWindow) -- 23
	return { -- 24
		QTE = Trigger.Sequence({ -- 26
			Trigger.Selector({ -- 27
				Trigger.Selector({ -- 28
					Trigger.KeyPressed(keyName), -- 28
					Trigger.Block(Trigger.AnyKeyPressed()) -- 29
				}), -- 27
				Trigger.Selector({ -- 32
					Trigger.ButtonPressed(buttonName), -- 32
					Trigger.Block(Trigger.AnyButtonPressed()) -- 33
				}) -- 31
			}), -- 26
			Trigger.Selector({ -- 37
				Trigger.KeyTimed(keyName, timeWindow), -- 37
				Trigger.ButtonTimed(buttonName, timeWindow) -- 38
			}) -- 36
		}) -- 24
	} -- 23
end -- 23
local inputManager = InputManager.CreateManager({ -- 43
	Default = { -- 44
		Confirm = Trigger.Selector({ -- 45
			Trigger.ButtonHold("y", 1), -- 45
			Trigger.KeyHold("Return", 1) -- 46
		}), -- 44
		MoveDown = Trigger.Selector({ -- 49
			Trigger.ButtonPressed("dpdown"), -- 49
			Trigger.KeyPressed("S") -- 50
		}) -- 48
	}, -- 43
	Test = { -- 53
		Confirm = Trigger.Selector({ -- 54
			Trigger.ButtonHold("x", 0.3), -- 54
			Trigger.KeyHold("LCtrl", 0.3) -- 55
		}) -- 53
	}, -- 52
	["Phase1"] = QTEContext("J", "a", 3), -- 57
	["Phase2"] = QTEContext("K", "b", 2), -- 58
	["Phase3"] = QTEContext("L", "x", 1) -- 59
}) -- 42
inputManager:pushContext("Default") -- 61
InputManager.CreateGamePad({ -- 63
	inputManager = inputManager -- 63
}) -- 63
local phase = "None" -- 65
local text = "" -- 66
local holdTime = 0.0 -- 68
local node = Node() -- 69
node:gslot("Input.Confirm", function(state, progress) -- 70
	if "Completed" == state then -- 72
		holdTime = 1 -- 73
	elseif "Ongoing" == state then -- 74
		holdTime = progress -- 75
	end -- 71
end) -- 70
node:gslot("Input.MoveDown", function(state, progress, value) -- 77
	if state == "Completed" then -- 78
		return print(state, progress, value) -- 79
	end -- 78
end) -- 77
node:gslot("Input.QTE", function(state, progress) -- 81
	if "Phase1" == phase then -- 82
		if "Canceled" == state then -- 84
			phase = "None" -- 85
			inputManager:popContext() -- 86
			text = "Failed!" -- 87
			holdTime = progress -- 88
		elseif "Completed" == state then -- 89
			phase = "Phase2" -- 90
			inputManager:pushContext(phase) -- 91
			text = "Button B or Key K" -- 92
		elseif "Ongoing" == state then -- 93
			holdTime = progress -- 94
		end -- 83
	elseif "Phase2" == phase then -- 96
		if "Canceled" == state then -- 98
			phase = "None" -- 99
			inputManager:popContext(2) -- 100
			text = "Failed!" -- 101
			holdTime = progress -- 102
		elseif "Completed" == state then -- 103
			phase = "Phase3" -- 104
			inputManager:pushContext(phase) -- 105
			text = "Button X or Key L" -- 106
		elseif "Ongoing" == state then -- 107
			holdTime = progress -- 108
		end -- 97
	elseif "Phase3" == phase then -- 110
		if ("Canceled") == state or "Completed" == state then -- 112
			phase = "None" -- 113
			inputManager:popContext(3) -- 114
			text = state == "Completed" and "Success!" or "Failed!" -- 115
			holdTime = progress -- 116
		elseif "Ongoing" == state then -- 117
			holdTime = progress -- 118
		end -- 111
	end -- 81
end) -- 81
local QTEButton -- 120
QTEButton = function() -- 120
	if ImGui.Button("Start QTE") then -- 121
		phase = "Phase1" -- 122
		text = "Button A or Key J" -- 123
		return inputManager:pushContext(phase) -- 124
	end -- 121
end -- 120
local countDownFlags = { -- 126
	"NoResize", -- 126
	"NoSavedSettings", -- 126
	"NoTitleBar", -- 126
	"NoMove", -- 126
	"AlwaysAutoResize" -- 126
} -- 126
node:schedule(loop(function() -- 133
	local width, height -- 134
	do -- 134
		local _obj_0 = App.visualSize -- 134
		width, height = _obj_0.width, _obj_0.height -- 134
	end -- 134
	ImGui.SetNextWindowPos(Vec2(width / 2 - 160, height / 2 - 100)) -- 135
	ImGui.SetNextWindowSize(Vec2(300, 100), "Always") -- 136
	ImGui.Begin("CountDown", countDownFlags, function() -- 137
		if phase == "None" then -- 138
			QTEButton() -- 139
		else -- 141
			ImGui.BeginDisabled(QTEButton) -- 141
		end -- 138
		ImGui.SameLine() -- 142
		ImGui.Text(text) -- 143
		return ImGui.ProgressBar(holdTime, Vec2(-1, 30)) -- 144
	end) -- 137
	return false -- 133
end)) -- 133
local checked = false -- 146
local windowFlags = { -- 148
	"NoDecoration", -- 148
	"AlwaysAutoResize", -- 148
	"NoSavedSettings", -- 148
	"NoFocusOnAppearing", -- 148
	"NoNav", -- 148
	"NoMove" -- 148
} -- 148
return threadLoop(function() -- 156
	local width = App.visualSize.width -- 157
	ImGui.SetNextWindowBgAlpha(0.35) -- 158
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), ("Always"), Vec2(1, 0)) -- 159
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 160
	ImGui.Begin("EnhancedInput", windowFlags, function() -- 161
		ImGui.Text("Enhanced Input (YueScript)") -- 162
		ImGui.Separator() -- 163
		ImGui.TextWrapped("Change input context to alter input mapping") -- 164
		if phase == "None" then -- 165
			local changed -- 166
			changed, checked = ImGui.Checkbox("hold X to confirm (instead Y)", checked) -- 166
			if changed then -- 166
				if checked then -- 167
					return inputManager:pushContext("Test") -- 168
				else -- 170
					return inputManager:popContext() -- 170
				end -- 167
			end -- 166
		end -- 165
	end) -- 161
	return false -- 156
end) -- 156
