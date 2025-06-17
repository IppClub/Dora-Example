-- [yue]: Example/RenderGroup.yue
local Class = Dora.Class -- 1
local Node = Dora.Node -- 1
local Vec2 = Dora.Vec2 -- 1
local Sprite = Dora.Sprite -- 1
local DrawNode = Dora.DrawNode -- 1
local App = Dora.App -- 1
local Color = Dora.Color -- 1
local Line = Dora.Line -- 1
local Angle = Dora.Angle -- 1
local Size = Dora.Size -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local _anon_func_0 = function(Sprite) -- 13
	local _with_0 = Sprite("Image/logo.png") -- 10
	_with_0.scaleX = 0.1 -- 11
	_with_0.scaleY = 0.1 -- 12
	_with_0.renderOrder = 1 -- 13
	return _with_0 -- 10
end -- 10
local _anon_func_1 = function(App, Color, DrawNode, Vec2) -- 23
	local _with_0 = DrawNode() -- 15
	_with_0:drawPolygon({ -- 17
		Vec2(-60, -60), -- 17
		Vec2(60, -60), -- 18
		Vec2(60, 60), -- 19
		Vec2(-60, 60) -- 20
	}, Color(App.themeColor:toColor3(), 0x30)) -- 16
	_with_0.renderOrder = 2 -- 22
	_with_0.angle = 45 -- 23
	return _with_0 -- 15
end -- 15
local _anon_func_2 = function(Color, Line, Vec2) -- 33
	local _with_0 = Line({ -- 26
		Vec2(-60, -60), -- 26
		Vec2(60, -60), -- 27
		Vec2(60, 60), -- 28
		Vec2(-60, 60), -- 29
		Vec2(-60, -60) -- 30
	}, Color(0xffff0080)) -- 25
	_with_0.renderOrder = 3 -- 32
	_with_0.angle = 45 -- 33
	return _with_0 -- 25
end -- 25
local Item = Class(Node, { -- 5
	__init = function(self) -- 5
		self.width = 144 -- 6
		self.height = 144 -- 7
		self.anchor = Vec2.zero -- 8
		self:addChild(_anon_func_0(Sprite)) -- 10
		self:addChild(_anon_func_1(App, Color, DrawNode, Vec2)) -- 15
		self:addChild(_anon_func_2(Color, Line, Vec2)) -- 25
		return self:runAction(Angle(5, 0, 360), true) -- 35
	end -- 5
}) -- 4
local currentEntry -- 37
do -- 37
	local _with_0 = Node() -- 37
	_with_0.renderGroup = true -- 38
	_with_0.size = Size(750, 750) -- 39
	for _ = 1, 16 do -- 40
		_with_0:addChild(Item()) -- 40
	end -- 40
	_with_0:alignItems() -- 41
	currentEntry = _with_0 -- 37
end -- 37
local renderGroup = currentEntry.renderGroup -- 45
local windowFlags = { -- 47
	"NoDecoration", -- 47
	"AlwaysAutoResize", -- 47
	"NoSavedSettings", -- 47
	"NoFocusOnAppearing", -- 47
	"NoNav", -- 47
	"NoMove" -- 47
} -- 47
return threadLoop(function() -- 55
	local width -- 56
	width = App.visualSize.width -- 56
	ImGui.SetNextWindowBgAlpha(0.35) -- 57
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 58
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 59
	return ImGui.Begin("Render Group", windowFlags, function() -- 60
		ImGui.Text("Render Group (YueScript)") -- 61
		ImGui.Separator() -- 62
		ImGui.TextWrapped("When render group is enabled, the nodes in the sub render tree will be grouped by \"renderOrder\" property, and get rendered in ascending order!\nNotice the draw call changes in stats window.") -- 63
		local changed -- 64
		changed, renderGroup = ImGui.Checkbox("Grouped", renderGroup) -- 64
		if changed then -- 64
			currentEntry.renderGroup = renderGroup -- 65
		end -- 64
	end) -- 65
end) -- 65
