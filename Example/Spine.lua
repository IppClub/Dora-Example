-- [yue]: Example/Spine.yue
local _ENV = Dora -- 2
local Spine <const> = Spine -- 3
local p <const> = p -- 3
local print <const> = print -- 3
local tostring <const> = tostring -- 3
local Label <const> = Label -- 3
local App <const> = App -- 3
local Vec2 <const> = Vec2 -- 3
local Sequence <const> = Sequence -- 3
local Spawn <const> = Spawn -- 3
local Scale <const> = Scale -- 3
local Ease <const> = Ease -- 3
local Delay <const> = Delay -- 3
local Opacity <const> = Opacity -- 3
local Event <const> = Event -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local spineStr = "Spine/dragon-ess" -- 5
local animations = Spine:getAnimations(spineStr) -- 7
local looks = Spine:getLooks(spineStr) -- 8
p(animations, looks) -- 10
local _anon_func_0 = function(_with_0, name, x, y) -- 19
	local _with_1 = Label("sarasa-mono-sc-regular", 30) -- 19
	_with_1.text = name -- 20
	_with_1.color = App.themeColor -- 21
	_with_1.position = Vec2(x, y) -- 22
	_with_1:perform(Sequence(Spawn(Scale(1, 0, 2, Ease.OutQuad), Sequence(Delay(0.5), Opacity(0.5, 1, 0))), Event("Stop"))) -- 23
	_with_1:slot("Stop", function() -- 30
		return _with_1:removeFromParent() -- 30
	end) -- 30
	return _with_1 -- 19
end -- 19
local spine -- 12
do -- 12
	local _with_0 = Spine(spineStr) -- 12
	_with_0.look = looks[1] -- 13
	_with_0:play(animations[1], true) -- 14
	_with_0:onAnimationEnd(function(name) -- 15
		return print(tostring(name) .. " end!") -- 15
	end) -- 15
	_with_0:onTapBegan(function(touch) -- 16
		local x, y -- 17
		do -- 17
			local _obj_0 = touch.location -- 17
			x, y = _obj_0.x, _obj_0.y -- 17
		end -- 17
		local name = _with_0:containsPoint(x, y) -- 18
		if name then -- 18
			return _with_0:addChild(_anon_func_0(_with_0, name, x, y)) -- 19
		end -- 18
	end) -- 16
	spine = _with_0 -- 12
end -- 12
local windowFlags = { -- 35
	"NoDecoration", -- 35
	"AlwaysAutoResize", -- 35
	"NoSavedSettings", -- 35
	"NoFocusOnAppearing", -- 35
	"NoNav", -- 35
	"NoMove" -- 35
} -- 35
local showDebug = spine.showDebug -- 43
return threadLoop(function() -- 44
	local width -- 45
	width = App.visualSize.width -- 45
	ImGui.SetNextWindowBgAlpha(0.35) -- 46
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 47
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 48
	return ImGui.Begin("Spine", windowFlags, function() -- 49
		ImGui.Text("Spine (YueScript)") -- 50
		ImGui.Separator() -- 51
		ImGui.TextWrapped("Basic usage to create spine! Tap it for a hit test.") -- 52
		local changed -- 53
		changed, showDebug = ImGui.Checkbox("BoundingBox", showDebug) -- 53
		if changed then -- 53
			spine.showDebug = showDebug -- 54
		end -- 53
	end) -- 49
end) -- 44
