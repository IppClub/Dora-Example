-- [ts]: init.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Vec2 = ____Dora.Vec2 -- 4
local threadLoop = ____Dora.threadLoop -- 4
local windowFlags = { -- 6
	"NoDecoration", -- 7
	"AlwaysAutoResize", -- 8
	"NoSavedSettings", -- 9
	"NoFocusOnAppearing", -- 10
	"NoNav", -- 11
	"NoMove" -- 12
} -- 12
threadLoop(function() -- 14
	local size = App.visualSize -- 15
	ImGui.SetNextWindowBgAlpha(0.35) -- 16
	ImGui.SetNextWindowPos( -- 17
		Vec2(size.width - 10, 10), -- 17
		"Always", -- 17
		Vec2(1, 0) -- 17
	) -- 17
	ImGui.SetNextWindowSize( -- 18
		Vec2(240, 0), -- 18
		"FirstUseEver" -- 18
	) -- 18
	ImGui.Begin( -- 19
		"Examples", -- 19
		windowFlags, -- 19
		function() -- 19
			ImGui.Text("Examples (TypeScript)") -- 20
			ImGui.Separator() -- 21
			ImGui.TextWrapped("Dora Example showcases code snippet-based demonstrations of features in the Dora game engine.") -- 22
		end -- 19
	) -- 19
	return false -- 24
end) -- 14
return ____exports -- 14