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
	local stop = false -- 19
	ImGui.Begin( -- 20
		"Examples", -- 20
		windowFlags, -- 20
		function() -- 20
			ImGui.Text("Dora Example") -- 21
			ImGui.Separator() -- 22
			ImGui.TextWrapped("Showcases code snippet-based demonstrations of features in the Dora SSR game engine. See more in the example tab.") -- 23
			if ImGui.Button("Try Snake") then -- 23
				require("Example.Snake") -- 25
				stop = true -- 26
			end -- 26
		end -- 20
	) -- 20
	return stop -- 29
end) -- 14
return ____exports -- 14