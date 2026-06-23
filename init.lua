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
	"NoMove" -- 11
} -- 11
threadLoop(function() -- 13
	local size = App.visualSize -- 14
	ImGui.SetNextWindowBgAlpha(0.35) -- 15
	ImGui.SetNextWindowPos( -- 16
		Vec2(size.width - 10, 10), -- 16
		"Always", -- 16
		Vec2(1, 0) -- 16
	) -- 16
	ImGui.SetNextWindowSize( -- 17
		Vec2(240, 0), -- 17
		"FirstUseEver" -- 17
	) -- 17
	local stop = false -- 18
	ImGui.Begin( -- 19
		"Examples", -- 19
		windowFlags, -- 19
		function() -- 19
			ImGui.Text("Dora Example") -- 20
			ImGui.Separator() -- 21
			ImGui.TextWrapped("Showcases code snippet-based demonstrations of features in the Dora SSR game engine. See more in the example tab.") -- 22
			if ImGui.Button("Try Snake") then -- 22
				require("Example.Snake") -- 24
				stop = true -- 25
			end -- 25
		end -- 19
	) -- 19
	return stop -- 28
end) -- 13
return ____exports -- 13