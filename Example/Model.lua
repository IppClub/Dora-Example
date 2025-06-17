-- [yue]: Example/Model.yue
local Model = Dora.Model -- 1
local print = _G.print -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
local modelFile = "Model/xiaoli.model" -- 4
local model -- 6
do -- 6
	local _with_0 = Model(modelFile) -- 6
	_with_0.recovery = 0.2 -- 7
	_with_0.look = "happy" -- 8
	_with_0:play("walk", true) -- 9
	_with_0:onAnimationEnd(function(name) -- 10
		return print(name, "end") -- 10
	end) -- 10
	model = _with_0 -- 6
end -- 6
local looks = Model:getLooks(modelFile) -- 14
if #looks == 0 then -- 15
	looks[#looks + 1] = "" -- 15
end -- 15
local animations = Model:getAnimations(modelFile) -- 16
if #animations == 0 then -- 17
	animations[#animations + 1] = "" -- 17
end -- 17
local currentLook = #looks -- 18
local currentAnim = #animations -- 19
local loop = true -- 20
local windowFlags = { -- 22
	"NoResize", -- 22
	"NoSavedSettings" -- 22
} -- 22
return threadLoop(function() -- 23
	local width -- 24
	width = App.visualSize.width -- 24
	ImGui.SetNextWindowPos(Vec2(width - 250, 10), "FirstUseEver") -- 25
	ImGui.SetNextWindowSize(Vec2(240, 325), "FirstUseEver") -- 26
	return ImGui.Begin("Model", windowFlags, function() -- 27
		ImGui.Text("Model (YueScript)") -- 28
		do -- 29
			local changed -- 29
			changed, currentLook = ImGui.Combo("Look", currentLook, looks) -- 29
			if changed then -- 29
				model.look = looks[currentLook] -- 30
			end -- 29
		end -- 29
		do -- 31
			local changed -- 31
			changed, currentAnim = ImGui.Combo("Anim", currentAnim, animations) -- 31
			if changed then -- 31
				model:play(animations[currentAnim], loop) -- 32
			end -- 31
		end -- 31
		do -- 33
			local changed -- 33
			changed, loop = ImGui.Checkbox("Loop", loop) -- 33
			if changed then -- 33
				model:play(animations[currentAnim], loop) -- 34
			end -- 33
		end -- 33
		ImGui.SameLine() -- 35
		do -- 36
			local changed -- 36
			changed, model.reversed = ImGui.Checkbox("Reversed", model.reversed) -- 36
			if changed then -- 36
				model:play(animations[currentAnim], loop) -- 37
			end -- 36
		end -- 36
		ImGui.PushItemWidth(-70, function() -- 38
			local _ -- 39
			_, model.speed = ImGui.DragFloat("Speed", model.speed, 0.01, 0, 10, "%.2f") -- 39
			_, model.recovery = ImGui.DragFloat("Recovery", model.recovery, 0.01, 0, 10, "%.2f") -- 40
		end) -- 38
		local scale = model.scaleX -- 41
		local _ -- 42
		_, scale = ImGui.DragFloat("Scale", scale, 0.01, 0.5, 2, "%.2f") -- 42
		model.scaleX, model.scaleY = scale, scale -- 43
		if ImGui.Button("Play", Vec2(140, 30)) then -- 44
			return model:play(animations[currentAnim], loop) -- 45
		end -- 44
	end) -- 45
end) -- 45
