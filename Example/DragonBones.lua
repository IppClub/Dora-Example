-- [yue]: Example/DragonBones.yue
local DragonBone = Dora.DragonBone -- 1
local p = _G.p -- 1
local print = _G.print -- 1
local tostring = _G.tostring -- 1
local Label = Dora.Label -- 1
local Vec2 = Dora.Vec2 -- 1
local Spawn = Dora.Spawn -- 1
local Sequence = Dora.Sequence -- 1
local Scale = Dora.Scale -- 1
local Ease = Dora.Ease -- 1
local Event = Dora.Event -- 1
local Opacity = Dora.Opacity -- 1
local Delay = Dora.Delay -- 1
local App = Dora.App -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local boneStr = "DragonBones/NewDragon" -- 4
local animations = DragonBone:getAnimations(boneStr) -- 6
local looks = DragonBone:getLooks(boneStr) -- 7
p(animations, looks) -- 9
local _anon_func_0 = function(App, Delay, Ease, Event, Label, Opacity, Scale, Sequence, Spawn, Vec2, _with_0, name, x, y) -- 31
	local _with_1 = Label("sarasa-mono-sc-regular", 30) -- 19
	_with_1.text = name -- 20
	_with_1.color = App.themeColor -- 21
	_with_1:perform(Sequence(Spawn(Scale(1, 0, 2, Ease.OutQuad), Sequence(Delay(0.5), Opacity(0.5, 1, 0))), Event("Stop"))) -- 22
	_with_1.position = Vec2(x, y) -- 29
	_with_1.order = 100 -- 30
	_with_1:slot("Stop", function() -- 31
		return _with_1:removeFromParent() -- 31
	end) -- 31
	return _with_1 -- 19
end -- 19
local bone -- 11
do -- 11
	local _with_0 = DragonBone(boneStr) -- 11
	_with_0.look = looks[1] -- 12
	_with_0:play(animations[1], true) -- 13
	_with_0:onAnimationEnd(function(name) -- 14
		return print(tostring(name) .. " end!") -- 14
	end) -- 14
	_with_0.y = -200 -- 15
	_with_0:onTapBegan(function(touch) -- 16
		local x, y -- 17
		do -- 17
			local _obj_0 = touch.location -- 17
			x, y = _obj_0.x, _obj_0.y -- 17
		end -- 17
		local name = _with_0:containsPoint(x, y) -- 18
		if name then -- 18
			return _with_0:addChild(_anon_func_0(App, Delay, Ease, Event, Label, Opacity, Scale, Sequence, Spawn, Vec2, _with_0, name, x, y)) -- 31
		end -- 18
	end) -- 16
	bone = _with_0 -- 11
end -- 11
local windowFlags = { -- 36
	"NoDecoration", -- 36
	"AlwaysAutoResize", -- 36
	"NoSavedSettings", -- 36
	"NoFocusOnAppearing", -- 36
	"NoNav", -- 36
	"NoMove" -- 36
} -- 36
local showDebug = bone.showDebug -- 44
return threadLoop(function() -- 45
	local width -- 46
	width = App.visualSize.width -- 46
	ImGui.SetNextWindowBgAlpha(0.35) -- 47
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 48
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 49
	return ImGui.Begin("DragonBones", windowFlags, function() -- 50
		ImGui.Text("DragonBones (YueScript)") -- 51
		ImGui.Separator() -- 52
		ImGui.TextWrapped("Basic usage to create dragonBones! Tap it for a hit test.") -- 53
		local changed -- 54
		changed, showDebug = ImGui.Checkbox("BoundingBox", showDebug) -- 54
		if changed then -- 54
			bone.showDebug = showDebug -- 55
		end -- 54
	end) -- 55
end) -- 55
