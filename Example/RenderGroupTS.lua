-- [ts]: RenderGroupTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local Angle = ____Dora.Angle -- 4
local App = ____Dora.App -- 4
local Color = ____Dora.Color -- 4
local DrawNode = ____Dora.DrawNode -- 4
local Line = ____Dora.Line -- 4
local Node = ____Dora.Node -- 4
local Size = ____Dora.Size -- 4
local Sprite = ____Dora.Sprite -- 4
local Vec2 = ____Dora.Vec2 -- 4
local threadLoop = ____Dora.threadLoop -- 4
local function Item() -- 6
	local node = Node() -- 7
	node.width = 144 -- 8
	node.height = 144 -- 9
	node.anchor = Vec2.zero -- 10
	local ____opt_0 = Sprite("Image/logo.png") -- 10
	local sprite = ____opt_0 and ____opt_0:addTo(node) -- 12
	if sprite then -- 12
		sprite.scaleX = 0.1 -- 14
		sprite.scaleY = 0.1 -- 15
		sprite.renderOrder = 1 -- 16
	end -- 16
	local drawNode = DrawNode():addTo(node) -- 19
	drawNode:drawPolygon( -- 20
		{ -- 20
			Vec2(-60, -60), -- 21
			Vec2(60, -60), -- 22
			Vec2(60, 60), -- 23
			Vec2(-60, 60) -- 24
		}, -- 24
		Color(822018176) -- 25
	) -- 25
	drawNode.renderOrder = 2 -- 26
	drawNode.angle = 45 -- 27
	local line = Line( -- 29
		{ -- 29
			Vec2(-60, -60), -- 30
			Vec2(60, -60), -- 31
			Vec2(60, 60), -- 32
			Vec2(-60, 60), -- 33
			Vec2(-60, -60) -- 34
		}, -- 34
		Color(4294901888) -- 35
	):addTo(node) -- 35
	line.renderOrder = 3 -- 36
	line.angle = 45 -- 37
	node:runAction( -- 39
		Angle(5, 0, 360), -- 39
		true -- 39
	) -- 39
	return node -- 40
end -- 6
local currentEntry = Node() -- 43
currentEntry.renderGroup = true -- 44
currentEntry.size = Size(750, 750) -- 45
do -- 45
	local _i = 1 -- 46
	while _i <= 16 do -- 46
		currentEntry:addChild(Item()) -- 47
		_i = _i + 1 -- 46
	end -- 46
end -- 46
currentEntry:alignItems() -- 50
local renderGroup = currentEntry.renderGroup -- 52
local windowFlags = { -- 53
	"NoDecoration", -- 54
	"AlwaysAutoResize", -- 55
	"NoSavedSettings", -- 56
	"NoFocusOnAppearing", -- 57
	"NoMove" -- 58
} -- 58
threadLoop(function() -- 60
	local ____App_visualSize_2 = App.visualSize -- 61
	local width = ____App_visualSize_2.width -- 61
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
		"Render Group", -- 65
		windowFlags, -- 65
		function() -- 65
			ImGui.Text("Render Group (TypeScript)") -- 66
			ImGui.Separator() -- 67
			ImGui.TextWrapped("When render group is enabled, the nodes in the sub render tree will be grouped by \"renderOrder\" property, and get rendered in ascending order!\nNotice the draw call changes in stats window.") -- 68
			local changed = false -- 69
			changed, renderGroup = ImGui.Checkbox("Grouped", renderGroup) -- 70
			if changed then -- 70
				currentEntry.renderGroup = renderGroup -- 72
			end -- 72
		end -- 65
	) -- 65
	return false -- 75
end) -- 60
return ____exports -- 60