-- [yue]: Example/DrawNode.yue
local math = _G.math -- 1
local Vec2 = Dora.Vec2 -- 1
local Node = Dora.Node -- 1
local DrawNode = Dora.DrawNode -- 1
local Color = Dora.Color -- 1
local App = Dora.App -- 1
local Line = Dora.Line -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local CircleVertices -- 4
CircleVertices = function(radius, verts) -- 4
	if verts == nil then -- 4
		verts = 20 -- 4
	end -- 4
	local newV -- 5
	newV = function(index, radius) -- 5
		local angle = 2 * math.pi * index / verts -- 6
		return Vec2(radius * math.cos(angle), radius * math.sin(angle)) + Vec2(radius, radius) -- 7
	end -- 5
	local _accum_0 = { } -- 8
	local _len_0 = 1 -- 8
	for index = 0, verts do -- 8
		_accum_0[_len_0] = newV(index, radius) -- 8
		_len_0 = _len_0 + 1 -- 8
	end -- 8
	return _accum_0 -- 8
end -- 4
local StarVertices -- 10
StarVertices = function(radius) -- 10
	local a = math.rad(36) -- 11
	local c = math.rad(72) -- 12
	local f = math.sin(a) * math.tan(c) + math.cos(a) -- 13
	local R = radius -- 14
	local r = R / f -- 15
	local _accum_0 = { } -- 16
	local _len_0 = 1 -- 16
	for i = 9, 0, -1 do -- 16
		local angle = i * a -- 17
		local cr = i % 2 == 1 and r or R -- 18
		_accum_0[_len_0] = Vec2(cr * math.sin(angle), cr * math.cos(angle)) -- 19
		_len_0 = _len_0 + 1 -- 17
	end -- 19
	return _accum_0 -- 19
end -- 10
do -- 21
	local _with_0 = Node() -- 21
	_with_0:addChild((function() -- 22
		local _with_1 = DrawNode() -- 22
		_with_1.position = Vec2(200, 200) -- 23
		_with_1:drawPolygon(StarVertices(60), Color(0x80ff0080), 1, Color(0xffff0080)) -- 24
		return _with_1 -- 22
	end)()) -- 22
	local themeColor = App.themeColor -- 26
	_with_0:addChild((function() -- 28
		local _with_1 = Line(CircleVertices(60), themeColor) -- 28
		_with_1.position = Vec2(-200, 200) -- 29
		return _with_1 -- 28
	end)()) -- 28
	_with_0:addChild((function() -- 31
		local _with_1 = Node() -- 31
		_with_1.color = themeColor -- 32
		_with_1.scaleX = 2 -- 33
		_with_1.scaleY = 2 -- 34
		_with_1:addChild((function() -- 35
			local _with_2 = DrawNode() -- 35
			_with_2.opacity = 0.5 -- 36
			_with_2:drawPolygon({ -- 38
				Vec2(-20, -10), -- 38
				Vec2(20, -10), -- 39
				Vec2(20, 10), -- 40
				Vec2(-20, 10) -- 41
			}) -- 37
			_with_2:drawPolygon({ -- 44
				Vec2(20, 3), -- 44
				Vec2(32, 10), -- 45
				Vec2(32, -10), -- 46
				Vec2(20, -3) -- 47
			}) -- 43
			_with_2:drawDot(Vec2(-11, 20), 10) -- 49
			_with_2:drawDot(Vec2(11, 20), 10) -- 50
			return _with_2 -- 35
		end)()) -- 35
		_with_1:addChild((function() -- 51
			local _with_2 = Line({ -- 52
				Vec2(0, 0), -- 52
				Vec2(40, 0), -- 53
				Vec2(40, 20), -- 54
				Vec2(0, 20), -- 55
				Vec2(0, 0) -- 56
			}) -- 51
			_with_2.position = Vec2(-20, -10) -- 58
			return _with_2 -- 51
		end)()) -- 51
		_with_1:addChild((function() -- 59
			local _with_2 = Line(CircleVertices(10)) -- 59
			_with_2.position = Vec2(-21, 10) -- 60
			return _with_2 -- 59
		end)()) -- 59
		_with_1:addChild((function() -- 61
			local _with_2 = Line(CircleVertices(10)) -- 61
			_with_2.position = Vec2(1, 10) -- 62
			return _with_2 -- 61
		end)()) -- 61
		_with_1:addChild(Line({ -- 64
			Vec2(20, 3), -- 64
			Vec2(32, 10), -- 65
			Vec2(32, -10), -- 66
			Vec2(20, -3) -- 67
		})) -- 63
		return _with_1 -- 31
	end)()) -- 31
end -- 21
local windowFlags = { -- 73
	"NoDecoration", -- 73
	"AlwaysAutoResize", -- 73
	"NoSavedSettings", -- 73
	"NoFocusOnAppearing", -- 73
	"NoNav", -- 73
	"NoMove" -- 73
} -- 73
return threadLoop(function() -- 81
	local width -- 82
	width = App.visualSize.width -- 82
	ImGui.SetNextWindowBgAlpha(0.35) -- 83
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 84
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 85
	return ImGui.Begin("Draw Node", windowFlags, function() -- 86
		ImGui.Text("Draw Node (YueScript)") -- 87
		ImGui.Separator() -- 88
		return ImGui.TextWrapped("Draw shapes and lines!") -- 89
	end) -- 89
end) -- 89
