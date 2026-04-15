-- [yue]: Example/SVG.yue
local _ENV = Dora -- 2
local SVG <const> = SVG -- 3
local Node <const> = Node -- 3
local threadLoop <const> = threadLoop -- 3
local nvg <const> = nvg -- 3
local View <const> = View -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
local svg = SVG("Image/dora.svg") -- 5
local size <const> = 1133 -- 6
local node = Node() -- 8
threadLoop(function() -- 10
	nvg.ApplyTransform(node) -- 11
	local scale = 0.6 * View.size.height / size -- 12
	nvg.Scale(scale, -scale) -- 13
	nvg.Translate(-size / 2, -size / 2) -- 14
	return svg:render() -- 15
end) -- 10
local windowFlags = { -- 20
	"NoDecoration", -- 20
	"AlwaysAutoResize", -- 20
	"NoSavedSettings", -- 20
	"NoFocusOnAppearing", -- 20
	"NoNav", -- 20
	"NoMove" -- 20
} -- 20
return threadLoop(function() -- 28
	local width -- 29
	width = App.visualSize.width -- 29
	ImGui.SetNextWindowBgAlpha(0.35) -- 30
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 31
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 32
	return ImGui.Begin("SVG Render", windowFlags, function() -- 33
		ImGui.Text("SVG Render (YueScript)") -- 34
		ImGui.Separator() -- 35
		return ImGui.TextWrapped("Load and render an SVG file. Only support the SVG file preprocessed by the picosvg tool.") -- 36
	end) -- 33
end) -- 28
