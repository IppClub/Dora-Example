-- [tsx]: Hello WorldTSX.tsx
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local toNode = ____DoraX.toNode -- 2
local ImGui = require("ImGui") -- 4
local ____Dora = require("Dora") -- 5
local App = ____Dora.App -- 5
local Vec2 = ____Dora.Vec2 -- 5
local once = ____Dora.once -- 5
local sleep = ____Dora.sleep -- 5
local threadLoop = ____Dora.threadLoop -- 5
toNode(React.createElement( -- 7
	"node", -- 7
	{ -- 7
		onEnter = function() -- 7
			print("on enter event") -- 10
		end, -- 9
		onExit = function() -- 9
			print("on exit event") -- 13
		end, -- 12
		onCleanup = function() -- 12
			print("on node destoyed event") -- 16
		end, -- 15
		onUpdate = once(function() -- 15
			do -- 15
				local i = 5 -- 19
				while i >= 1 do -- 19
					print(i) -- 20
					sleep(1) -- 21
					i = i - 1 -- 19
				end -- 19
			end -- 19
			print("Hello World!") -- 23
		end) -- 18
	} -- 18
)) -- 18
local windowFlags = { -- 28
	"NoDecoration", -- 29
	"AlwaysAutoResize", -- 30
	"NoSavedSettings", -- 31
	"NoFocusOnAppearing", -- 32
	"NoMove" -- 33
} -- 33
threadLoop(function() -- 35
	local size = App.visualSize -- 36
	ImGui.SetNextWindowBgAlpha(0.35) -- 37
	ImGui.SetNextWindowPos( -- 38
		Vec2(size.width - 10, 10), -- 38
		"Always", -- 38
		Vec2(1, 0) -- 38
	) -- 38
	ImGui.SetNextWindowSize( -- 39
		Vec2(240, 0), -- 39
		"FirstUseEver" -- 39
	) -- 39
	ImGui.Begin( -- 40
		"Hello World", -- 40
		windowFlags, -- 40
		function() -- 40
			ImGui.Text("Hello World (TSX)") -- 41
			ImGui.Separator() -- 42
			ImGui.TextWrapped("Basic Dora schedule and signal function usage. Written in Teal. View outputs in log window!") -- 43
		end -- 40
	) -- 40
	return false -- 45
end) -- 35
return ____exports -- 35