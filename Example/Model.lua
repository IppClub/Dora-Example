-- [yue]: Example/Model.yue
local _ENV = Dora -- 2
local Model <const> = Model -- 3
local print <const> = print -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
local modelFile = "Model/xiaoli.model" -- 5
local model -- 7
do -- 7
	local _with_0 = Model(modelFile) -- 7
	_with_0.recovery = 0.2 -- 8
	_with_0.look = "happy" -- 9
	_with_0:play("walk", true) -- 10
	_with_0:onAnimationEnd(function(name) -- 11
		return print(name, "end") -- 11
	end) -- 11
	model = _with_0 -- 7
end -- 7
local looks = Model:getLooks(modelFile) -- 15
if #looks == 0 then -- 16
	looks[#looks + 1] = "" -- 16
end -- 16
local animations = Model:getAnimations(modelFile) -- 17
if #animations == 0 then -- 18
	animations[#animations + 1] = "" -- 18
end -- 18
local currentLook = #looks -- 19
local currentAnim = #animations -- 20
local loop = true -- 21
local windowFlags = { -- 23
	"NoResize", -- 23
	"NoSavedSettings" -- 23
} -- 23
return threadLoop(function() -- 24
	local width -- 25
	width = App.visualSize.width -- 25
	ImGui.SetNextWindowPos(Vec2(width - 250, 10), "FirstUseEver") -- 26
	ImGui.SetNextWindowSize(Vec2(240, 325), "FirstUseEver") -- 27
	return ImGui.Begin("Model", windowFlags, function() -- 28
		ImGui.Text("Model (YueScript)") -- 29
		do -- 30
			local changed -- 30
			changed, currentLook = ImGui.Combo("Look", currentLook, looks) -- 30
			if changed then -- 30
				model.look = looks[currentLook] -- 31
			end -- 30
		end -- 30
		do -- 32
			local changed -- 32
			changed, currentAnim = ImGui.Combo("Anim", currentAnim, animations) -- 32
			if changed then -- 32
				model:play(animations[currentAnim], loop) -- 33
			end -- 32
		end -- 32
		do -- 34
			local changed -- 34
			changed, loop = ImGui.Checkbox("Loop", loop) -- 34
			if changed then -- 34
				model:play(animations[currentAnim], loop) -- 35
			end -- 34
		end -- 34
		ImGui.SameLine() -- 36
		do -- 37
			local changed -- 37
			changed, model.reversed = ImGui.Checkbox("Reversed", model.reversed) -- 37
			if changed then -- 37
				model:play(animations[currentAnim], loop) -- 38
			end -- 37
		end -- 37
		ImGui.PushItemWidth(-70, function() -- 39
			local _ -- 40
			_, model.speed = ImGui.DragFloat("Speed", model.speed, 0.01, 0, 10, "%.2f") -- 40
			_, model.recovery = ImGui.DragFloat("Recovery", model.recovery, 0.01, 0, 10, "%.2f") -- 41
		end) -- 39
		local scale = model.scaleX -- 42
		local _ -- 43
		_, scale = ImGui.DragFloat("Scale", scale, 0.01, 0.5, 2, "%.2f") -- 43
		model.scaleX, model.scaleY = scale, scale -- 44
		if ImGui.Button("Play", Vec2(140, 30)) then -- 45
			return model:play(animations[currentAnim], loop) -- 46
		end -- 45
	end) -- 28
end) -- 24
