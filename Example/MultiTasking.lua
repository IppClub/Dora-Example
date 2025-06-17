-- [yue]: Example/MultiTasking.yue
local thread = Dora.thread -- 1
local print = _G.print -- 1
local Content = Dora.Content -- 1
local sleep = Dora.sleep -- 1
local tostring = _G.tostring -- 1
local string = _G.string -- 1
local App = Dora.App -- 1
local threadLoop = Dora.threadLoop -- 1
local math = _G.math -- 1
local Node = Dora.Node -- 1
local once = Dora.once -- 1
local loop = Dora.loop -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
thread(function() -- 4
	print("thread 1") -- 5
	local yueCodes = Content:loadAsync("Example/MultiTasking.yue") -- 6
	sleep(2) -- 7
	local yue = require("yue") -- 8
	local luaCodes = yue.to_lua(yueCodes) -- 9
	print(luaCodes) -- 10
	print("thread 1 done") -- 11
	return thread(function() -- 13
		print("thread 2 stared") -- 14
		repeat -- 15
			print("thread 2 Time passed: " .. tostring(string.format("%.2fs", App.totalTime))) -- 16
			sleep(1) -- 17
		until false -- 18
	end) -- 18
end) -- 4
threadLoop(function() -- 20
	print("thread 3") -- 21
	sleep(math.random(3)) -- 22
	print("do nothing") -- 23
	return sleep(0.2) -- 24
end) -- 20
do -- 26
	local _with_0 = Node() -- 26
	_with_0:schedule(once(function() -- 27
		sleep(5) -- 28
		print("5 seconds later") -- 29
		return _with_0:schedule(loop(function() -- 30
			sleep(3) -- 31
			return print("another 3 seconds") -- 32
		end)) -- 32
	end)) -- 27
end -- 26
local windowFlags = { -- 37
	"NoDecoration", -- 37
	"AlwaysAutoResize", -- 37
	"NoSavedSettings", -- 37
	"NoFocusOnAppearing", -- 37
	"NoNav", -- 37
	"NoMove" -- 37
} -- 37
return threadLoop(function() -- 45
	local width -- 46
	width = App.visualSize.width -- 46
	ImGui.SetNextWindowBgAlpha(0.35) -- 47
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 48
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 49
	return ImGui.Begin("Multi-tasking", windowFlags, function() -- 50
		ImGui.Text("Multi-tasking (YueScript)") -- 51
		ImGui.Separator() -- 52
		return ImGui.TextWrapped("Basic Dora multi-tasking usage. Powered by View outputs in log window!") -- 53
	end) -- 53
end) -- 53
