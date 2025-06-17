-- [yue]: Example/Hello World.yue
local Node = Dora.Node -- 1
local print = _G.print -- 1
local sleep = Dora.sleep -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
do -- 4
	local _with_0 = Node() -- 4
	_with_0:onEnter(function() -- 5
		return print("on enter event") -- 5
	end) -- 5
	_with_0:onExit(function() -- 6
		return print("on exit event") -- 6
	end) -- 6
	_with_0:onCleanup(function() -- 7
		return print("on node destoyed event") -- 7
	end) -- 7
	_with_0:once(function() -- 8
		for i = 5, 1, -1 do -- 9
			print(i) -- 10
			sleep(1) -- 11
		end -- 11
		return print("Hello World!") -- 12
	end) -- 8
end -- 4
local windowFlags = { -- 17
	"NoDecoration", -- 17
	"AlwaysAutoResize", -- 17
	"NoSavedSettings", -- 17
	"NoFocusOnAppearing", -- 17
	"NoNav", -- 17
	"NoMove" -- 17
} -- 17
return threadLoop(function() -- 25
	local width -- 26
	width = App.visualSize.width -- 26
	ImGui.SetNextWindowBgAlpha(0.35) -- 27
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 28
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 29
	return ImGui.Begin("Hello World", windowFlags, function() -- 30
		ImGui.Text("Hello World (YueScript)") -- 31
		ImGui.Separator() -- 32
		return ImGui.TextWrapped("Basic Dora schedule and signal function usage. Written in Yuescript. View outputs in log window!") -- 33
	end) -- 33
end) -- 33
