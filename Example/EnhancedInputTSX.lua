-- [tsx]: EnhancedInputTSX.tsx
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local toNode = ____DoraX.toNode -- 2
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 3
local Node = ____Dora.Node -- 3
local Vec2 = ____Dora.Vec2 -- 3
local loop = ____Dora.loop -- 3
local threadLoop = ____Dora.threadLoop -- 3
local ImGui = require("ImGui") -- 4
local ____InputManager = require("InputManager") -- 6
local GamePad = ____InputManager.GamePad -- 6
local CreateManager = ____InputManager.CreateManager -- 6
local Trigger = ____InputManager.Trigger -- 6
local function QTEContext(keyName, buttonName, timeWindow) -- 15
	return {QTE = Trigger.Sequence({ -- 16
		Trigger.Selector({ -- 18
			Trigger.Selector({ -- 19
				Trigger.KeyPressed(keyName), -- 20
				Trigger.Block(Trigger.AnyKeyPressed()) -- 21
			}), -- 21
			Trigger.Selector({ -- 23
				Trigger.ButtonPressed(buttonName), -- 24
				Trigger.Block(Trigger.AnyButtonPressed()) -- 25
			}) -- 25
		}), -- 25
		Trigger.Selector({ -- 28
			Trigger.KeyTimed(keyName, timeWindow), -- 29
			Trigger.ButtonTimed(buttonName, timeWindow) -- 30
		}) -- 30
	})} -- 30
end -- 15
local inputManager = CreateManager({ -- 36
	Default = { -- 37
		Confirm = Trigger.Hold({{button = "y"}, {key = "Return"}}, 1), -- 38
		MoveDown = Trigger.Pressed({{button = "dpdown"}, {key = "S"}}) -- 42
	}, -- 42
	Test = {Confirm = Trigger.Hold({{button = "x"}, {key = "LCtrl"}}, 0.3)}, -- 47
	Phase1 = QTEContext("J", "a", 3), -- 53
	Phase2 = QTEContext("K", "b", 2), -- 54
	Phase3 = QTEContext("L", "x", 1) -- 55
}) -- 55
inputManager:pushContext("Default") -- 58
toNode(React.createElement(GamePad, {inputManager = inputManager})) -- 60
local phase = "None" -- 64
local text = "" -- 65
local holdTime = 0 -- 67
local node = Node() -- 68
inputManager:on( -- 69
	"Confirm", -- 69
	function(event) -- 69
		if event.state == "Completed" then -- 69
			holdTime = 1 -- 71
		elseif event.state == "Ongoing" then -- 71
			holdTime = event.progress -- 73
		end -- 73
	end -- 69
) -- 69
inputManager:onCompleted( -- 77
	"MoveDown", -- 77
	function(event) -- 77
		print(event.state, event.progress, event.value) -- 78
	end -- 77
) -- 77
inputManager:on( -- 81
	"QTE", -- 81
	function(____bindingPattern0) -- 81
		local progress -- 81
		local state -- 81
		state = ____bindingPattern0.state -- 81
		progress = ____bindingPattern0.progress -- 81
		repeat -- 81
			local ____switch8 = phase -- 81
			local ____cond8 = ____switch8 == "Phase1" -- 81
			if ____cond8 then -- 81
				repeat -- 81
					local ____switch9 = state -- 81
					local ____cond9 = ____switch9 == "Canceled" -- 81
					if ____cond9 then -- 81
						phase = "None" -- 86
						inputManager:popContext() -- 87
						text = "Failed!" -- 88
						holdTime = progress -- 89
						break -- 90
					end -- 90
					____cond9 = ____cond9 or ____switch9 == "Completed" -- 90
					if ____cond9 then -- 90
						phase = "Phase2" -- 92
						inputManager:pushContext("Phase2") -- 93
						text = "Button B or Key K" -- 94
						break -- 95
					end -- 95
					____cond9 = ____cond9 or ____switch9 == "Ongoing" -- 95
					if ____cond9 then -- 95
						holdTime = progress -- 97
						break -- 98
					end -- 98
				until true -- 98
				break -- 100
			end -- 100
			____cond8 = ____cond8 or ____switch8 == "Phase2" -- 100
			if ____cond8 then -- 100
				repeat -- 100
					local ____switch10 = state -- 100
					local ____cond10 = ____switch10 == "Canceled" -- 100
					if ____cond10 then -- 100
						phase = "None" -- 104
						inputManager:popContext(2) -- 105
						text = "Failed!" -- 106
						holdTime = progress -- 107
						break -- 108
					end -- 108
					____cond10 = ____cond10 or ____switch10 == "Completed" -- 108
					if ____cond10 then -- 108
						phase = "Phase3" -- 110
						inputManager:pushContext("Phase3") -- 111
						text = "Button X or Key L" -- 112
						break -- 113
					end -- 113
					____cond10 = ____cond10 or ____switch10 == "Ongoing" -- 113
					if ____cond10 then -- 113
						holdTime = progress -- 115
						break -- 116
					end -- 116
				until true -- 116
				break -- 118
			end -- 118
			____cond8 = ____cond8 or ____switch8 == "Phase3" -- 118
			if ____cond8 then -- 118
				repeat -- 118
					local ____switch11 = state -- 118
					local ____cond11 = ____switch11 == "Canceled" or ____switch11 == "Completed" -- 118
					if ____cond11 then -- 118
						phase = "None" -- 123
						inputManager:popContext(3) -- 124
						text = state == "Completed" and "Success!" or "Failed!" -- 125
						holdTime = progress -- 126
						break -- 127
					end -- 127
					____cond11 = ____cond11 or ____switch11 == "Ongoing" -- 127
					if ____cond11 then -- 127
						holdTime = progress -- 129
						break -- 130
					end -- 130
				until true -- 130
				break -- 132
			end -- 132
		until true -- 132
	end -- 81
) -- 81
local function QTEButton() -- 136
	if ImGui.Button("Start QTE") then -- 136
		phase = "Phase1" -- 138
		text = "Button A or Key J" -- 139
		inputManager:pushContext("Phase1") -- 140
	end -- 140
end -- 136
local countDownFlags = { -- 143
	"NoResize", -- 144
	"NoSavedSettings", -- 145
	"NoTitleBar", -- 146
	"NoMove", -- 147
	"AlwaysAutoResize" -- 148
} -- 148
node:schedule(loop(function() -- 150
	local ____App_visualSize_0 = App.visualSize -- 151
	local width = ____App_visualSize_0.width -- 151
	local height = ____App_visualSize_0.height -- 151
	ImGui.SetNextWindowPos(Vec2(width / 2 - 160, height / 2 - 100)) -- 152
	ImGui.SetNextWindowSize( -- 153
		Vec2(300, 100), -- 153
		"Always" -- 153
	) -- 153
	ImGui.Begin( -- 154
		"CountDown", -- 154
		countDownFlags, -- 154
		function() -- 154
			if phase == "None" then -- 154
				QTEButton() -- 156
			else -- 156
				ImGui.BeginDisabled(QTEButton) -- 158
			end -- 158
			ImGui.SameLine() -- 160
			ImGui.Text(text) -- 161
			ImGui.ProgressBar( -- 162
				holdTime, -- 162
				Vec2(-1, 30) -- 162
			) -- 162
		end -- 154
	) -- 154
	return false -- 164
end)) -- 150
local checked = false -- 167
local windowFlags = { -- 169
	"NoDecoration", -- 170
	"AlwaysAutoResize", -- 171
	"NoSavedSettings", -- 172
	"NoFocusOnAppearing", -- 173
	"NoMove" -- 174
} -- 174
threadLoop(function() -- 176
	local ____App_visualSize_1 = App.visualSize -- 177
	local width = ____App_visualSize_1.width -- 177
	ImGui.SetNextWindowBgAlpha(0.35) -- 178
	ImGui.SetNextWindowPos( -- 179
		Vec2(width - 10, 10), -- 179
		"Always", -- 179
		Vec2(1, 0) -- 179
	) -- 179
	ImGui.SetNextWindowSize( -- 180
		Vec2(240, 0), -- 180
		"FirstUseEver" -- 180
	) -- 180
	ImGui.Begin( -- 181
		"EnhancedInput", -- 181
		windowFlags, -- 181
		function() -- 181
			ImGui.Text("Enhanced Input (TSX)") -- 182
			ImGui.Separator() -- 183
			ImGui.TextWrapped("Change input context to alter input mapping") -- 184
			if phase == "None" then -- 184
				local changed, result = ImGui.Checkbox("hold X to Confirm (instead Y)", checked) -- 186
				if changed then -- 186
					if checked then -- 186
						inputManager:popContext() -- 189
					else -- 189
						inputManager:pushContext("Test") -- 191
					end -- 191
					checked = result -- 193
				end -- 193
			end -- 193
		end -- 181
	) -- 181
	return false -- 197
end) -- 176
return ____exports -- 176