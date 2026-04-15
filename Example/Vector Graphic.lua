-- [yue]: Example/Vector Graphic.yue
local _ENV = Dora -- 2
local nvg <const> = nvg -- 3
local Color <const> = Color -- 3
local VGNode <const> = VGNode -- 3
local Sequence <const> = Sequence -- 3
local Scale <const> = Scale -- 3
local Ease <const> = Ease -- 3
local coroutine <const> = coroutine -- 3
local cycle <const> = cycle -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
local drawHeart -- 5
drawHeart = function() -- 5
	nvg.BeginPath() -- 6
	nvg.MoveTo(36.29, 0) -- 7
	nvg.BezierTo(32.5244, 0.0, 28.9316, 1.3173, 26.0742, 3.7275) -- 8
	nvg.BezierTo(23.2168, 1.3173, 19.624, 0, 15.8593, 0) -- 9
	nvg.BezierTo(5.4843, 0, 0, 5.4838, 0, 15.8588) -- 10
	nvg.BezierTo(0.0, 23.5278, 9.248, 33.1123, 14.7607, 38.143) -- 11
	nvg.BezierTo(17.2099, 40.3779, 23.8379, 46.0322, 25.9765, 46.2172) -- 12
	nvg.BezierTo(26.0097, 46.2207, 26.0478, 46.2226, 26.08, 46.2216) -- 13
	nvg.BezierTo(26.1093, 46.2216, 26.1377, 46.2207, 26.165, 46.2177) -- 14
	nvg.LineTo(26.165, 46.2163) -- 15
	nvg.BezierTo(28.2246, 46.0263, 34.748, 40.4858, 37.165, 38.2939) -- 16
	nvg.BezierTo(42.7607, 33.2197, 52.1484, 23.5581, 52.1484, 15.8588) -- 17
	nvg.BezierTo(52.1484, 5.4838, 46.665, 0, 36.29, 0) -- 18
	nvg.ClosePath() -- 19
	nvg.FillColor(Color(253, 90, 90, 255)) -- 20
	nvg.Fill() -- 21
	return nvg -- 5
end -- 5
local stopRendering = false -- 23
do -- 25
	local _with_0 = VGNode(60, 50, 5) -- 25
	_with_0:render(drawHeart) -- 26
	_with_0:slot("Cleanup", function() -- 27
		stopRendering = true -- 27
	end) -- 27
	_with_0:runAction(Sequence(Scale(0.2, 1.0, 0.3), Scale(0.5, 0.3, 1.0, Ease.OutBack)), true) -- 28
end -- 25
local drawAnimated = coroutine.wrap(function() -- 33
	while true do -- 34
		cycle(0.2, function(time) -- 35
			nvg.Translate(60, 50) -- 36
			local scale = 1 - 0.7 * time -- 37
			nvg.Scale(scale, scale) -- 38
			nvg.Translate(-30, -25) -- 39
			return drawHeart() -- 40
		end) -- 35
		cycle(0.5, function(time) -- 41
			nvg.Translate(60, 50) -- 42
			local scale = 0.3 + 0.7 * Ease:func(Ease.OutBack, time) -- 43
			nvg.Scale(scale, scale) -- 44
			nvg.Translate(-30, -25) -- 45
			return drawHeart() -- 46
		end) -- 41
	end -- 34
end) -- 33
threadLoop(function() -- 48
	nvg.Scale(2, 2) -- 49
	drawAnimated() -- 50
	return stopRendering -- 51
end) -- 48
local windowFlags = { -- 56
	"NoDecoration", -- 56
	"AlwaysAutoResize", -- 56
	"NoSavedSettings", -- 56
	"NoFocusOnAppearing", -- 56
	"NoNav", -- 56
	"NoMove" -- 56
} -- 56
return threadLoop(function() -- 64
	local width -- 65
	width = App.visualSize.width -- 65
	ImGui.SetNextWindowBgAlpha(0.35) -- 66
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 67
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 68
	return ImGui.Begin("Vector Graphic Rendering", windowFlags, function() -- 69
		ImGui.Text("Vector Graphic Rendering (Yuescript)") -- 70
		ImGui.Separator() -- 71
		return ImGui.TextWrapped("Use nanoVG lib to do vector graphic rendering, render to a texture or do instant render!") -- 72
	end) -- 69
end) -- 64
