-- @preview-file on clear
local Model <const> = require("Model")
local threadLoop <const> = require("threadLoop")

local modelFile = "Model/xiaoli.model"
local model = Model(modelFile)
model.recovery = 0.2
model.look = "happy"
model:play("walk", true)
model:onAnimationEnd(function(name: string)
	print(name, "end")
end)

-- example codes ends here, some test ui below --

local App <const> = require("App")
local ImGui <const> = require("ImGui")
local Vec2 <const> = require("Vec2")

local looks = Model:getLooks(modelFile)
if #looks == 0 then
	looks[#looks + 1] = ""
end
local animations = Model:getAnimations(modelFile)
if #animations == 0 then
	animations[#animations + 1] = ""
end
local currentLook = #looks
local currentAnim = #animations
local loop = true
local windowFlags = {
	"NoResize",
	"NoSavedSettings"
}
threadLoop(function(): boolean
	local width = App.visualSize.width
	ImGui.SetNextWindowPos(Vec2(width - 250, 10), "FirstUseEver")
	ImGui.SetNextWindowSize(Vec2(240, 325), "FirstUseEver")
	ImGui.Begin("Model", windowFlags, function()
		ImGui.Text("Model (Teal)")
		local changed = false
		changed, currentLook = ImGui.Combo("Look", currentLook, looks)
		if changed then
			model.look = looks[currentLook]
		end
		changed, currentAnim = ImGui.Combo("Anim", currentAnim, animations)
		if changed then
			model:play(animations[currentAnim], loop)
		end
		changed, loop = ImGui.Checkbox("Loop", loop)
		if changed then
			model:play(animations[currentAnim], loop)
		end
		ImGui.SameLine()
		changed, model.reversed = ImGui.Checkbox("Reversed", model.reversed)
		if changed then
			model:play(animations[currentAnim], loop)
		end
		ImGui.PushItemWidth(-70, function()
			local _: boolean
			_, model.speed = ImGui.DragFloat("Speed", model.speed, 0.01, 0, 10, "%.2f")
			_, model.recovery = ImGui.DragFloat("Recovery", model.recovery, 0.01, 0, 10, "%.2f")
		end)
		local scale = model.scaleX
		local _: boolean
		_, scale = ImGui.DragFloat("Scale", scale, 0.01, 0.5, 2, "%.2f")
		model.scaleX, model.scaleY = scale, scale
		if ImGui.Button("Play", Vec2(140, 30)) then
			model:play(animations[currentAnim], loop)
		end
	end)
end)
