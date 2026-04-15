-- [yue]: Example/ClipNode.yue
local _ENV = Dora -- 2
local math <const> = math -- 3
local Vec2 <const> = Vec2 -- 3
local DrawNode <const> = DrawNode -- 3
local Model <const> = Model -- 3
local Sequence <const> = Sequence -- 3
local X <const> = X -- 3
local Event <const> = Event -- 3
local ClipNode <const> = ClipNode -- 3
local Line <const> = Line -- 3
local App <const> = App -- 3
local Node <const> = Node -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local StarVertices -- 5
StarVertices = function(radius, line) -- 5
	if line == nil then -- 5
		line = false -- 5
	end -- 5
	local a = math.rad(36) -- 6
	local c = math.rad(72) -- 7
	local f = math.sin(a) * math.tan(c) + math.cos(a) -- 8
	local R = radius -- 9
	local r = R / f -- 10
	local _accum_0 = { } -- 11
	local _len_0 = 1 -- 11
	for i = 9, line and -1 or 0, -1 do -- 11
		local angle = i * a -- 12
		local cr = i % 2 == 1 and r or R -- 13
		_accum_0[_len_0] = Vec2(cr * math.sin(angle), cr * math.cos(angle)) -- 14
		_len_0 = _len_0 + 1 -- 12
	end -- 11
	return _accum_0 -- 11
end -- 5
local maskA -- 18
do -- 18
	local _with_0 = DrawNode() -- 18
	_with_0:drawPolygon(StarVertices(160)) -- 19
	maskA = _with_0 -- 18
end -- 18
local targetA -- 21
do -- 21
	local _with_0 = Model("Model/xiaoli.model") -- 21
	_with_0.look = "happy" -- 22
	_with_0.fliped = true -- 23
	_with_0:play("walk", true) -- 24
	_with_0:runAction(Sequence(X(1.5, -200, 200), Event("Turn"), X(1.5, 200, -200), Event("Turn")), true) -- 25
	_with_0:slot("Turn", function() -- 31
		_with_0.fliped = not _with_0.fliped -- 31
	end) -- 31
	targetA = _with_0 -- 21
end -- 21
local clipNodeA -- 33
do -- 33
	local _with_0 = ClipNode(maskA) -- 33
	_with_0:addChild(targetA) -- 34
	_with_0.inverted = true -- 35
	clipNodeA = _with_0 -- 33
end -- 33
local frame -- 36
do -- 36
	local _with_0 = Line(StarVertices(160, true), App.themeColor) -- 36
	_with_0.visible = false -- 37
	frame = _with_0 -- 36
end -- 36
local exampleA -- 38
do -- 38
	local _with_0 = Node() -- 38
	_with_0:addChild(clipNodeA) -- 39
	_with_0:addChild(frame) -- 40
	_with_0.visible = false -- 41
	exampleA = _with_0 -- 38
end -- 38
local maskB -- 45
do -- 45
	local _with_0 = Model("Model/xiaoli.model") -- 45
	_with_0.look = "happy" -- 46
	_with_0.fliped = true -- 47
	_with_0:play("walk", true) -- 48
	maskB = _with_0 -- 45
end -- 45
local targetB -- 50
do -- 50
	local _with_0 = DrawNode() -- 50
	_with_0:drawPolygon(StarVertices(160)) -- 51
	_with_0:runAction(Sequence(X(1.5, -200, 200), X(1.5, 200, -200)), true) -- 52
	targetB = _with_0 -- 50
end -- 50
local clipNodeB -- 57
do -- 57
	local _with_0 = ClipNode(maskB) -- 57
	_with_0:addChild(targetB) -- 58
	_with_0.inverted = true -- 59
	_with_0.alphaThreshold = 0.3 -- 60
	clipNodeB = _with_0 -- 57
end -- 57
local exampleB -- 61
do -- 61
	local _with_0 = Node() -- 61
	_with_0:addChild(clipNodeB) -- 62
	exampleB = _with_0 -- 61
end -- 61
local inverted = true -- 66
local withAlphaThreshold = true -- 67
local windowFlags = { -- 69
	"NoDecoration", -- 69
	"AlwaysAutoResize", -- 69
	"NoSavedSettings", -- 69
	"NoFocusOnAppearing", -- 69
	"NoNav", -- 69
	"NoMove" -- 69
} -- 69
return threadLoop(function() -- 77
	local width -- 78
	width = App.visualSize.width -- 78
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 79
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 80
	return ImGui.Begin("Clip Node", windowFlags, function() -- 81
		ImGui.Text("Clip Node (YueScript)") -- 82
		ImGui.Separator() -- 83
		ImGui.TextWrapped("Render children nodes with mask!") -- 84
		do -- 85
			local changed -- 85
			changed, inverted = ImGui.Checkbox("Inverted", inverted) -- 85
			if changed then -- 85
				clipNodeA.inverted = inverted -- 86
				clipNodeB.inverted = inverted -- 87
				frame.visible = not inverted -- 88
			end -- 85
		end -- 85
		local changed -- 89
		changed, withAlphaThreshold = ImGui.Checkbox("With alphaThreshold", withAlphaThreshold) -- 89
		if changed then -- 89
			exampleB.visible = withAlphaThreshold -- 90
			exampleA.visible = not withAlphaThreshold -- 91
		end -- 89
	end) -- 81
end) -- 77
