-- [yue]: Example/Vector Graphic.yue
local nvg = Dora.nvg -- 1
local Color = Dora.Color -- 1
local VGNode = Dora.VGNode -- 1
local Sequence = Dora.Sequence -- 1
local Scale = Dora.Scale -- 1
local Ease = Dora.Ease -- 1
local coroutine = _G.coroutine -- 1
local cycle = Dora.cycle -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
local drawHeart -- 4
drawHeart = function() -- 4
	local _with_0 = nvg -- 4
	_with_0.BeginPath() -- 5
	_with_0.MoveTo(36.29, 0) -- 6
	_with_0.BezierTo(32.5244, 0.0, 28.9316, 1.3173, 26.0742, 3.7275) -- 7
	_with_0.BezierTo(23.2168, 1.3173, 19.624, 0, 15.8593, 0) -- 8
	_with_0.BezierTo(5.4843, 0, 0, 5.4838, 0, 15.8588) -- 9
	_with_0.BezierTo(0.0, 23.5278, 9.248, 33.1123, 14.7607, 38.143) -- 10
	_with_0.BezierTo(17.2099, 40.3779, 23.8379, 46.0322, 25.9765, 46.2172) -- 11
	_with_0.BezierTo(26.0097, 46.2207, 26.0478, 46.2226, 26.08, 46.2216) -- 12
	_with_0.BezierTo(26.1093, 46.2216, 26.1377, 46.2207, 26.165, 46.2177) -- 13
	_with_0.LineTo(26.165, 46.2163) -- 14
	_with_0.BezierTo(28.2246, 46.0263, 34.748, 40.4858, 37.165, 38.2939) -- 15
	_with_0.BezierTo(42.7607, 33.2197, 52.1484, 23.5581, 52.1484, 15.8588) -- 16
	_with_0.BezierTo(52.1484, 5.4838, 46.665, 0, 36.29, 0) -- 17
	_with_0.ClosePath() -- 18
	_with_0.FillColor(Color(253, 90, 90, 255)) -- 19
	_with_0.Fill() -- 20
	return _with_0 -- 4
end -- 4
local stopRendering = false -- 22
do -- 24
	local _with_0 = VGNode(60, 50, 5) -- 24
	_with_0:render(drawHeart) -- 25
	_with_0:slot("Cleanup", function() -- 26
		stopRendering = true -- 26
	end) -- 26
	_with_0:runAction(Sequence(Scale(0.2, 1.0, 0.3), Scale(0.5, 0.3, 1.0, Ease.OutBack)), true) -- 27
end -- 24
local drawAnimated = coroutine.wrap(function() -- 32
	while true do -- 33
		cycle(0.2, function(time) -- 34
			nvg.Translate(60, 50) -- 35
			local scale = 1 - 0.7 * time -- 36
			nvg.Scale(scale, scale) -- 37
			nvg.Translate(-30, -25) -- 38
			return drawHeart() -- 39
		end) -- 34
		cycle(0.5, function(time) -- 40
			nvg.Translate(60, 50) -- 41
			local scale = 0.3 + 0.7 * Ease:func(Ease.OutBack, time) -- 42
			nvg.Scale(scale, scale) -- 43
			nvg.Translate(-30, -25) -- 44
			return drawHeart() -- 45
		end) -- 40
	end -- 45
end) -- 32
threadLoop(function() -- 47
	nvg.Scale(2, 2) -- 48
	drawAnimated() -- 49
	return stopRendering -- 50
end) -- 47
local windowFlags = { -- 55
	"NoDecoration", -- 55
	"AlwaysAutoResize", -- 55
	"NoSavedSettings", -- 55
	"NoFocusOnAppearing", -- 55
	"NoNav", -- 55
	"NoMove" -- 55
} -- 55
return threadLoop(function() -- 63
	local width -- 64
	width = App.visualSize.width -- 64
	ImGui.SetNextWindowBgAlpha(0.35) -- 65
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 66
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 67
	return ImGui.Begin("Vector Graphic Rendering", windowFlags, function() -- 68
		ImGui.Text("Vector Graphic Rendering (Yuescript)") -- 69
		ImGui.Separator() -- 70
		return ImGui.TextWrapped("Use nanoVG lib to do vector graphic rendering, render to a texture or do instant render!") -- 71
	end) -- 71
end) -- 71
