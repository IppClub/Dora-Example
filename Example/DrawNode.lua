-- [yue]: Example/DrawNode.yue
local _ENV = Dora -- 2
local math <const> = math -- 3
local Vec2 <const> = Vec2 -- 3
local Node <const> = Node -- 3
local DrawNode <const> = DrawNode -- 3
local Color <const> = Color -- 3
local App <const> = App -- 3
local Line <const> = Line -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local CircleVertices -- 5
CircleVertices = function(radius, verts) -- 5
	if verts == nil then -- 5
		verts = 20 -- 5
	end -- 5
	local newV -- 6
	newV = function(index, radius) -- 6
		local angle = 2 * math.pi * index / verts -- 7
		return Vec2(radius * math.cos(angle), radius * math.sin(angle)) + Vec2(radius, radius) -- 8
	end -- 6
	local _accum_0 = { } -- 9
	local _len_0 = 1 -- 9
	for index = 0, verts do -- 9
		_accum_0[_len_0] = newV(index, radius) -- 9
		_len_0 = _len_0 + 1 -- 9
	end -- 9
	return _accum_0 -- 9
end -- 5
local StarVertices -- 11
StarVertices = function(radius) -- 11
	local a = math.rad(36) -- 12
	local c = math.rad(72) -- 13
	local f = math.sin(a) * math.tan(c) + math.cos(a) -- 14
	local R = radius -- 15
	local r = R / f -- 16
	local _accum_0 = { } -- 17
	local _len_0 = 1 -- 17
	for i = 9, 0, -1 do -- 17
		local angle = i * a -- 18
		local cr = i % 2 == 1 and r or R -- 19
		_accum_0[_len_0] = Vec2(cr * math.sin(angle), cr * math.cos(angle)) -- 20
		_len_0 = _len_0 + 1 -- 18
	end -- 17
	return _accum_0 -- 17
end -- 11
do -- 22
	local _with_0 = Node() -- 22
	_with_0:addChild((function() -- 23
		local _with_1 = DrawNode() -- 23
		_with_1.position = Vec2(200, 200) -- 24
		_with_1:drawPolygon(StarVertices(60), Color(0x80ff0080), 1, Color(0xffff0080)) -- 25
		return _with_1 -- 23
	end)()) -- 23
	local themeColor = App.themeColor -- 27
	_with_0:addChild((function() -- 29
		local _with_1 = Line(CircleVertices(60), themeColor) -- 29
		_with_1.position = Vec2(-200, 200) -- 30
		return _with_1 -- 29
	end)()) -- 29
	_with_0:addChild((function() -- 32
		local _with_1 = Node() -- 32
		_with_1.color = themeColor -- 33
		_with_1.scaleX = 2 -- 34
		_with_1.scaleY = 2 -- 35
		_with_1:addChild((function() -- 36
			local _with_2 = DrawNode() -- 36
			_with_2.opacity = 0.5 -- 37
			_with_2:drawPolygon({ -- 39
				Vec2(-20, -10), -- 39
				Vec2(20, -10), -- 40
				Vec2(20, 10), -- 41
				Vec2(-20, 10) -- 42
			}) -- 38
			_with_2:drawPolygon({ -- 45
				Vec2(20, 3), -- 45
				Vec2(32, 10), -- 46
				Vec2(32, -10), -- 47
				Vec2(20, -3) -- 48
			}) -- 44
			_with_2:drawDot(Vec2(-11, 20), 10) -- 50
			_with_2:drawDot(Vec2(11, 20), 10) -- 51
			return _with_2 -- 36
		end)()) -- 36
		_with_1:addChild((function() -- 52
			local _with_2 = Line({ -- 53
				Vec2(0, 0), -- 53
				Vec2(40, 0), -- 54
				Vec2(40, 20), -- 55
				Vec2(0, 20), -- 56
				Vec2(0, 0) -- 57
			}) -- 52
			_with_2.position = Vec2(-20, -10) -- 59
			return _with_2 -- 52
		end)()) -- 52
		_with_1:addChild((function() -- 60
			local _with_2 = Line(CircleVertices(10)) -- 60
			_with_2.position = Vec2(-21, 10) -- 61
			return _with_2 -- 60
		end)()) -- 60
		_with_1:addChild((function() -- 62
			local _with_2 = Line(CircleVertices(10)) -- 62
			_with_2.position = Vec2(1, 10) -- 63
			return _with_2 -- 62
		end)()) -- 62
		_with_1:addChild(Line({ -- 65
			Vec2(20, 3), -- 65
			Vec2(32, 10), -- 66
			Vec2(32, -10), -- 67
			Vec2(20, -3) -- 68
		})) -- 64
		return _with_1 -- 32
	end)()) -- 32
end -- 22
local windowFlags = { -- 74
	"NoDecoration", -- 74
	"AlwaysAutoResize", -- 74
	"NoSavedSettings", -- 74
	"NoFocusOnAppearing", -- 74
	"NoNav", -- 74
	"NoMove" -- 74
} -- 74
return threadLoop(function() -- 82
	local width -- 83
	width = App.visualSize.width -- 83
	ImGui.SetNextWindowBgAlpha(0.35) -- 84
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 85
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 86
	return ImGui.Begin("Draw Node", windowFlags, function() -- 87
		ImGui.Text("Draw Node (YueScript)") -- 88
		ImGui.Separator() -- 89
		return ImGui.TextWrapped("Draw shapes and lines!") -- 90
	end) -- 87
end) -- 82
