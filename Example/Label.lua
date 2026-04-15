-- [yue]: Example/Label.yue
local _ENV = Dora -- 2
local Label <const> = Label -- 3
local Sequence <const> = Sequence -- 3
local Delay <const> = Delay -- 3
local Scale <const> = Scale -- 3
local App <const> = App -- 3
local Vec2 <const> = Vec2 -- 3
local Opacity <const> = Opacity -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
do -- 5
	local _with_0 = Label("sarasa-mono-sc-regular", 40) -- 5
	_with_0.batched = false -- 6
	_with_0.text = "你好，Dora SSR！" -- 7
	for i = 1, _with_0.characterCount do -- 8
		local char = _with_0:getCharacter(i) -- 9
		if char ~= nil then -- 10
			char:runAction(Sequence(Delay(i / 5), Scale(0.2, 1, 2), Scale(0.2, 2, 1))) -- 10
		end -- 10
	end -- 8
end -- 5
do -- 16
	local _with_0 = Label("sarasa-mono-sc-regular", 30) -- 16
	_with_0.text = "-- from Jin." -- 17
	_with_0.color = App.themeColor -- 18
	_with_0.opacity = 0 -- 19
	_with_0.position = Vec2(120, -70) -- 20
	_with_0:runAction(Sequence(Delay(2), Opacity(0.2, 0, 1))) -- 21
end -- 16
local windowFlags = { -- 29
	"NoDecoration", -- 29
	"AlwaysAutoResize", -- 29
	"NoSavedSettings", -- 29
	"NoFocusOnAppearing", -- 29
	"NoNav", -- 29
	"NoMove" -- 29
} -- 29
return threadLoop(function() -- 37
	local width -- 38
	width = App.visualSize.width -- 38
	ImGui.SetNextWindowBgAlpha(0.35) -- 39
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 40
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 41
	return ImGui.Begin("Label", windowFlags, function() -- 42
		ImGui.Text("Label (YueScript)") -- 43
		ImGui.Separator() -- 44
		return ImGui.TextWrapped("Render labels with unbatched and batched methods!") -- 45
	end) -- 42
end) -- 37
