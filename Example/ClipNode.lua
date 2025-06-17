-- [yue]: Example/ClipNode.yue
local math = _G.math -- 1
local Vec2 = Dora.Vec2 -- 1
local DrawNode = Dora.DrawNode -- 1
local Model = Dora.Model -- 1
local Sequence = Dora.Sequence -- 1
local X = Dora.X -- 1
local Event = Dora.Event -- 1
local ClipNode = Dora.ClipNode -- 1
local Line = Dora.Line -- 1
local App = Dora.App -- 1
local Node = Dora.Node -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local StarVertices -- 4
StarVertices = function(radius, line) -- 4
	if line == nil then -- 4
		line = false -- 4
	end -- 4
	local a = math.rad(36) -- 5
	local c = math.rad(72) -- 6
	local f = math.sin(a) * math.tan(c) + math.cos(a) -- 7
	local R = radius -- 8
	local r = R / f -- 9
	local _accum_0 = { } -- 10
	local _len_0 = 1 -- 10
	for i = 9, line and -1 or 0, -1 do -- 10
		local angle = i * a -- 11
		local cr = i % 2 == 1 and r or R -- 12
		_accum_0[_len_0] = Vec2(cr * math.sin(angle), cr * math.cos(angle)) -- 13
		_len_0 = _len_0 + 1 -- 11
	end -- 13
	return _accum_0 -- 13
end -- 4
local maskA -- 17
do -- 17
	local _with_0 = DrawNode() -- 17
	_with_0:drawPolygon(StarVertices(160)) -- 18
	maskA = _with_0 -- 17
end -- 17
local targetA -- 20
do -- 20
	local _with_0 = Model("Model/xiaoli.model") -- 20
	_with_0.look = "happy" -- 21
	_with_0.fliped = true -- 22
	_with_0:play("walk", true) -- 23
	_with_0:runAction(Sequence(X(1.5, -200, 200), Event("Turn"), X(1.5, 200, -200), Event("Turn")), true) -- 24
	_with_0:slot("Turn", function() -- 30
		_with_0.fliped = not _with_0.fliped -- 30
	end) -- 30
	targetA = _with_0 -- 20
end -- 20
local clipNodeA -- 32
do -- 32
	local _with_0 = ClipNode(maskA) -- 32
	_with_0:addChild(targetA) -- 33
	_with_0.inverted = true -- 34
	clipNodeA = _with_0 -- 32
end -- 32
local frame -- 35
do -- 35
	local _with_0 = Line(StarVertices(160, true), App.themeColor) -- 35
	_with_0.visible = false -- 36
	frame = _with_0 -- 35
end -- 35
local exampleA -- 37
do -- 37
	local _with_0 = Node() -- 37
	_with_0:addChild(clipNodeA) -- 38
	_with_0:addChild(frame) -- 39
	_with_0.visible = false -- 40
	exampleA = _with_0 -- 37
end -- 37
local maskB -- 44
do -- 44
	local _with_0 = Model("Model/xiaoli.model") -- 44
	_with_0.look = "happy" -- 45
	_with_0.fliped = true -- 46
	_with_0:play("walk", true) -- 47
	maskB = _with_0 -- 44
end -- 44
local targetB -- 49
do -- 49
	local _with_0 = DrawNode() -- 49
	_with_0:drawPolygon(StarVertices(160)) -- 50
	_with_0:runAction(Sequence(X(1.5, -200, 200), X(1.5, 200, -200)), true) -- 51
	targetB = _with_0 -- 49
end -- 49
local clipNodeB -- 56
do -- 56
	local _with_0 = ClipNode(maskB) -- 56
	_with_0:addChild(targetB) -- 57
	_with_0.inverted = true -- 58
	_with_0.alphaThreshold = 0.3 -- 59
	clipNodeB = _with_0 -- 56
end -- 56
local exampleB -- 60
do -- 60
	local _with_0 = Node() -- 60
	_with_0:addChild(clipNodeB) -- 61
	exampleB = _with_0 -- 60
end -- 60
local inverted = true -- 65
local withAlphaThreshold = true -- 66
local windowFlags = { -- 68
	"NoDecoration", -- 68
	"AlwaysAutoResize", -- 68
	"NoSavedSettings", -- 68
	"NoFocusOnAppearing", -- 68
	"NoNav", -- 68
	"NoMove" -- 68
} -- 68
return threadLoop(function() -- 76
	local width -- 77
	width = App.visualSize.width -- 77
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 78
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 79
	return ImGui.Begin("Clip Node", windowFlags, function() -- 80
		ImGui.Text("Clip Node (YueScript)") -- 81
		ImGui.Separator() -- 82
		ImGui.TextWrapped("Render children nodes with mask!") -- 83
		do -- 84
			local changed -- 84
			changed, inverted = ImGui.Checkbox("Inverted", inverted) -- 84
			if changed then -- 84
				clipNodeA.inverted = inverted -- 85
				clipNodeB.inverted = inverted -- 86
				frame.visible = not inverted -- 87
			end -- 84
		end -- 84
		local changed -- 88
		changed, withAlphaThreshold = ImGui.Checkbox("With alphaThreshold", withAlphaThreshold) -- 88
		if changed then -- 88
			exampleB.visible = withAlphaThreshold -- 89
			exampleA.visible = not withAlphaThreshold -- 90
		end -- 88
	end) -- 90
end) -- 90
