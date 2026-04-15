-- [yue]: Example/Particle.yue
local _ENV = Dora(Dora.ImGui) -- 2
local BlendFunc <const> = BlendFunc -- 3
local Color <const> = Color -- 3
local Vec2 <const> = Vec2 -- 3
local Buffer <const> = Buffer -- 3
local Rect <const> = Rect -- 3
local tolua <const> = tolua -- 3
local tostring <const> = tostring -- 3
local string <const> = string -- 3
local table <const> = table -- 3
local pairs <const> = pairs -- 3
local Cache <const> = Cache -- 3
local Particle <const> = Particle -- 3
local Node <const> = Node -- 3
local DragFloat <const> = DragFloat -- 3
local DragInt <const> = DragInt -- 3
local math <const> = math -- 3
local Combo <const> = Combo -- 3
local PushItemWidth <const> = PushItemWidth -- 3
local DragInt2 <const> = DragInt2 -- 3
local SetColorEditOptions <const> = SetColorEditOptions -- 3
local ColorEdit4 <const> = ColorEdit4 -- 3
local Checkbox <const> = Checkbox -- 3
local InputText <const> = InputText -- 3
local coroutine <const> = coroutine -- 3
local sleep <const> = sleep -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local SetNextWindowPos <const> = SetNextWindowPos -- 3
local SetNextWindowSize <const> = SetNextWindowSize -- 3
local Begin <const> = Begin -- 3
local Button <const> = Button -- 3
local SameLine <const> = SameLine -- 3
local InputTextMultiline <const> = InputTextMultiline -- 3
local blendFuncs = { -- 6
	"One", -- 6
	"Zero", -- 7
	"SrcAlpha", -- 8
	"DstAlpha", -- 9
	"InvSrcAlpha", -- 10
	"InvDstAlpha" -- 11
} -- 5
local blendFuncDst = 1 -- 13
local blendFuncSrc = 3 -- 14
local emitterTypes = { -- 17
	"Gravity", -- 17
	"Radius" -- 18
} -- 16
local emitterType = 1 -- 20
local Data = { -- 23
	Angle = { -- 23
		"B", -- 23
		"float", -- 23
		90 -- 23
	}, -- 23
	AngleVariance = { -- 24
		"C", -- 24
		"float", -- 24
		360 -- 24
	}, -- 24
	BlendFuncDestination = { -- 25
		"D", -- 25
		"BlendFunc", -- 25
		BlendFunc:get("One"), -- 25
		"One" -- 25
	}, -- 25
	BlendFuncSource = { -- 26
		"E", -- 26
		" BlendFunc", -- 26
		BlendFunc:get("SrcAlpha"), -- 26
		"SrcAlpha" -- 26
	}, -- 26
	Duration = { -- 27
		"F", -- 27
		"floatN", -- 27
		-1 -- 27
	}, -- 27
	EmissionRate = { -- 28
		"G", -- 28
		"float", -- 28
		350 -- 28
	}, -- 28
	FinishColor = { -- 29
		"H", -- 29
		"Color", -- 29
		Color(0xff000000) -- 29
	}, -- 29
	FinishColorVariance = { -- 30
		"I", -- 30
		"Color", -- 30
		Color(0x0) -- 30
	}, -- 30
	RotationStart = { -- 31
		"J", -- 31
		"float", -- 31
		0 -- 31
	}, -- 31
	RotationStartVariance = { -- 32
		"K", -- 32
		"float", -- 32
		0 -- 32
	}, -- 32
	RotationEnd = { -- 33
		"L", -- 33
		"float", -- 33
		0 -- 33
	}, -- 33
	RotationEndVariance = { -- 34
		"M", -- 34
		"float", -- 34
		0 -- 34
	}, -- 34
	FinishParticleSize = { -- 35
		"N", -- 35
		"floatN", -- 35
		-1 -- 35
	}, -- 35
	FinishParticleSizeVariance = { -- 36
		"O", -- 36
		"float", -- 36
		0 -- 36
	}, -- 36
	MaxParticles = { -- 37
		"P", -- 37
		"Uint32", -- 37
		100 -- 37
	}, -- 37
	ParticleLifespan = { -- 38
		"Q", -- 38
		"float", -- 38
		1 -- 38
	}, -- 38
	ParticleLifespanVariance = { -- 39
		"R", -- 39
		"float", -- 39
		0.5 -- 39
	}, -- 39
	StartPosition = { -- 40
		"S", -- 40
		"Vec2", -- 40
		Vec2(0, 0) -- 40
	}, -- 40
	StartPositionVariance = { -- 41
		"T", -- 41
		"Vec2", -- 41
		Vec2(0, 0) -- 41
	}, -- 41
	StartColor = { -- 42
		"U", -- 42
		"Color", -- 42
		Color(194, 64, 31, 255) -- 42
	}, -- 42
	StartColorVariance = { -- 43
		"V", -- 43
		"Color", -- 43
		Color(0x0) -- 43
	}, -- 43
	StartParticleSize = { -- 44
		"W", -- 44
		"float", -- 44
		30 -- 44
	}, -- 44
	StartParticleSizeVariance = { -- 45
		"X", -- 45
		"float", -- 45
		10 -- 45
	}, -- 45
	TextureName = { -- 46
		"Y", -- 46
		"string", -- 46
		"", -- 46
		Buffer(256) -- 46
	}, -- 46
	TextureRect = { -- 47
		"Z", -- 47
		"Rect", -- 47
		Rect(0, 0, 0, 0) -- 47
	}, -- 47
	EmitterType = { -- 48
		"a", -- 48
		"EmitterType", -- 48
		0 -- 48
	} -- 48
} -- 22
local Gravity = { -- 50
	RotationIsDir = { -- 50
		"b", -- 50
		"bool", -- 50
		false -- 50
	}, -- 50
	Gravity = { -- 51
		"c", -- 51
		"Vec2", -- 51
		Vec2(0, 100) -- 51
	}, -- 51
	Speed = { -- 52
		"d", -- 52
		"float", -- 52
		20 -- 52
	}, -- 52
	SpeedVariance = { -- 53
		"e", -- 53
		"float", -- 53
		5 -- 53
	}, -- 53
	RadialAcceleration = { -- 54
		"f", -- 54
		"float", -- 54
		0 -- 54
	}, -- 54
	RadialAccelVariance = { -- 55
		"g", -- 55
		"float", -- 55
		0 -- 55
	}, -- 55
	TangentialAcceleration = { -- 56
		"h", -- 56
		"float", -- 56
		0 -- 56
	}, -- 56
	TangentialAccelVariance = { -- 57
		"i", -- 57
		"float", -- 57
		0 -- 57
	} -- 57
} -- 49
local Radius = { -- 59
	StartRadius = { -- 59
		"j", -- 59
		"float", -- 59
		0 -- 59
	}, -- 59
	StartRadiusVariance = { -- 60
		"k", -- 60
		"float", -- 60
		0 -- 60
	}, -- 60
	FinishRadius = { -- 61
		"l", -- 61
		"floatN", -- 61
		-1 -- 61
	}, -- 61
	FinishRadiusVariance = { -- 62
		"m", -- 62
		"float", -- 62
		0 -- 62
	}, -- 62
	RotatePerSecond = { -- 63
		"n", -- 63
		"float", -- 63
		0 -- 63
	}, -- 63
	RotatePerSecondVariance = { -- 64
		"o", -- 64
		"float", -- 64
		0 -- 64
	} -- 64
} -- 58
local toString -- 66
toString = function(value) -- 66
	local _exp_0 = tolua.type(value) -- 67
	if "number" == _exp_0 then -- 68
		return tostring(value) -- 69
	elseif "string" == _exp_0 then -- 70
		return value -- 71
	elseif "Rect" == _exp_0 then -- 72
		return tostring(value.x) .. "," .. tostring(value.y) .. "," .. tostring(value.width) .. "," .. tostring(value.height) -- 73
	elseif "boolean" == _exp_0 then -- 74
		return value and "1" or "0" -- 75
	elseif "Vec2" == _exp_0 then -- 76
		return tostring(value.x) .. "," .. tostring(value.y) -- 77
	elseif "Color" == _exp_0 then -- 78
		return string.format("%.2f,%.2f,%.2f,%.2f", value.r / 255, value.g / 255, value.b / 255, value.a / 255) -- 79
	end -- 67
end -- 66
local _anon_func_1 = function(Data, Gravity, Radius, emitterType) -- 82
	local _tab_0 = { } -- 82
	local _idx_0 = 1 -- 82
	for _key_0, _value_0 in pairs(Data) do -- 82
		if _idx_0 == _key_0 then -- 82
			_tab_0[#_tab_0 + 1] = _value_0 -- 82
			_idx_0 = _idx_0 + 1 -- 82
		else -- 82
			_tab_0[_key_0] = _value_0 -- 82
		end -- 82
	end -- 82
	local _obj_0 = (emitterType == 1 and Gravity or Radius) -- 82
	local _idx_1 = 1 -- 82
	for _key_0, _value_0 in pairs(_obj_0) do -- 82
		if _idx_1 == _key_0 then -- 82
			_tab_0[#_tab_0 + 1] = _value_0 -- 82
			_idx_1 = _idx_1 + 1 -- 82
		else -- 82
			_tab_0[_key_0] = _value_0 -- 82
		end -- 82
	end -- 82
	return _tab_0 -- 82
end -- 82
local _anon_func_0 = function(Data, Gravity, Radius, emitterType, toString) -- 82
	local _accum_0 = { } -- 82
	local _len_0 = 1 -- 82
	for k, v in pairs(_anon_func_1(Data, Gravity, Radius, emitterType)) do -- 82
		_accum_0[_len_0] = "\n\t<" .. tostring(v[1]) .. " A=\"" .. tostring(toString(v[3])) .. "\"/>" -- 82
		_len_0 = _len_0 + 1 -- 82
	end -- 82
	return _accum_0 -- 82
end -- 82
local getParticle -- 81
getParticle = function() -- 81
	return "<A>" .. table.concat(_anon_func_0(Data, Gravity, Radius, emitterType, toString)) .. "\n</A>" -- 82
end -- 81
Cache:update("__test__.par", getParticle()) -- 84
local particle -- 86
do -- 86
	local _with_0 = Particle("__test__.par") -- 86
	_with_0:start() -- 87
	particle = _with_0 -- 86
end -- 86
local root -- 89
do -- 89
	local _with_0 = Node() -- 89
	_with_0.scaleX = 2 -- 90
	_with_0.scaleY = 2 -- 91
	_with_0:addChild(particle) -- 92
	_with_0:onTapMoved(function(touch) -- 93
		if not touch.first then -- 94
			return -- 94
		end -- 94
		particle.position = particle.position + (touch.delta / 2) -- 95
	end) -- 93
	root = _with_0 -- 89
end -- 89
local DataDirty = false -- 99
local Item -- 101
Item = function(name, data) -- 101
	local _with_0 = data[name] -- 101
	local _exp_0 = _with_0[2] -- 101
	if "float" == _exp_0 then -- 102
		local changed -- 103
		changed, _with_0[3] = DragFloat(name, _with_0[3], 0.1, -1000, 1000, "%.1f") -- 103
		if changed then -- 103
			DataDirty = true -- 104
		end -- 103
	elseif "floatN" == _exp_0 then -- 105
		local changed -- 106
		changed, _with_0[3] = DragFloat(name, _with_0[3], 0.1, -1, 1000, "%.1f") -- 106
		if changed then -- 106
			DataDirty = true -- 107
		end -- 106
	elseif "Uint32" == _exp_0 then -- 108
		local changed -- 109
		changed, _with_0[3] = DragInt(name, math.floor(_with_0[3]), 1, 0, 1000) -- 109
		if changed then -- 109
			DataDirty = true -- 110
		end -- 109
	elseif "EmitterType" == _exp_0 then -- 111
		do -- 112
			local changed -- 112
			changed, emitterType = Combo("EmitterType", emitterType, emitterTypes) -- 112
			if changed then -- 112
				_with_0[3] = emitterType == 1 and 0 or 1 -- 113
			end -- 112
		end -- 112
		PushItemWidth(-180, function() -- 114
			if emitterType == 1 then -- 115
				for k in pairs(Gravity) do -- 116
					Item(k, Gravity) -- 116
				end -- 116
			else -- 118
				for k in pairs(Radius) do -- 118
					Item(k, Radius) -- 118
				end -- 118
			end -- 115
		end) -- 114
	elseif "BlendFunc" == _exp_0 then -- 119
		if name == "BlendFuncDestination" then -- 120
			local changed -- 121
			changed, blendFuncDst = Combo("BlendFuncDestination", blendFuncDst, blendFuncs) -- 121
			if changed then -- 121
				_with_0[3] = BlendFunc:get(blendFuncs[blendFuncDst]) -- 122
				_with_0[4] = blendFuncs[blendFuncDst] -- 123
			end -- 121
		elseif name == "BlendFuncSource" then -- 124
			local changed -- 125
			changed, blendFuncSrc = Combo("BlendFuncSource", blendFuncSrc, blendFuncs) -- 125
			if changed then -- 125
				_with_0[3] = BlendFunc:get(blendFuncs[blendFuncSrc]) -- 126
				_with_0[4] = blendFuncs[blendFuncSrc] -- 127
			end -- 125
		end -- 120
	elseif "Vec2" == _exp_0 then -- 128
		local x, y -- 129
		do -- 129
			local _obj_0 = _with_0[3] -- 129
			x, y = _obj_0.x, _obj_0.y -- 129
		end -- 129
		local changed -- 130
		changed, x, y = DragInt2(name, math.floor(x), math.floor(y), 1, -1000, 1000) -- 130
		if changed then -- 130
			DataDirty, _with_0[3] = true, Vec2(x, y) -- 131
		end -- 130
	elseif "Color" == _exp_0 then -- 132
		PushItemWidth(-150, function() -- 133
			SetColorEditOptions({ -- 134
				"DisplayRGB" -- 134
			}) -- 134
			local changed = ColorEdit4(name, _with_0[3]) -- 135
			if changed then -- 135
				DataDirty = true -- 136
			end -- 135
		end) -- 133
	elseif "bool" == _exp_0 then -- 137
		local changed -- 138
		changed, _with_0[3] = Checkbox(name, _with_0[3]) -- 138
		if changed then -- 138
			DataDirty = true -- 139
		end -- 138
	elseif "string" == _exp_0 then -- 140
		local buffer = _with_0[4] -- 141
		local changed = InputText(name, buffer) -- 142
		if changed then -- 142
			DataDirty = true -- 143
			_with_0[3] = buffer.text -- 144
		end -- 142
	end -- 101
	return _with_0 -- 101
end -- 101
local refresh = coroutine.wrap(function() -- 146
	while true do -- 146
		sleep(1) -- 147
		if DataDirty then -- 148
			DataDirty = false -- 149
			Cache:update("__test__.par", getParticle()) -- 150
			particle:removeFromParent() -- 151
			local _with_0 = Particle("__test__.par") -- 152
			_with_0:start() -- 153
			_with_0:addTo(particle) -- 154
			particle = _with_0 -- 152
		end -- 148
	end -- 146
end) -- 146
local buffer = Buffer(5000) -- 157
local windowFlags = { -- 158
	"NoResize", -- 158
	"NoSavedSettings" -- 158
} -- 158
return threadLoop(function() -- 159
	local width, height -- 160
	do -- 160
		local _obj_0 = App.visualSize -- 160
		width, height = _obj_0.width, _obj_0.height -- 160
	end -- 160
	SetNextWindowPos(Vec2(width - 400, 10), "FirstUseEver") -- 161
	SetNextWindowSize(Vec2(390, height - 80), "FirstUseEver") -- 162
	Begin("Particle", windowFlags, function() -- 163
		PushItemWidth(-180, function() -- 164
			for k in pairs(Data) do -- 165
				Item(k, Data) -- 166
			end -- 165
		end) -- 164
		if Button("Export") then -- 167
			buffer.text = getParticle() -- 168
		end -- 167
		SameLine() -- 169
		return PushItemWidth(-1, function() -- 170
			return InputTextMultiline("###Edited", buffer) -- 171
		end) -- 170
	end) -- 163
	return refresh() -- 172
end) -- 159
