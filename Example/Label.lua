-- [yue]: Example/Label.yue
local Label = Dora.Label -- 1
local Sequence = Dora.Sequence -- 1
local Delay = Dora.Delay -- 1
local Scale = Dora.Scale -- 1
local App = Dora.App -- 1
local Vec2 = Dora.Vec2 -- 1
local Opacity = Dora.Opacity -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
do -- 4
	local _with_0 = Label("sarasa-mono-sc-regular", 40) -- 4
	_with_0.batched = false -- 5
	_with_0.text = "你好，Dora SSR！" -- 6
	for i = 1, _with_0.characterCount do -- 7
		local char = _with_0:getCharacter(i) -- 8
		if char ~= nil then -- 9
			char:runAction(Sequence(Delay(i / 5), Scale(0.2, 1, 2), Scale(0.2, 2, 1))) -- 9
		end -- 9
	end -- 13
end -- 4
do -- 15
	local _with_0 = Label("sarasa-mono-sc-regular", 30) -- 15
	_with_0.text = "-- from Jin." -- 16
	_with_0.color = App.themeColor -- 17
	_with_0.opacity = 0 -- 18
	_with_0.position = Vec2(120, -70) -- 19
	_with_0:runAction(Sequence(Delay(2), Opacity(0.2, 0, 1))) -- 20
end -- 15
local windowFlags = { -- 28
	"NoDecoration", -- 28
	"AlwaysAutoResize", -- 28
	"NoSavedSettings", -- 28
	"NoFocusOnAppearing", -- 28
	"NoNav", -- 28
	"NoMove" -- 28
} -- 28
return threadLoop(function() -- 36
	local width -- 37
	width = App.visualSize.width -- 37
	ImGui.SetNextWindowBgAlpha(0.35) -- 38
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 39
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 40
	return ImGui.Begin("Label", windowFlags, function() -- 41
		ImGui.Text("Label (YueScript)") -- 42
		ImGui.Separator() -- 43
		return ImGui.TextWrapped("Render labels with unbatched and batched methods!") -- 44
	end) -- 44
end) -- 44
