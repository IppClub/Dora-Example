-- [yue]: Example/Hello World.yue
local _ENV = Dora -- 2
local Node <const> = Node -- 3
local print <const> = print -- 3
local sleep <const> = sleep -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
do -- 5
	local _with_0 = Node() -- 5
	_with_0:onEnter(function() -- 6
		return print("on enter event") -- 6
	end) -- 6
	_with_0:onExit(function() -- 7
		return print("on exit event") -- 7
	end) -- 7
	_with_0:onCleanup(function() -- 8
		return print("on node destoyed event") -- 8
	end) -- 8
	_with_0:once(function() -- 9
		for i = 5, 1, -1 do -- 10
			print(i) -- 11
			sleep(1) -- 12
		end -- 10
		return print("Hello World!") -- 13
	end) -- 9
end -- 5
local windowFlags = { -- 18
	"NoDecoration", -- 18
	"AlwaysAutoResize", -- 18
	"NoSavedSettings", -- 18
	"NoFocusOnAppearing", -- 18
	"NoNav", -- 18
	"NoMove" -- 18
} -- 18
return threadLoop(function() -- 26
	local width -- 27
	width = App.visualSize.width -- 27
	ImGui.SetNextWindowBgAlpha(0.35) -- 28
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 29
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 30
	return ImGui.Begin("Hello World", windowFlags, function() -- 31
		ImGui.Text("Hello World (YueScript)") -- 32
		ImGui.Separator() -- 33
		return ImGui.TextWrapped("Basic Dora schedule and signal function usage. Written in Yuescript. View outputs in log window!") -- 34
	end) -- 31
end) -- 26
