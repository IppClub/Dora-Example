-- @preview-file on clear
local DragonBone <const> = require("DragonBone")
local Label <const> = require("Label")
local App <const> = require("App")
local Sequence <const> = require("Sequence")
local Spawn <const> = require("Spawn")
local Scale <const> = require("Scale")
local Ease <const> = require("Ease")
local Delay <const> = require("Delay")
local Opacity <const> = require("Opacity")
local Event <const> = require("Event")
local Vec2 <const> = require("Vec2")
local threadLoop <const> = require("threadLoop")
local type Touch = require("TouchType")

local boneStr <const> = "DragonBones/NewDragon"
local animations = DragonBone:getAnimations(boneStr)
local looks = DragonBone:getLooks(boneStr)

p(animations, looks)

local bone = DragonBone(boneStr)
if bone is nil then
	return
end
bone.look = looks[1]
bone:play(animations[1], true)
bone:onAnimationEnd(function(name: string)
	print(name .. " end!")
end)

bone.y = -200
bone:onTapBegan(function(touch: Touch)
	local loc = touch.location
	local x, y = loc.x, loc.y
	local name = bone:containsPoint(x, y)
	if name is nil then
		return
	end
	local label = Label("sarasa-mono-sc-regular", 30)
	if label is nil then
		return
	end
	label.text = name
	label.color = App.themeColor
	label.position = Vec2(x, y)
	label.order = 100
	label:perform(
		Sequence(
			Spawn(
				Scale(1, 0, 2, Ease.OutQuad),
				Sequence(
					Delay(0.5),
					Opacity(0.5, 1, 0)
				)
			),
			Event("Stop")
		)
	)
	label:slot("Stop", function()
		label:removeFromParent()
	end)
	bone:addChild(label)
end)

-- example codes ends here, some test ui below --

local ImGui <const> = require("ImGui")

local windowFlags = {
	"NoDecoration",
	"AlwaysAutoResize",
	"NoSavedSettings",
	"NoFocusOnAppearing",
	"NoNav",
	"NoMove"
}
local showDebug = bone.showDebug
threadLoop(function(): boolean
	local width = App.visualSize.width
	ImGui.SetNextWindowBgAlpha(0.35)
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0))
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver")
	ImGui.Begin("DragonBones", windowFlags, function()
		ImGui.Text("DragonBones (Teal)")
		ImGui.Separator()
		ImGui.TextWrapped("Basic usage to create dragonBones! Tap it for a hit test.")
		local changed = false
		changed, showDebug = ImGui.Checkbox("BoundingBox", showDebug)
		if changed then
			bone.showDebug = showDebug
		end
	end)
end)
