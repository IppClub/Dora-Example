-- [ts]: Hello WorldTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Node = ____Dora.Node -- 4
local Vec2 = ____Dora.Vec2 -- 4
local sleep = ____Dora.sleep -- 4
local threadLoop = ____Dora.threadLoop -- 4
local node = Node() -- 6
node:onEnter(function() -- 7
	print("on enter event") -- 8
end) -- 7
node:onExit(function() -- 10
	print("on exit event") -- 11
end) -- 10
node:onCleanup(function() -- 13
	print("on node destoyed event") -- 14
end) -- 13
node:once(function() -- 16
	do -- 16
		local i = 5 -- 17
		while i >= 1 do -- 17
			print(i) -- 18
			sleep(1) -- 19
			i = i - 1 -- 17
		end -- 17
	end -- 17
	print("Hello World!") -- 21
end) -- 16
local windowFlags = { -- 24
	"NoDecoration", -- 25
	"AlwaysAutoResize", -- 26
	"NoSavedSettings", -- 27
	"NoFocusOnAppearing", -- 28
	"NoMove" -- 29
} -- 29
threadLoop(function() -- 31
	local size = App.visualSize -- 32
	ImGui.SetNextWindowBgAlpha(0.35) -- 33
	ImGui.SetNextWindowPos( -- 34
		Vec2(size.width - 10, 10), -- 34
		"Always", -- 34
		Vec2(1, 0) -- 34
	) -- 34
	ImGui.SetNextWindowSize( -- 35
		Vec2(240, 0), -- 35
		"FirstUseEver" -- 35
	) -- 35
	ImGui.Begin( -- 36
		"Hello World", -- 36
		windowFlags, -- 36
		function() -- 36
			ImGui.Text("Hello World (TypeScript)") -- 37
			ImGui.Separator() -- 38
			ImGui.TextWrapped("Basic Dora schedule and signal function usage. Written in Teal. View outputs in log window!") -- 39
		end -- 36
	) -- 36
	return false -- 41
end) -- 31
return ____exports -- 31