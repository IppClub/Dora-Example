-- [yue]: Example/MultiTasking.yue
local _ENV = Dora -- 2
local thread <const> = thread -- 3
local print <const> = print -- 3
local Content <const> = Content -- 3
local sleep <const> = sleep -- 3
local require <const> = require -- 3
local string <const> = string -- 3
local App <const> = App -- 3
local tostring <const> = tostring -- 3
local threadLoop <const> = threadLoop -- 3
local math <const> = math -- 3
local Node <const> = Node -- 3
local once <const> = once -- 3
local loop <const> = loop -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
thread(function() -- 5
	print("thread 1") -- 6
	local yueCodes = Content:loadAsync("Example/MultiTasking.yue") -- 7
	sleep(2) -- 8
	local yue = require("yue") -- 9
	local luaCodes = yue.to_lua(yueCodes) -- 10
	print(luaCodes) -- 11
	print("thread 1 done") -- 12
	return thread(function() -- 14
		print("thread 2 stared") -- 15
		repeat -- 16
			print("thread 2 Time passed: " .. tostring(string.format("%.2fs", App.totalTime))) -- 17
			sleep(1) -- 18
		until false -- 16
	end) -- 14
end) -- 5
threadLoop(function() -- 21
	print("thread 3") -- 22
	sleep(math.random(3)) -- 23
	print("do nothing") -- 24
	return sleep(0.2) -- 25
end) -- 21
do -- 27
	local _with_0 = Node() -- 27
	_with_0:schedule(once(function() -- 28
		sleep(5) -- 29
		print("5 seconds later") -- 30
		return _with_0:schedule(loop(function() -- 31
			sleep(3) -- 32
			return print("another 3 seconds") -- 33
		end)) -- 31
	end)) -- 28
end -- 27
local windowFlags = { -- 38
	"NoDecoration", -- 38
	"AlwaysAutoResize", -- 38
	"NoSavedSettings", -- 38
	"NoFocusOnAppearing", -- 38
	"NoNav", -- 38
	"NoMove" -- 38
} -- 38
return threadLoop(function() -- 46
	local width -- 47
	width = App.visualSize.width -- 47
	ImGui.SetNextWindowBgAlpha(0.35) -- 48
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 49
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 50
	return ImGui.Begin("Multi-tasking", windowFlags, function() -- 51
		ImGui.Text("Multi-tasking (YueScript)") -- 52
		ImGui.Separator() -- 53
		return ImGui.TextWrapped("Basic Dora multi-tasking usage. Powered by View outputs in log window!") -- 54
	end) -- 51
end) -- 46
