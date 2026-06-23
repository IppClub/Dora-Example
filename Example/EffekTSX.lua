-- [tsx]: EffekTSX.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local toNode = ____DoraX.toNode -- 2
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 3
local Vec2 = ____Dora.Vec2 -- 3
local threadLoop = ____Dora.threadLoop -- 3
local ImGui = require("ImGui") -- 5
local current -- 7
local function Test(name, jsx) -- 9
	return { -- 10
		name = name, -- 10
		test = function() -- 10
			current = toNode(React.createElement("node", {scaleX = 50, scaleY = 50, scaleZ = 10}, jsx)) -- 11
		end -- 10
	} -- 10
end -- 9
local tests = { -- 18
	Test( -- 20
		"Laser", -- 20
		React.createElement( -- 20
			"effek-node", -- 20
			{angleY = -90}, -- 20
			React.createElement("effek", {file = "Particle/effek/Laser01.efk", x = -200}) -- 20
		) -- 20
	), -- 20
	Test( -- 26
		"Simple Model UV", -- 26
		React.createElement( -- 26
			"effek-node", -- 26
			nil, -- 26
			React.createElement("effek", {file = "Particle/effek/Simple_Model_UV.efkefc"}) -- 26
		) -- 26
	), -- 26
	Test( -- 32
		"Sword Lightning", -- 32
		React.createElement( -- 32
			"effek-node", -- 32
			nil, -- 32
			React.createElement("effek", {file = "Particle/effek/sword_lightning.efkefc"}) -- 32
		) -- 32
	) -- 32
} -- 32
tests[1].test() -- 39
local testNames = __TS__ArrayMap( -- 41
	tests, -- 41
	function(____, t) return t.name end -- 41
) -- 41
local currentTest = 1 -- 43
local windowFlags = {"NoDecoration", "NoSavedSettings", "NoFocusOnAppearing", "NoMove"} -- 44
threadLoop(function() -- 50
	local ____App_visualSize_0 = App.visualSize -- 51
	local width = ____App_visualSize_0.width -- 51
	ImGui.SetNextWindowPos( -- 52
		Vec2(width - 10, 10), -- 52
		"Always", -- 52
		Vec2(1, 0) -- 52
	) -- 52
	ImGui.SetNextWindowSize( -- 53
		Vec2(200, 0), -- 53
		"Always" -- 53
	) -- 53
	ImGui.Begin( -- 54
		"Effekseer", -- 54
		windowFlags, -- 54
		function() -- 54
			ImGui.Text("Effekseer (TSX)") -- 55
			ImGui.Separator() -- 56
			local changed = false -- 57
			changed, currentTest = ImGui.Combo("Test", currentTest, testNames) -- 58
			if changed then -- 58
				if current then -- 58
					current:removeFromParent() -- 61
				end -- 61
				tests[currentTest].test() -- 63
			end -- 63
		end -- 54
	) -- 54
	return false -- 66
end) -- 50
return ____exports -- 50