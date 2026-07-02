-- [ts]: icons.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Color = ____Dora.Color -- 1
local nvg = require("nvg") -- 2
local function lineIcon(points, rect, color, width) -- 8
	nvg.BeginPath() -- 9
	for i = 1, #points / 2 do -- 9
		local x = rect.x + points[(i - 1) * 2 + 1] * rect.width -- 11
		local y = rect.y + points[(i - 1) * 2 + 1 + 1] * rect.height -- 12
		if i == 1 then -- 12
			nvg.MoveTo(x, y) -- 13
		else -- 13
			nvg.LineTo(x, y) -- 14
		end -- 14
	end -- 14
	nvg.StrokeWidth(width) -- 16
	nvg.StrokeColor(Color(color)) -- 17
	nvg.Stroke() -- 18
end -- 8
____exports.iconPainters = { -- 21
	play = function(_ctx, r, color) -- 22
		nvg.BeginPath() -- 23
		nvg.MoveTo(r.x + r.width * 0.32, r.y + r.height * 0.22) -- 24
		nvg.LineTo(r.x + r.width * 0.32, r.y + r.height * 0.78) -- 25
		nvg.LineTo(r.x + r.width * 0.78, r.y + r.height * 0.5) -- 26
		nvg.ClosePath() -- 27
		nvg.FillColor(Color(color)) -- 28
		nvg.Fill() -- 29
	end, -- 22
	close = function(_ctx, r, color) -- 31
		lineIcon({0.25, 0.25, 0.75, 0.75}, r, color, 2) -- 32
		lineIcon({0.75, 0.25, 0.25, 0.75}, r, color, 2) -- 33
	end, -- 31
	minus = function(_ctx, r, color) -- 35
		lineIcon({0.24, 0.5, 0.76, 0.5}, r, color, 2.4) -- 36
	end, -- 35
	plus = function(_ctx, r, color) -- 38
		lineIcon({0.24, 0.5, 0.76, 0.5}, r, color, 2.4) -- 39
		lineIcon({0.5, 0.24, 0.5, 0.76}, r, color, 2.4) -- 40
	end, -- 38
	gear = function(_ctx, r, color) -- 42
		nvg.BeginPath() -- 43
		nvg.Circle( -- 44
			r.x + r.width / 2, -- 44
			r.y + r.height / 2, -- 44
			math.min(r.width, r.height) * 0.32 -- 44
		) -- 44
		nvg.StrokeWidth(2) -- 45
		nvg.StrokeColor(Color(color)) -- 46
		nvg.Stroke() -- 47
		nvg.BeginPath() -- 48
		nvg.Circle( -- 49
			r.x + r.width / 2, -- 49
			r.y + r.height / 2, -- 49
			math.min(r.width, r.height) * 0.11 -- 49
		) -- 49
		nvg.FillColor(Color(color)) -- 50
		nvg.Fill() -- 51
	end, -- 42
	coin = function(_ctx, r, color) -- 53
		nvg.BeginPath() -- 54
		nvg.Circle( -- 55
			r.x + r.width / 2, -- 55
			r.y + r.height / 2, -- 55
			math.min(r.width, r.height) * 0.38 -- 55
		) -- 55
		nvg.FillColor(Color(color)) -- 56
		nvg.Fill() -- 57
		nvg.BeginPath() -- 58
		nvg.Circle( -- 59
			r.x + r.width / 2, -- 59
			r.y + r.height / 2, -- 59
			math.min(r.width, r.height) * 0.24 -- 59
		) -- 59
		nvg.StrokeWidth(2) -- 60
		nvg.StrokeColor(Color(1426063360)) -- 61
		nvg.Stroke() -- 62
	end, -- 53
	heart = function(_ctx, r, color) -- 64
		nvg.BeginPath() -- 65
		nvg.MoveTo(r.x + r.width * 0.5, r.y + r.height * 0.78) -- 66
		nvg.BezierTo( -- 67
			r.x + r.width * 0.18, -- 67
			r.y + r.height * 0.55, -- 67
			r.x + r.width * 0.15, -- 67
			r.y + r.height * 0.25, -- 67
			r.x + r.width * 0.36, -- 67
			r.y + r.height * 0.25 -- 67
		) -- 67
		nvg.BezierTo( -- 68
			r.x + r.width * 0.46, -- 68
			r.y + r.height * 0.25, -- 68
			r.x + r.width * 0.5, -- 68
			r.y + r.height * 0.36, -- 68
			r.x + r.width * 0.5, -- 68
			r.y + r.height * 0.36 -- 68
		) -- 68
		nvg.BezierTo( -- 69
			r.x + r.width * 0.5, -- 69
			r.y + r.height * 0.36, -- 69
			r.x + r.width * 0.54, -- 69
			r.y + r.height * 0.25, -- 69
			r.x + r.width * 0.64, -- 69
			r.y + r.height * 0.25 -- 69
		) -- 69
		nvg.BezierTo( -- 70
			r.x + r.width * 0.85, -- 70
			r.y + r.height * 0.25, -- 70
			r.x + r.width * 0.82, -- 70
			r.y + r.height * 0.55, -- 70
			r.x + r.width * 0.5, -- 70
			r.y + r.height * 0.78 -- 70
		) -- 70
		nvg.FillColor(Color(color)) -- 71
		nvg.Fill() -- 72
	end, -- 64
	mana = function(_ctx, r, color) -- 74
		nvg.BeginPath() -- 75
		nvg.MoveTo(r.x + r.width * 0.5, r.y + r.height * 0.12) -- 76
		nvg.BezierTo( -- 77
			r.x + r.width * 0.28, -- 77
			r.y + r.height * 0.42, -- 77
			r.x + r.width * 0.2, -- 77
			r.y + r.height * 0.58, -- 77
			r.x + r.width * 0.5, -- 77
			r.y + r.height * 0.86 -- 77
		) -- 77
		nvg.BezierTo( -- 78
			r.x + r.width * 0.8, -- 78
			r.y + r.height * 0.58, -- 78
			r.x + r.width * 0.72, -- 78
			r.y + r.height * 0.42, -- 78
			r.x + r.width * 0.5, -- 78
			r.y + r.height * 0.12 -- 78
		) -- 78
		nvg.FillColor(Color(color)) -- 79
		nvg.Fill() -- 80
	end, -- 74
	lock = function(_ctx, r, color) -- 82
		nvg.BeginPath() -- 83
		nvg.RoundedRect( -- 84
			r.x + r.width * 0.25, -- 84
			r.y + r.height * 0.44, -- 84
			r.width * 0.5, -- 84
			r.height * 0.38, -- 84
			3 -- 84
		) -- 84
		nvg.FillColor(Color(color)) -- 85
		nvg.Fill() -- 86
		nvg.BeginPath() -- 87
		nvg.Arc( -- 88
			r.x + r.width * 0.5, -- 88
			r.y + r.height * 0.45, -- 88
			r.width * 0.22, -- 88
			math.pi, -- 88
			math.pi * 2, -- 88
			"CW" -- 88
		) -- 88
		nvg.StrokeWidth(2) -- 89
		nvg.StrokeColor(Color(color)) -- 90
		nvg.Stroke() -- 91
	end, -- 82
	check = function(_ctx, r, color) -- 93
		lineIcon({ -- 94
			0.22, -- 94
			0.52, -- 94
			0.42, -- 94
			0.72, -- 94
			0.78, -- 94
			0.28 -- 94
		}, r, color, 3) -- 94
	end, -- 93
	warning = function(_ctx, r, color) -- 96
		nvg.BeginPath() -- 97
		nvg.MoveTo(r.x + r.width * 0.5, r.y + r.height * 0.16) -- 98
		nvg.LineTo(r.x + r.width * 0.86, r.y + r.height * 0.82) -- 99
		nvg.LineTo(r.x + r.width * 0.14, r.y + r.height * 0.82) -- 100
		nvg.ClosePath() -- 101
		nvg.StrokeWidth(2) -- 102
		nvg.StrokeColor(Color(color)) -- 103
		nvg.Stroke() -- 104
	end, -- 96
	arrow = function(_ctx, r, color) -- 106
		lineIcon({ -- 107
			0.25, -- 107
			0.5, -- 107
			0.75, -- 107
			0.5, -- 107
			0.55, -- 107
			0.3, -- 107
			0.75, -- 107
			0.5, -- 107
			0.55, -- 107
			0.7 -- 107
		}, r, color, 2) -- 107
	end, -- 106
	chevronDown = function(_ctx, r, color) -- 109
		lineIcon({ -- 110
			0.24, -- 110
			0.38, -- 110
			0.5, -- 110
			0.64, -- 110
			0.76, -- 110
			0.38 -- 110
		}, r, color, 2) -- 110
	end, -- 109
	chevronUp = function(_ctx, r, color) -- 112
		lineIcon({ -- 113
			0.24, -- 113
			0.62, -- 113
			0.5, -- 113
			0.36, -- 113
			0.76, -- 113
			0.62 -- 113
		}, r, color, 2) -- 113
	end -- 112
} -- 112
function ____exports.drawIcon(name, ctx, rect, color) -- 117
	nvg.Save() -- 118
	nvg.Translate(rect.x, rect.y + rect.height) -- 119
	nvg.Scale(1, -1) -- 120
	local drawRect = {x = 0, y = 0, width = rect.width, height = rect.height} -- 121
	local painter = ____exports.iconPainters[name] -- 122
	if painter ~= nil then -- 122
		painter(ctx, drawRect, color) -- 124
		nvg.Restore() -- 125
		return -- 126
	end -- 126
	nvg.BeginPath() -- 128
	nvg.RoundedRect( -- 129
		2, -- 129
		2, -- 129
		rect.width - 4, -- 129
		rect.height - 4, -- 129
		3 -- 129
	) -- 129
	nvg.StrokeWidth(2) -- 130
	nvg.StrokeColor(Color(color)) -- 131
	nvg.Stroke() -- 132
	nvg.Restore() -- 133
end -- 117
return ____exports -- 117