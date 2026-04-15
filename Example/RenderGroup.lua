-- [yue]: Example/RenderGroup.yue
local _ENV = Dora -- 2
local Class <const> = Class -- 3
local Node <const> = Node -- 3
local Vec2 <const> = Vec2 -- 3
local Sprite <const> = Sprite -- 3
local DrawNode <const> = DrawNode -- 3
local Color <const> = Color -- 3
local App <const> = App -- 3
local Line <const> = Line -- 3
local Angle <const> = Angle -- 3
local Size <const> = Size -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local _anon_func_0 = function() -- 11
	local _with_0 = Sprite("Image/logo.png") -- 11
	_with_0.scaleX = 0.1 -- 12
	_with_0.scaleY = 0.1 -- 13
	_with_0.renderOrder = 1 -- 14
	return _with_0 -- 11
end -- 11
local _anon_func_1 = function() -- 16
	local _with_0 = DrawNode() -- 16
	_with_0:drawPolygon({ -- 18
		Vec2(-60, -60), -- 18
		Vec2(60, -60), -- 19
		Vec2(60, 60), -- 20
		Vec2(-60, 60) -- 21
	}, Color(App.themeColor:toColor3(), 0x30)) -- 17
	_with_0.renderOrder = 2 -- 23
	_with_0.angle = 45 -- 24
	return _with_0 -- 16
end -- 16
local _anon_func_2 = function() -- 26
	local _with_0 = Line({ -- 27
		Vec2(-60, -60), -- 27
		Vec2(60, -60), -- 28
		Vec2(60, 60), -- 29
		Vec2(-60, 60), -- 30
		Vec2(-60, -60) -- 31
	}, Color(0xffff0080)) -- 26
	_with_0.renderOrder = 3 -- 33
	_with_0.angle = 45 -- 34
	return _with_0 -- 26
end -- 26
local Item = Class(Node, { -- 6
	__init = function(self) -- 6
		self.width = 144 -- 7
		self.height = 144 -- 8
		self.anchor = Vec2.zero -- 9
		self:addChild(_anon_func_0()) -- 11
		self:addChild(_anon_func_1()) -- 16
		self:addChild(_anon_func_2()) -- 26
		return self:runAction(Angle(5, 0, 360), true) -- 36
	end -- 6
}) -- 5
local currentEntry -- 38
do -- 38
	local _with_0 = Node() -- 38
	_with_0.renderGroup = true -- 39
	_with_0.size = Size(750, 750) -- 40
	for _ = 1, 16 do -- 41
		_with_0:addChild(Item()) -- 41
	end -- 41
	_with_0:alignItems() -- 42
	currentEntry = _with_0 -- 38
end -- 38
local renderGroup = currentEntry.renderGroup -- 46
local windowFlags = { -- 48
	"NoDecoration", -- 48
	"AlwaysAutoResize", -- 48
	"NoSavedSettings", -- 48
	"NoFocusOnAppearing", -- 48
	"NoNav", -- 48
	"NoMove" -- 48
} -- 48
return threadLoop(function() -- 56
	local width -- 57
	width = App.visualSize.width -- 57
	ImGui.SetNextWindowBgAlpha(0.35) -- 58
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 59
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 60
	return ImGui.Begin("Render Group", windowFlags, function() -- 61
		ImGui.Text("Render Group (YueScript)") -- 62
		ImGui.Separator() -- 63
		ImGui.TextWrapped("When render group is enabled, the nodes in the sub render tree will be grouped by \"renderOrder\" property, and get rendered in ascending order!\nNotice the draw call changes in stats window.") -- 64
		local changed -- 65
		changed, renderGroup = ImGui.Checkbox("Grouped", renderGroup) -- 65
		if changed then -- 65
			currentEntry.renderGroup = renderGroup -- 66
		end -- 65
	end) -- 61
end) -- 56
