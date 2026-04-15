-- [yue]: Example/DragonBones.yue
local _ENV = Dora -- 2
local DragonBone <const> = DragonBone -- 3
local p <const> = p -- 3
local print <const> = print -- 3
local tostring <const> = tostring -- 3
local Label <const> = Label -- 3
local App <const> = App -- 3
local Sequence <const> = Sequence -- 3
local Spawn <const> = Spawn -- 3
local Scale <const> = Scale -- 3
local Ease <const> = Ease -- 3
local Delay <const> = Delay -- 3
local Opacity <const> = Opacity -- 3
local Event <const> = Event -- 3
local Vec2 <const> = Vec2 -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local boneStr = "DragonBones/NewDragon" -- 5
local animations = DragonBone:getAnimations(boneStr) -- 7
local looks = DragonBone:getLooks(boneStr) -- 8
p(animations, looks) -- 10
local _anon_func_0 = function(_with_0, name, x, y) -- 20
	local _with_1 = Label("sarasa-mono-sc-regular", 30) -- 20
	_with_1.text = name -- 21
	_with_1.color = App.themeColor -- 22
	_with_1:perform(Sequence(Spawn(Scale(1, 0, 2, Ease.OutQuad), Sequence(Delay(0.5), Opacity(0.5, 1, 0))), Event("Stop"))) -- 23
	_with_1.position = Vec2(x, y) -- 30
	_with_1.order = 100 -- 31
	_with_1:slot("Stop", function() -- 32
		return _with_1:removeFromParent() -- 32
	end) -- 32
	return _with_1 -- 20
end -- 20
local bone -- 12
do -- 12
	local _with_0 = DragonBone(boneStr) -- 12
	_with_0.look = looks[1] -- 13
	_with_0:play(animations[1], true) -- 14
	_with_0:onAnimationEnd(function(name) -- 15
		return print(tostring(name) .. " end!") -- 15
	end) -- 15
	_with_0.y = -200 -- 16
	_with_0:onTapBegan(function(touch) -- 17
		local x, y -- 18
		do -- 18
			local _obj_0 = touch.location -- 18
			x, y = _obj_0.x, _obj_0.y -- 18
		end -- 18
		local name = _with_0:containsPoint(x, y) -- 19
		if name then -- 19
			return _with_0:addChild(_anon_func_0(_with_0, name, x, y)) -- 20
		end -- 19
	end) -- 17
	bone = _with_0 -- 12
end -- 12
local windowFlags = { -- 37
	"NoDecoration", -- 37
	"AlwaysAutoResize", -- 37
	"NoSavedSettings", -- 37
	"NoFocusOnAppearing", -- 37
	"NoNav", -- 37
	"NoMove" -- 37
} -- 37
local showDebug = bone.showDebug -- 45
return threadLoop(function() -- 46
	local width -- 47
	width = App.visualSize.width -- 47
	ImGui.SetNextWindowBgAlpha(0.35) -- 48
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 49
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 50
	return ImGui.Begin("DragonBones", windowFlags, function() -- 51
		ImGui.Text("DragonBones (YueScript)") -- 52
		ImGui.Separator() -- 53
		ImGui.TextWrapped("Basic usage to create dragonBones! Tap it for a hit test.") -- 54
		local changed -- 55
		changed, showDebug = ImGui.Checkbox("BoundingBox", showDebug) -- 55
		if changed then -- 55
			bone.showDebug = showDebug -- 56
		end -- 55
	end) -- 51
end) -- 46
