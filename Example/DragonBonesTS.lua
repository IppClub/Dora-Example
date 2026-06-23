-- [ts]: DragonBonesTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Delay = ____Dora.Delay -- 4
local DragonBone = ____Dora.DragonBone -- 4
local Ease = ____Dora.Ease -- 4
local Event = ____Dora.Event -- 4
local Label = ____Dora.Label -- 4
local Opacity = ____Dora.Opacity -- 4
local Scale = ____Dora.Scale -- 4
local Sequence = ____Dora.Sequence -- 4
local Spawn = ____Dora.Spawn -- 4
local Vec2 = ____Dora.Vec2 -- 4
local threadLoop = ____Dora.threadLoop -- 4
local boneStr = "DragonBones/NewDragon" -- 6
local animations = DragonBone:getAnimations(boneStr) -- 7
local looks = DragonBone:getLooks(boneStr) -- 8
p(animations, looks) -- 10
local bone = DragonBone(boneStr) -- 12
if bone then -- 12
	bone.look = looks[1] -- 14
	bone:play(animations[1], true) -- 15
	bone:onAnimationEnd(function(name) -- 16
		print(name .. " end!") -- 17
	end) -- 16
	bone.y = -200 -- 20
	bone:onTapBegan(function(touch) -- 21
		local ____touch_location_0 = touch.location -- 22
		local x = ____touch_location_0.x -- 22
		local y = ____touch_location_0.y -- 22
		local name = bone:containsPoint(x, y) -- 23
		if name then -- 23
			local label = Label("sarasa-mono-sc-regular", 30) -- 25
			if label then -- 25
				label.text = name -- 27
				label.color = App.themeColor -- 28
				label.position = Vec2(x, y) -- 29
				label.order = 100 -- 30
				label:perform(Sequence( -- 31
					Spawn( -- 33
						Scale(1, 0, 2, Ease.OutQuad), -- 34
						Sequence( -- 35
							Delay(0.5), -- 36
							Opacity(0.5, 1, 0) -- 37
						) -- 37
					), -- 37
					Event("Stop") -- 40
				)) -- 40
				label:slot( -- 43
					"Stop", -- 43
					function() -- 43
						label:removeFromParent() -- 44
					end -- 43
				) -- 43
				bone:addChild(label) -- 46
			end -- 46
		end -- 46
	end) -- 21
end -- 21
local windowFlags = { -- 52
	"NoDecoration", -- 53
	"AlwaysAutoResize", -- 54
	"NoSavedSettings", -- 55
	"NoFocusOnAppearing", -- 56
	"NoMove" -- 57
} -- 57
local ____temp_3 = bone and bone.showDebug -- 59
if ____temp_3 == nil then -- 59
	____temp_3 = false -- 59
end -- 59
local showDebug = ____temp_3 -- 59
threadLoop(function() -- 60
	local ____App_visualSize_4 = App.visualSize -- 61
	local width = ____App_visualSize_4.width -- 61
	ImGui.SetNextWindowBgAlpha(0.35) -- 62
	ImGui.SetNextWindowPos( -- 63
		Vec2(width - 10, 10), -- 63
		"Always", -- 63
		Vec2(1, 0) -- 63
	) -- 63
	ImGui.SetNextWindowSize( -- 64
		Vec2(240, 0), -- 64
		"FirstUseEver" -- 64
	) -- 64
	ImGui.Begin( -- 65
		"DragonBones", -- 65
		windowFlags, -- 65
		function() -- 65
			ImGui.Text("DragonBones (TypeScript)") -- 66
			ImGui.Separator() -- 67
			ImGui.TextWrapped("Basic usage to create dragonBones! Tap it for a hit test.") -- 68
			local changed = false -- 69
			changed, showDebug = ImGui.Checkbox("BoundingBox", showDebug) -- 70
			if changed and bone then -- 70
				bone.showDebug = showDebug -- 72
			end -- 72
		end -- 65
	) -- 65
	return false -- 75
end) -- 60
return ____exports -- 60