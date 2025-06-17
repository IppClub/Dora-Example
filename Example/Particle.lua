-- [yue]: Example/Particle.yue
local BlendFunc = Dora.BlendFunc -- 1
local Color = Dora.Color -- 1
local Vec2 = Dora.Vec2 -- 1
local Buffer = Dora.Buffer -- 1
local Rect = Dora.Rect -- 1
local tolua = Dora.tolua -- 1
local tostring = _G.tostring -- 1
local string = _G.string -- 1
local table = _G.table -- 1
local pairs = _G.pairs -- 1
local Cache = Dora.Cache -- 1
local Particle = Dora.Particle -- 1
local Node = Dora.Node -- 1
local _module_0 = Dora.ImGui -- 1
local DragFloat = _module_0.DragFloat -- 1
local DragInt = _module_0.DragInt -- 1
local math = _G.math -- 1
local Combo = _module_0.Combo -- 1
local PushItemWidth = _module_0.PushItemWidth -- 1
local DragInt2 = _module_0.DragInt2 -- 1
local SetColorEditOptions = _module_0.SetColorEditOptions -- 1
local ColorEdit4 = _module_0.ColorEdit4 -- 1
local Checkbox = _module_0.Checkbox -- 1
local InputText = _module_0.InputText -- 1
local coroutine = _G.coroutine -- 1
local sleep = Dora.sleep -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local SetNextWindowPos = _module_0.SetNextWindowPos -- 1
local SetNextWindowSize = _module_0.SetNextWindowSize -- 1
local Begin = _module_0.Begin -- 1
local Button = _module_0.Button -- 1
local SameLine = _module_0.SameLine -- 1
local InputTextMultiline = _module_0.InputTextMultiline -- 1
local blendFuncs = { -- 5
	"One", -- 5
	"Zero", -- 6
	"SrcAlpha", -- 7
	"DstAlpha", -- 8
	"InvSrcAlpha", -- 9
	"InvDstAlpha" -- 10
} -- 4
local blendFuncDst = 1 -- 12
local blendFuncSrc = 3 -- 13
local emitterTypes = { -- 16
	"Gravity", -- 16
	"Radius" -- 17
} -- 15
local emitterType = 1 -- 19
local Data = { -- 22
	Angle = { -- 22
		"B", -- 22
		"float", -- 22
		90 -- 22
	}, -- 22
	AngleVariance = { -- 23
		"C", -- 23
		"float", -- 23
		360 -- 23
	}, -- 23
	BlendFuncDestination = { -- 24
		"D", -- 24
		"BlendFunc", -- 24
		BlendFunc:get("One"), -- 24
		"One" -- 24
	}, -- 24
	BlendFuncSource = { -- 25
		"E", -- 25
		" BlendFunc", -- 25
		BlendFunc:get("SrcAlpha"), -- 25
		"SrcAlpha" -- 25
	}, -- 25
	Duration = { -- 26
		"F", -- 26
		"floatN", -- 26
		-1 -- 26
	}, -- 26
	EmissionRate = { -- 27
		"G", -- 27
		"float", -- 27
		350 -- 27
	}, -- 27
	FinishColor = { -- 28
		"H", -- 28
		"Color", -- 28
		Color(0xff000000) -- 28
	}, -- 28
	FinishColorVariance = { -- 29
		"I", -- 29
		"Color", -- 29
		Color(0x0) -- 29
	}, -- 29
	RotationStart = { -- 30
		"J", -- 30
		"float", -- 30
		0 -- 30
	}, -- 30
	RotationStartVariance = { -- 31
		"K", -- 31
		"float", -- 31
		0 -- 31
	}, -- 31
	RotationEnd = { -- 32
		"L", -- 32
		"float", -- 32
		0 -- 32
	}, -- 32
	RotationEndVariance = { -- 33
		"M", -- 33
		"float", -- 33
		0 -- 33
	}, -- 33
	FinishParticleSize = { -- 34
		"N", -- 34
		"floatN", -- 34
		-1 -- 34
	}, -- 34
	FinishParticleSizeVariance = { -- 35
		"O", -- 35
		"float", -- 35
		0 -- 35
	}, -- 35
	MaxParticles = { -- 36
		"P", -- 36
		"Uint32", -- 36
		100 -- 36
	}, -- 36
	ParticleLifespan = { -- 37
		"Q", -- 37
		"float", -- 37
		1 -- 37
	}, -- 37
	ParticleLifespanVariance = { -- 38
		"R", -- 38
		"float", -- 38
		0.5 -- 38
	}, -- 38
	StartPosition = { -- 39
		"S", -- 39
		"Vec2", -- 39
		Vec2(0, 0) -- 39
	}, -- 39
	StartPositionVariance = { -- 40
		"T", -- 40
		"Vec2", -- 40
		Vec2(0, 0) -- 40
	}, -- 40
	StartColor = { -- 41
		"U", -- 41
		"Color", -- 41
		Color(194, 64, 31, 255) -- 41
	}, -- 41
	StartColorVariance = { -- 42
		"V", -- 42
		"Color", -- 42
		Color(0x0) -- 42
	}, -- 42
	StartParticleSize = { -- 43
		"W", -- 43
		"float", -- 43
		30 -- 43
	}, -- 43
	StartParticleSizeVariance = { -- 44
		"X", -- 44
		"float", -- 44
		10 -- 44
	}, -- 44
	TextureName = { -- 45
		"Y", -- 45
		"string", -- 45
		"", -- 45
		Buffer(256) -- 45
	}, -- 45
	TextureRect = { -- 46
		"Z", -- 46
		"Rect", -- 46
		Rect(0, 0, 0, 0) -- 46
	}, -- 46
	EmitterType = { -- 47
		"a", -- 47
		"EmitterType", -- 47
		0 -- 47
	} -- 47
} -- 21
local Gravity = { -- 49
	RotationIsDir = { -- 49
		"b", -- 49
		"bool", -- 49
		false -- 49
	}, -- 49
	Gravity = { -- 50
		"c", -- 50
		"Vec2", -- 50
		Vec2(0, 100) -- 50
	}, -- 50
	Speed = { -- 51
		"d", -- 51
		"float", -- 51
		20 -- 51
	}, -- 51
	SpeedVariance = { -- 52
		"e", -- 52
		"float", -- 52
		5 -- 52
	}, -- 52
	RadialAcceleration = { -- 53
		"f", -- 53
		"float", -- 53
		0 -- 53
	}, -- 53
	RadialAccelVariance = { -- 54
		"g", -- 54
		"float", -- 54
		0 -- 54
	}, -- 54
	TangentialAcceleration = { -- 55
		"h", -- 55
		"float", -- 55
		0 -- 55
	}, -- 55
	TangentialAccelVariance = { -- 56
		"i", -- 56
		"float", -- 56
		0 -- 56
	} -- 56
} -- 48
local Radius = { -- 58
	StartRadius = { -- 58
		"j", -- 58
		"float", -- 58
		0 -- 58
	}, -- 58
	StartRadiusVariance = { -- 59
		"k", -- 59
		"float", -- 59
		0 -- 59
	}, -- 59
	FinishRadius = { -- 60
		"l", -- 60
		"floatN", -- 60
		-1 -- 60
	}, -- 60
	FinishRadiusVariance = { -- 61
		"m", -- 61
		"float", -- 61
		0 -- 61
	}, -- 61
	RotatePerSecond = { -- 62
		"n", -- 62
		"float", -- 62
		0 -- 62
	}, -- 62
	RotatePerSecondVariance = { -- 63
		"o", -- 63
		"float", -- 63
		0 -- 63
	} -- 63
} -- 57
local toString -- 65
toString = function(value) -- 65
	local _exp_0 = tolua.type(value) -- 66
	if "number" == _exp_0 then -- 67
		return tostring(value) -- 68
	elseif "string" == _exp_0 then -- 69
		return value -- 70
	elseif "Rect" == _exp_0 then -- 71
		return tostring(value.x) .. "," .. tostring(value.y) .. "," .. tostring(value.width) .. "," .. tostring(value.height) -- 72
	elseif "boolean" == _exp_0 then -- 73
		return value and "1" or "0" -- 74
	elseif "Vec2" == _exp_0 then -- 75
		return tostring(value.x) .. "," .. tostring(value.y) -- 76
	elseif "Color" == _exp_0 then -- 77
		return string.format("%.2f,%.2f,%.2f,%.2f", value.r / 255, value.g / 255, value.b / 255, value.a / 255) -- 78
	end -- 78
end -- 65
local _anon_func_1 = function(Data, Gravity, Radius, emitterType, pairs) -- 81
	local _tab_0 = { } -- 81
	local _idx_0 = 1 -- 81
	for _key_0, _value_0 in pairs(Data) do -- 81
		if _idx_0 == _key_0 then -- 81
			_tab_0[#_tab_0 + 1] = _value_0 -- 81
			_idx_0 = _idx_0 + 1 -- 81
		else -- 81
			_tab_0[_key_0] = _value_0 -- 81
		end -- 81
	end -- 81
	local _obj_0 = (emitterType == 1 and Gravity or Radius) -- 81
	local _idx_1 = 1 -- 81
	for _key_0, _value_0 in pairs(_obj_0) do -- 81
		if _idx_1 == _key_0 then -- 81
			_tab_0[#_tab_0 + 1] = _value_0 -- 81
			_idx_1 = _idx_1 + 1 -- 81
		else -- 81
			_tab_0[_key_0] = _value_0 -- 81
		end -- 81
	end -- 81
	return _tab_0 -- 81
end -- 81
local _anon_func_0 = function(Data, Gravity, Radius, emitterType, pairs, toString, tostring) -- 81
	local _accum_0 = { } -- 81
	local _len_0 = 1 -- 81
	for k, v in pairs(_anon_func_1(Data, Gravity, Radius, emitterType, pairs)) do -- 81
		_accum_0[_len_0] = "\n\t<" .. tostring(v[1]) .. " A=\"" .. tostring(toString(v[3])) .. "\"/>" -- 81
		_len_0 = _len_0 + 1 -- 81
	end -- 81
	return _accum_0 -- 81
end -- 81
local getParticle -- 80
getParticle = function() -- 80
	return "<A>" .. table.concat(_anon_func_0(Data, Gravity, Radius, emitterType, pairs, toString, tostring)) .. "\n</A>" -- 81
end -- 80
Cache:update("__test__.par", getParticle()) -- 83
local particle -- 85
do -- 85
	local _with_0 = Particle("__test__.par") -- 85
	_with_0:start() -- 86
	particle = _with_0 -- 85
end -- 85
local root -- 88
do -- 88
	local _with_0 = Node() -- 88
	_with_0.scaleX = 2 -- 89
	_with_0.scaleY = 2 -- 90
	_with_0:addChild(particle) -- 91
	_with_0:onTapMoved(function(touch) -- 92
		if not touch.first then -- 93
			return -- 93
		end -- 93
		particle.position = particle.position + (touch.delta / 2) -- 94
	end) -- 92
	root = _with_0 -- 88
end -- 88
local DataDirty = false -- 98
local Item -- 100
Item = function(name, data) -- 100
	local _with_0 = data[name] -- 100
	local _exp_0 = _with_0[2] -- 100
	if "float" == _exp_0 then -- 101
		local changed -- 102
		changed, _with_0[3] = DragFloat(name, _with_0[3], 0.1, -1000, 1000, "%.1f") -- 102
		if changed then -- 102
			DataDirty = true -- 103
		end -- 102
	elseif "floatN" == _exp_0 then -- 104
		local changed -- 105
		changed, _with_0[3] = DragFloat(name, _with_0[3], 0.1, -1, 1000, "%.1f") -- 105
		if changed then -- 105
			DataDirty = true -- 106
		end -- 105
	elseif "Uint32" == _exp_0 then -- 107
		local changed -- 108
		changed, _with_0[3] = DragInt(name, math.floor(_with_0[3]), 1, 0, 1000) -- 108
		if changed then -- 108
			DataDirty = true -- 109
		end -- 108
	elseif "EmitterType" == _exp_0 then -- 110
		do -- 111
			local changed -- 111
			changed, emitterType = Combo("EmitterType", emitterType, emitterTypes) -- 111
			if changed then -- 111
				_with_0[3] = emitterType == 1 and 0 or 1 -- 112
			end -- 111
		end -- 111
		PushItemWidth(-180, function() -- 113
			if emitterType == 1 then -- 114
				for k in pairs(Gravity) do -- 115
					Item(k, Gravity) -- 115
				end -- 115
			else -- 117
				for k in pairs(Radius) do -- 117
					Item(k, Radius) -- 117
				end -- 117
			end -- 114
		end) -- 113
	elseif "BlendFunc" == _exp_0 then -- 118
		if name == "BlendFuncDestination" then -- 119
			local changed -- 120
			changed, blendFuncDst = Combo("BlendFuncDestination", blendFuncDst, blendFuncs) -- 120
			if changed then -- 120
				_with_0[3] = BlendFunc:get(blendFuncs[blendFuncDst]) -- 121
				_with_0[4] = blendFuncs[blendFuncDst] -- 122
			end -- 120
		elseif name == "BlendFuncSource" then -- 123
			local changed -- 124
			changed, blendFuncSrc = Combo("BlendFuncSource", blendFuncSrc, blendFuncs) -- 124
			if changed then -- 124
				_with_0[3] = BlendFunc:get(blendFuncs[blendFuncSrc]) -- 125
				_with_0[4] = blendFuncs[blendFuncSrc] -- 126
			end -- 124
		end -- 119
	elseif "Vec2" == _exp_0 then -- 127
		local x, y -- 128
		do -- 128
			local _obj_0 = _with_0[3] -- 128
			x, y = _obj_0.x, _obj_0.y -- 128
		end -- 128
		local changed -- 129
		changed, x, y = DragInt2(name, math.floor(x), math.floor(y), 1, -1000, 1000) -- 129
		if changed then -- 129
			DataDirty, _with_0[3] = true, Vec2(x, y) -- 130
		end -- 129
	elseif "Color" == _exp_0 then -- 131
		PushItemWidth(-150, function() -- 132
			SetColorEditOptions({ -- 133
				"DisplayRGB" -- 133
			}) -- 133
			local changed = ColorEdit4(name, _with_0[3]) -- 134
			if changed then -- 134
				DataDirty = true -- 135
			end -- 134
		end) -- 132
	elseif "bool" == _exp_0 then -- 136
		local changed -- 137
		changed, _with_0[3] = Checkbox(name, _with_0[3]) -- 137
		if changed then -- 137
			DataDirty = true -- 138
		end -- 137
	elseif "string" == _exp_0 then -- 139
		local buffer = _with_0[4] -- 140
		local changed = InputText(name, buffer) -- 141
		if changed then -- 141
			DataDirty = true -- 142
			_with_0[3] = buffer.text -- 143
		end -- 141
	end -- 143
	return _with_0 -- 100
end -- 100
local refresh = coroutine.wrap(function() -- 145
	while true do -- 145
		sleep(1) -- 146
		if DataDirty then -- 147
			DataDirty = false -- 148
			Cache:update("__test__.par", getParticle()) -- 149
			particle:removeFromParent() -- 150
			local _with_0 = Particle("__test__.par") -- 151
			_with_0:start() -- 152
			_with_0:addTo(particle) -- 153
			particle = _with_0 -- 151
		end -- 147
	end -- 153
end) -- 145
local buffer = Buffer(5000) -- 156
local windowFlags = { -- 157
	"NoResize", -- 157
	"NoSavedSettings" -- 157
} -- 157
return threadLoop(function() -- 158
	local width, height -- 159
	do -- 159
		local _obj_0 = App.visualSize -- 159
		width, height = _obj_0.width, _obj_0.height -- 159
	end -- 159
	SetNextWindowPos(Vec2(width - 400, 10), "FirstUseEver") -- 160
	SetNextWindowSize(Vec2(390, height - 80), "FirstUseEver") -- 161
	Begin("Particle", windowFlags, function() -- 162
		PushItemWidth(-180, function() -- 163
			for k in pairs(Data) do -- 164
				Item(k, Data) -- 165
			end -- 165
		end) -- 163
		if Button("Export") then -- 166
			buffer.text = getParticle() -- 167
		end -- 166
		SameLine() -- 168
		return PushItemWidth(-1, function() -- 169
			return InputTextMultiline("###Edited", buffer) -- 170
		end) -- 170
	end) -- 162
	return refresh() -- 171
end) -- 171
