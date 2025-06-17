-- [yue]: Example/SVG.yue
local SVG = Dora.SVG -- 1
local Node = Dora.Node -- 1
local threadLoop = Dora.threadLoop -- 1
local nvg = Dora.nvg -- 1
local View = Dora.View -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
local svg = SVG("Image/dora.svg") -- 4
local size <const> = 1133 -- 5
local node = Node() -- 7
threadLoop(function() -- 9
	nvg.ApplyTransform(node) -- 10
	local scale = 0.6 * View.size.height / size -- 11
	nvg.Scale(scale, -scale) -- 12
	nvg.Translate(-size / 2, -size / 2) -- 13
	return svg:render() -- 14
end) -- 9
local windowFlags = { -- 19
	"NoDecoration", -- 19
	"AlwaysAutoResize", -- 19
	"NoSavedSettings", -- 19
	"NoFocusOnAppearing", -- 19
	"NoNav", -- 19
	"NoMove" -- 19
} -- 19
return threadLoop(function() -- 27
	local width -- 28
	width = App.visualSize.width -- 28
	ImGui.SetNextWindowBgAlpha(0.35) -- 29
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 30
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 31
	return ImGui.Begin("SVG Render", windowFlags, function() -- 32
		ImGui.Text("SVG Render (YueScript)") -- 33
		ImGui.Separator() -- 34
		return ImGui.TextWrapped("Load and render an SVG file. Only support the SVG file preprocessed by the picosvg tool.") -- 35
	end) -- 35
end) -- 35
