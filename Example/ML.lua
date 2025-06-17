-- [yue]: Example/ML.yue
local App = Dora.App -- 1
local table = _G.table -- 1
local ML = Dora.ML -- 1
local math = _G.math -- 1
local pairs = _G.pairs -- 1
local threadLoop = Dora.threadLoop -- 1
local _module_0 = Dora.ImGui -- 1
local SetNextWindowPos = _module_0.SetNextWindowPos -- 1
local Vec2 = Dora.Vec2 -- 1
local SetNextWindowSize = _module_0.SetNextWindowSize -- 1
local Begin = _module_0.Begin -- 1
local Text = _module_0.Text -- 1
local Separator = _module_0.Separator -- 1
local TextWrapped = _module_0.TextWrapped -- 1
local tostring = _G.tostring -- 1
local Button = _module_0.Button -- 1
local SameLine = _module_0.SameLine -- 1
local Checkbox = _module_0.Checkbox -- 1
local thread = Dora.thread -- 1
local string = _G.string -- 1
local actions = { -- 4
	"观察", -- 4
	"侦查", -- 4
	"攀爬", -- 4
	"挥舞", -- 4
	"攻击", -- 4
	"破坏", -- 4
	"投掷", -- 4
	"采集", -- 4
	"挖掘", -- 4
	"采收", -- 4
	"沟通", -- 4
	"鼓舞", -- 4
	"恐吓" -- 4
} -- 4
local relationTags = { -- 6
	"友善", -- 6
	"中立", -- 6
	"敌对" -- 6
} -- 6
local bodyTypes = { -- 8
	"大型", -- 8
	"巨型" -- 8
} -- 8
local skills = { -- 10
	"迅速Lv1", -- 10
	"迅速Lv2" -- 10
} -- 10
local unitTags = { -- 12
	"生物", -- 12
	"挖掘资源", -- 12
	"采集资源", -- 12
	"可破坏", -- 12
	"可攀爬", -- 12
	"飞行" -- 12
} -- 12
local effectNames = { -- 14
	"揭示", -- 14
	"伤害", -- 14
	"破坏", -- 14
	"采集", -- 14
	"擒抱", -- 14
	"攀爬", -- 14
	"交涉", -- 14
	"恐吓" -- 14
} -- 14
local actionEffects = { -- 17
	["观察"] = { -- 18
		["生物"] = { -- 18
			"揭示", -- 18
			0, -- 18
			1 -- 18
		}, -- 18
		["友善"] = { -- 19
			"揭示", -- 19
			0, -- 19
			1 -- 19
		}, -- 19
		["中立"] = { -- 20
			"揭示", -- 20
			0, -- 20
			1 -- 20
		}, -- 20
		["敌对"] = { -- 21
			"揭示", -- 21
			0, -- 21
			1 -- 21
		}, -- 21
		["挖掘资源"] = { -- 22
			"揭示", -- 22
			0, -- 22
			1 -- 22
		}, -- 22
		["采集资源"] = { -- 23
			"揭示", -- 23
			0, -- 23
			1 -- 23
		}, -- 23
		["可破坏"] = { -- 24
			"揭示", -- 24
			0, -- 24
			1 -- 24
		}, -- 24
		["可攀爬"] = { -- 25
			"揭示", -- 25
			0, -- 25
			1 -- 25
		}, -- 25
		["巨型"] = { -- 26
			"揭示", -- 26
			0, -- 26
			0 -- 26
		}, -- 26
		["迅速Lv2"] = { -- 27
			"揭示", -- 27
			0, -- 27
			0 -- 27
		} -- 27
	}, -- 17
	["侦查"] = { -- 30
		["生物"] = { -- 30
			"揭示", -- 30
			1, -- 30
			1 -- 30
		}, -- 30
		["挖掘资源"] = { -- 31
			"揭示", -- 31
			1, -- 31
			1 -- 31
		}, -- 31
		["采集资源"] = { -- 32
			"揭示", -- 32
			1, -- 32
			1 -- 32
		}, -- 32
		["可破坏"] = { -- 33
			"揭示", -- 33
			1, -- 33
			1 -- 33
		}, -- 33
		["可攀爬"] = { -- 34
			"揭示", -- 34
			1, -- 34
			1 -- 34
		}, -- 34
		["飞行"] = { -- 35
			"揭示", -- 35
			1, -- 35
			1 -- 35
		}, -- 35
		["大型"] = { -- 36
			"揭示", -- 36
			1, -- 36
			1 -- 36
		}, -- 36
		["巨型"] = { -- 37
			"揭示", -- 37
			1, -- 37
			1 -- 37
		}, -- 37
		["迅速Lv1"] = { -- 38
			"揭示", -- 38
			1, -- 38
			1 -- 38
		}, -- 38
		["迅速Lv2"] = { -- 39
			"揭示", -- 39
			1, -- 39
			1 -- 39
		} -- 39
	}, -- 29
	["攀爬"] = { -- 42
		["友善"] = { -- 42
			"擒抱", -- 42
			0, -- 42
			1 -- 42
		}, -- 42
		["中立"] = { -- 43
			"擒抱", -- 43
			0, -- 43
			1 -- 43
		}, -- 43
		["可攀爬"] = { -- 44
			"攀爬", -- 44
			1, -- 44
			1 -- 44
		}, -- 44
		["大型"] = { -- 45
			"攀爬", -- 45
			1, -- 45
			1 -- 45
		}, -- 45
		["巨型"] = { -- 46
			"攀爬", -- 46
			1, -- 46
			1 -- 46
		} -- 46
	}, -- 41
	["挥舞"] = { -- 49
		["生物"] = { -- 49
			"伤害", -- 49
			0, -- 49
			1 -- 49
		}, -- 49
		["友善"] = { -- 50
			"取消伤害" -- 50
		}, -- 50
		["中立"] = { -- 51
			"取消伤害" -- 51
		}, -- 51
		["敌对"] = { -- 52
			"伤害", -- 52
			0, -- 52
			1 -- 52
		}, -- 52
		["挖掘资源"] = { -- 53
			"采集", -- 53
			0, -- 53
			1 -- 53
		}, -- 53
		["采集资源"] = { -- 54
			"采集", -- 54
			0, -- 54
			1 -- 54
		}, -- 54
		["可破坏"] = { -- 55
			"破坏", -- 55
			0, -- 55
			1 -- 55
		}, -- 55
		["可攀爬"] = { -- 56
			"破坏", -- 56
			0, -- 56
			1 -- 56
		}, -- 56
		["飞行"] = { -- 57
			"伤害", -- 57
			-1, -- 57
			1 -- 57
		}, -- 57
		["大型"] = { -- 58
			"伤害", -- 58
			0, -- 58
			1 -- 58
		}, -- 58
		["巨型"] = { -- 59
			"伤害", -- 59
			0, -- 59
			1 -- 59
		}, -- 59
		["迅速Lv1"] = { -- 60
			"伤害", -- 60
			0, -- 60
			0 -- 60
		}, -- 60
		["迅速Lv2"] = { -- 61
			"伤害", -- 61
			0, -- 61
			0 -- 61
		} -- 61
	}, -- 48
	["攻击"] = { -- 64
		["生物"] = { -- 64
			"伤害", -- 64
			1, -- 64
			1 -- 64
		}, -- 64
		["友善"] = { -- 65
			"取消伤害" -- 65
		}, -- 65
		["中立"] = { -- 66
			"伤害", -- 66
			0, -- 66
			1 -- 66
		}, -- 66
		["敌对"] = { -- 67
			"伤害", -- 67
			1, -- 67
			1 -- 67
		}, -- 67
		["挖掘资源"] = { -- 68
			"破坏", -- 68
			0, -- 68
			1 -- 68
		}, -- 68
		["采集资源"] = { -- 69
			"采集", -- 69
			0, -- 69
			1 -- 69
		}, -- 69
		["可破坏"] = { -- 70
			"破坏", -- 70
			1, -- 70
			1 -- 70
		}, -- 70
		["飞行"] = { -- 71
			"伤害", -- 71
			-1, -- 71
			1 -- 71
		}, -- 71
		["大型"] = { -- 72
			"伤害", -- 72
			1, -- 72
			1 -- 72
		}, -- 72
		["巨型"] = { -- 73
			"伤害", -- 73
			1, -- 73
			1 -- 73
		}, -- 73
		["迅速Lv1"] = { -- 74
			"伤害", -- 74
			0, -- 74
			1 -- 74
		}, -- 74
		["迅速Lv2"] = { -- 75
			"伤害", -- 75
			0, -- 75
			1 -- 75
		} -- 75
	}, -- 63
	["破坏"] = { -- 78
		["生物"] = { -- 78
			"伤害", -- 78
			0, -- 78
			1 -- 78
		}, -- 78
		["友善"] = { -- 79
			"取消伤害" -- 79
		}, -- 79
		["中立"] = { -- 80
			"伤害", -- 80
			0, -- 80
			1 -- 80
		}, -- 80
		["敌对"] = { -- 81
			"伤害", -- 81
			0, -- 81
			1 -- 81
		}, -- 81
		["挖掘资源"] = { -- 82
			"采集", -- 82
			0, -- 82
			1 -- 82
		}, -- 82
		["采集资源"] = { -- 83
			"破坏", -- 83
			1, -- 83
			1 -- 83
		}, -- 83
		["可破坏"] = { -- 84
			"破坏", -- 84
			1, -- 84
			1 -- 84
		}, -- 84
		["巨型"] = { -- 85
			"伤害", -- 85
			1, -- 85
			1 -- 85
		}, -- 85
		["迅速Lv1"] = { -- 86
			"伤害", -- 86
			0, -- 86
			0 -- 86
		}, -- 86
		["迅速Lv2"] = { -- 87
			"伤害", -- 87
			0, -- 87
			0 -- 87
		} -- 87
	}, -- 77
	["投掷"] = { -- 90
		["生物"] = { -- 90
			"伤害", -- 90
			1, -- 90
			1 -- 90
		}, -- 90
		["友善"] = { -- 91
			"取消伤害" -- 91
		}, -- 91
		["中立"] = { -- 92
			"伤害", -- 92
			0, -- 92
			1 -- 92
		}, -- 92
		["敌对"] = { -- 93
			"伤害", -- 93
			1, -- 93
			1 -- 93
		}, -- 93
		["可破坏"] = { -- 94
			"破坏", -- 94
			1, -- 94
			1 -- 94
		}, -- 94
		["飞行"] = { -- 95
			"伤害", -- 95
			1, -- 95
			1 -- 95
		}, -- 95
		["大型"] = { -- 96
			"伤害", -- 96
			1, -- 96
			1 -- 96
		}, -- 96
		["巨型"] = { -- 97
			"伤害", -- 97
			1, -- 97
			1 -- 97
		}, -- 97
		["迅速Lv1"] = { -- 98
			"伤害", -- 98
			0, -- 98
			1 -- 98
		}, -- 98
		["迅速Lv2"] = { -- 99
			"伤害", -- 99
			0, -- 99
			1 -- 99
		} -- 99
	}, -- 89
	["采集"] = { -- 102
		["生物"] = { -- 102
			"伤害", -- 102
			0, -- 102
			1 -- 102
		}, -- 102
		["友善"] = { -- 103
			"伤害", -- 103
			0, -- 103
			1 -- 103
		}, -- 103
		["中立"] = { -- 104
			"伤害", -- 104
			0, -- 104
			1 -- 104
		}, -- 104
		["敌对"] = { -- 105
			"伤害", -- 105
			0, -- 105
			1 -- 105
		}, -- 105
		["挖掘资源"] = { -- 106
			"采集", -- 106
			0, -- 106
			1 -- 106
		}, -- 106
		["采集资源"] = { -- 107
			"采集", -- 107
			0, -- 107
			1 -- 107
		}, -- 107
		["可破坏"] = { -- 108
			"揭示", -- 108
			0, -- 108
			1 -- 108
		}, -- 108
		["可攀爬"] = { -- 109
			"揭示", -- 109
			0, -- 109
			1 -- 109
		}, -- 109
		["大型"] = { -- 110
			"伤害", -- 110
			0, -- 110
			1 -- 110
		} -- 110
	}, -- 101
	["挖掘"] = { -- 113
		["挖掘资源"] = { -- 113
			"采集", -- 113
			1, -- 113
			1 -- 113
		}, -- 113
		["采集资源"] = { -- 114
			"采集", -- 114
			0, -- 114
			1 -- 114
		}, -- 114
		["可破坏"] = { -- 115
			"破坏", -- 115
			1, -- 115
			1 -- 115
		}, -- 115
		["可攀爬"] = { -- 116
			"破坏", -- 116
			0, -- 116
			1 -- 116
		} -- 116
	}, -- 112
	["采收"] = { -- 119
		["友善"] = { -- 119
			"采集", -- 119
			0, -- 119
			1 -- 119
		}, -- 119
		["挖掘资源"] = { -- 120
			"采集", -- 120
			0, -- 120
			1 -- 120
		}, -- 120
		["采集资源"] = { -- 121
			"采集", -- 121
			1, -- 121
			1 -- 121
		} -- 121
	}, -- 118
	["沟通"] = { -- 124
		["生物"] = { -- 124
			"揭示", -- 124
			0, -- 124
			1 -- 124
		}, -- 124
		["友善"] = { -- 125
			"交涉", -- 125
			0, -- 125
			1 -- 125
		}, -- 125
		["中立"] = { -- 126
			"交涉", -- 126
			0, -- 126
			1 -- 126
		}, -- 126
		["敌对"] = { -- 127
			"揭示", -- 127
			0, -- 127
			1 -- 127
		}, -- 127
		["挖掘资源"] = { -- 128
			"揭示", -- 128
			0, -- 128
			1 -- 128
		}, -- 128
		["采集资源"] = { -- 129
			"揭示", -- 129
			0, -- 129
			1 -- 129
		}, -- 129
		["巨型"] = { -- 130
			"交涉", -- 130
			0, -- 130
			0 -- 130
		} -- 130
	}, -- 123
	["鼓舞"] = { -- 133
		["友善"] = { -- 133
			"交涉", -- 133
			0, -- 133
			1 -- 133
		}, -- 133
		["中立"] = { -- 134
			"交涉", -- 134
			0, -- 134
			1 -- 134
		} -- 134
	}, -- 132
	["恐吓"] = { -- 137
		["生物"] = { -- 137
			"恐吓", -- 137
			1, -- 137
			1 -- 137
		}, -- 137
		["友善"] = { -- 138
			"恐吓", -- 138
			1, -- 138
			1 -- 138
		}, -- 138
		["中立"] = { -- 139
			"恐吓", -- 139
			1, -- 139
			1 -- 139
		}, -- 139
		["敌对"] = { -- 140
			"恐吓", -- 140
			1, -- 140
			1 -- 140
		}, -- 140
		["飞行"] = { -- 141
			"恐吓", -- 141
			1, -- 141
			1 -- 141
		}, -- 141
		["大型"] = { -- 142
			"恐吓", -- 142
			0, -- 142
			1 -- 142
		} -- 142
	} -- 136
} -- 16
local newCreature -- 146
newCreature = function() -- 146
	local hints = { } -- 147
	local values = { } -- 148
	local tags = { } -- 149
	local record = { } -- 150
	local relationIndex = App.rand % #relationTags -- 151
	tags[#tags + 1] = relationTags[relationIndex + 1] -- 152
	hints[#hints + 1] = #relationTags -- 153
	values[#values + 1] = relationIndex -- 154
	record[#record + 1] = relationTags[relationIndex + 1] -- 155
	local bodyTypeIndex = App.rand % (#bodyTypes + 1) -- 156
	if bodyTypeIndex ~= 0 then -- 157
		tags[#tags + 1] = bodyTypes[bodyTypeIndex] -- 158
		record[#record + 1] = bodyTypes[bodyTypeIndex] -- 159
	else -- 161
		record[#record + 1] = "无" -- 161
	end -- 157
	hints[#hints + 1] = #bodyTypes + 1 -- 162
	values[#values + 1] = bodyTypeIndex -- 163
	local skillIndex = App.rand % (#skills + 1) -- 164
	if skillIndex ~= 0 then -- 165
		tags[#tags + 1] = skills[skillIndex] -- 166
		record[#record + 1] = skills[skillIndex] -- 167
	else -- 169
		record[#record + 1] = "无" -- 169
	end -- 165
	hints[#hints + 1] = #skills + 1 -- 170
	values[#values + 1] = skillIndex -- 171
	for i = 1, #unitTags do -- 172
		hints[#hints + 1] = 2 -- 173
		if App.rand % 2 == 1 then -- 174
			tags[#tags + 1] = unitTags[i] -- 175
			values[#values + 1] = 1 -- 176
			record[#record + 1] = "有" -- 177
		else -- 179
			values[#values + 1] = 0 -- 179
			record[#record + 1] = "无" -- 180
		end -- 174
	end -- 180
	return { -- 182
		name = table.concat(tags, ","), -- 182
		tags = tags, -- 183
		hints = hints, -- 184
		values = values, -- 185
		record = record -- 186
	} -- 187
end -- 146
local ql = ML.QLearner() -- 189
local getEffect -- 191
getEffect = function(tags, action) -- 191
	local effects = actionEffects[actions[action]] -- 192
	local cancelHarm = false -- 193
	local eset = { } -- 194
	for _index_0 = 1, #tags do -- 195
		local tag = tags[_index_0] -- 195
		local eff = effects[tag] -- 196
		if not eff then -- 197
			goto _continue_0 -- 197
		end -- 197
		if eff[1] == "取消伤害" then -- 198
			cancelHarm = true -- 199
		else -- 201
			local e = eset[eff[1]] -- 201
			if e then -- 201
				local _update_0 = 1 -- 202
				e[_update_0] = e[_update_0] + eff[2] -- 202
				e[2] = math.max(e[2], eff[3]) -- 203
			else -- 205
				eset[eff[1]] = { -- 205
					eff[2], -- 205
					eff[3] -- 205
				} -- 205
			end -- 201
		end -- 198
		::_continue_0:: -- 196
	end -- 205
	if cancelHarm then -- 206
		eset["伤害"] = nil -- 207
	end -- 206
	local _accum_0 = { } -- 208
	local _len_0 = 1 -- 208
	for k, v in pairs(eset) do -- 208
		local p = math.min(100, 50 + 20 * v[1]) -- 209
		if (1 + App.rand % 100) <= p then -- 210
			_accum_0[_len_0] = { -- 211
				k, -- 211
				v[2] -- 211
			} -- 211
			_len_0 = _len_0 + 1 -- 209
		else -- 212
			goto _continue_1 -- 212
		end -- 210
		::_continue_1:: -- 209
	end -- 212
	return _accum_0 -- 212
end -- 191
local newRoundTraining -- 214
newRoundTraining = function() -- 214
	local result = { } -- 215
	while #result == 0 do -- 216
		local unit = newCreature() -- 217
		local state = ML.QLearner:pack(unit.hints, unit.values) -- 218
		local action = ql:getBestAction(state) -- 219
		local randomAction = false -- 220
		if action == 0 then -- 221
			randomAction = true -- 222
			action = App.rand % #actions + 1 -- 223
		end -- 221
		do -- 224
			local _obj_0 = unit.record -- 224
			_obj_0[#_obj_0 + 1] = actions[action] -- 224
		end -- 224
		result = getEffect(unit.tags, action) -- 225
		if #result > 0 then -- 226
			return { -- 228
				name = unit.name, -- 228
				state = state, -- 229
				action = action, -- 230
				result = result, -- 231
				rand = randomAction, -- 232
				record = unit.record -- 233
			} -- 234
		else -- 236
			ql:update(state, action, -1) -- 236
		end -- 226
	end -- 236
end -- 214
local training = nil -- 238
local laborResult = nil -- 239
local effectFlags -- 240
do -- 240
	local _accum_0 = { } -- 240
	local _len_0 = 1 -- 240
	for i = 1, #effectNames do -- 240
		_accum_0[_len_0] = false -- 240
		_len_0 = _len_0 + 1 -- 240
	end -- 240
	effectFlags = _accum_0 -- 240
end -- 240
local manualOp = 0 -- 241
local selfTrained = false -- 242
local records = { -- 244
	{ -- 244
		"关系", -- 244
		"体型", -- 244
		"技能", -- 244
		"生物", -- 244
		"挖掘资源", -- 244
		"采集资源", -- 244
		"可破坏", -- 244
		"可攀爬", -- 244
		"飞行", -- 244
		"行动" -- 244
	}, -- 244
	{ -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C", -- 245
		"C" -- 245
	} -- 245
} -- 243
local decisionStr = nil -- 247
local windowFlags = { -- 249
	"NoResize", -- 249
	"NoSavedSettings", -- 249
	"NoMove", -- 249
	"NoCollapse", -- 249
	"NoDecoration", -- 249
	"NoNav", -- 249
	"AlwaysVerticalScrollbar", -- 249
	"NoSavedSettings" -- 249
} -- 249
local _anon_func_0 = function(tostring, training) -- 265
	local _accum_0 = { } -- 265
	local _len_0 = 1 -- 265
	local _list_0 = training.result -- 265
	for _index_0 = 1, #_list_0 do -- 265
		local item = _list_0[_index_0] -- 265
		_accum_0[_len_0] = tostring(item[1]) .. ":" .. tostring(item[2]) -- 265
		_len_0 = _len_0 + 1 -- 265
	end -- 265
	return _accum_0 -- 265
end -- 265
local _anon_func_1 = function(result, tostring) -- 301
	local _accum_0 = { } -- 301
	local _len_0 = 1 -- 301
	for _index_0 = 1, #result do -- 301
		local _des_0 = result[_index_0] -- 301
		local k, v = _des_0[1], _des_0[2] -- 301
		_accum_0[_len_0] = tostring(k) .. ":" .. tostring(v) -- 301
		_len_0 = _len_0 + 1 -- 301
	end -- 301
	return _accum_0 -- 301
end -- 301
local _anon_func_2 = function(effectFlags, effectNames) -- 307
	local _accum_0 = { } -- 307
	local _len_0 = 1 -- 307
	for i = 1, #effectFlags do -- 307
		if effectFlags[i] then -- 307
			_accum_0[_len_0] = effectNames[i] -- 307
			_len_0 = _len_0 + 1 -- 307
		end -- 307
	end -- 307
	return _accum_0 -- 307
end -- 307
local _anon_func_3 = function(records, table) -- 359
	local _accum_0 = { } -- 359
	local _len_0 = 1 -- 359
	for _index_0 = 1, #records do -- 359
		local r = records[_index_0] -- 359
		_accum_0[_len_0] = table.concat(r, ",") -- 359
		_len_0 = _len_0 + 1 -- 359
	end -- 359
	return _accum_0 -- 359
end -- 359
local _anon_func_4 = function(name, op, tostring, value) -- 363
	if name ~= "" then -- 363
		return "if " .. tostring(name) .. " " .. tostring(op) .. " " .. tostring(op == '==' and "\"" .. tostring(value) .. "\"" or value) -- 364
	else -- 366
		return tostring(op) .. " \"" .. tostring(value) .. "\"" -- 366
	end -- 363
end -- 363
return threadLoop(function() -- 255
	local width, height -- 256
	do -- 256
		local _obj_0 = App.visualSize -- 256
		width, height = _obj_0.width, _obj_0.height -- 256
	end -- 256
	SetNextWindowPos(Vec2.zero, "Always", Vec2.zero) -- 257
	SetNextWindowSize(Vec2(width, height - 50), "Always") -- 258
	return Begin("Fairy", windowFlags, function() -- 259
		Text("AI Fairy") -- 260
		Separator() -- 261
		if training then -- 262
			TextWrapped("生物: " .. tostring(training.name)) -- 263
			TextWrapped("执行动作: " .. tostring(actions[training.action])) -- 264
			TextWrapped("取得效果: " .. tostring(table.concat(_anon_func_0(tostring, training), ", "))) -- 265
			TextWrapped("手工训练记录数: " .. tostring(manualOp)) -- 266
			if training.rand then -- 267
				TextWrapped("[执行了随机动作]") -- 268
			else -- 270
				TextWrapped("[执行了已习得动作]") -- 270
			end -- 267
			if Button("表扬") then -- 271
				manualOp = manualOp + 1 -- 272
				ql:update(training.state, training.action, 1) -- 273
				training = newRoundTraining() -- 274
				records[#records + 1] = training.record -- 275
			end -- 271
			SameLine() -- 276
			if Button("批评") then -- 277
				manualOp = manualOp + 1 -- 278
				ql:update(training.state, training.action, -1) -- 279
				training = newRoundTraining() -- 280
			end -- 277
			SameLine() -- 281
			if Button("跳过") then -- 282
				training = newRoundTraining() -- 283
			end -- 282
		else -- 285
			if Button("开始人工训练") then -- 285
				training = newRoundTraining() -- 286
			end -- 285
		end -- 262
		Separator() -- 287
		if Button("对付100个随机生物") then -- 288
			local result = { } -- 289
			local validAction = 0 -- 290
			for i = 1, 100 do -- 291
				local res = newRoundTraining() -- 292
				if not res.rand then -- 293
					validAction = validAction + 1 -- 293
				end -- 293
				local _list_0 = res.result -- 294
				for _index_0 = 1, #_list_0 do -- 294
					local item = _list_0[_index_0] -- 294
					if result[item[1]] then -- 295
						local _update_0 = item[1] -- 296
						result[_update_0] = result[_update_0] + item[2] -- 296
					else -- 298
						result[item[1]] = item[2] -- 298
					end -- 295
				end -- 298
			end -- 298
			do -- 299
				local _accum_0 = { } -- 299
				local _len_0 = 1 -- 299
				for k, v in pairs(result) do -- 299
					_accum_0[_len_0] = { -- 299
						k, -- 299
						v -- 299
					} -- 299
					_len_0 = _len_0 + 1 -- 299
				end -- 299
				result = _accum_0 -- 299
			end -- 299
			table.sort(result, function(a, b) -- 300
				return b[2] < a[2] -- 300
			end) -- 300
			laborResult = table.concat(_anon_func_1(result, tostring), ", ") -- 301
			laborResult = laborResult .. "\n习得动作生效次数: " .. tostring(validAction) .. "/100" -- 302
		end -- 288
		if laborResult then -- 303
			TextWrapped(laborResult) -- 303
		end -- 303
		Separator() -- 304
		local doSelfTraining = false -- 305
		if selfTrained then -- 306
			local target = table.concat(_anon_func_2(effectFlags, effectNames), ", ") -- 307
			TextWrapped("已完成自我训练, 目标: " .. tostring(target)) -- 308
			if Button("遗忘") then -- 309
				selfTrained = false -- 310
				ql = ML.QLearner() -- 311
			end -- 309
		else -- 313
			TextWrapped("选择训练目标") -- 313
			for i = 1, #effectFlags do -- 314
				local _ -- 315
				_, effectFlags[i] = Checkbox(effectNames[i], effectFlags[i]) -- 315
			end -- 315
			doSelfTraining = Button("进行自我训练") -- 316
		end -- 306
		if doSelfTraining then -- 317
			selfTrained = true -- 318
			ql = ML.QLearner() -- 319
			local targetEffects -- 320
			do -- 320
				local _tbl_0 = { } -- 320
				for i = 1, #effectFlags do -- 320
					if effectFlags[i] then -- 320
						_tbl_0[effectNames[i]] = true -- 320
					end -- 320
				end -- 320
				targetEffects = _tbl_0 -- 320
			end -- 320
			local hints = { -- 322
				#relationTags, -- 322
				#bodyTypes + 1, -- 323
				#skills + 1 -- 324
			} -- 321
			for i = 1, #unitTags do -- 326
				hints[#hints + 1] = 2 -- 327
			end -- 327
			local l1 = #relationTags - 1 -- 328
			local l2 = #bodyTypes -- 329
			local l3 = #skills -- 330
			for i1 = 0, l1 do -- 331
				for i2 = 0, l2 do -- 331
					for i3 = 0, l3 do -- 331
						for i4 = 0, 1 do -- 332
							for i5 = 0, 1 do -- 332
								for i6 = 0, 1 do -- 332
									for i7 = 0, 1 do -- 333
										for i8 = 0, 1 do -- 333
											for i9 = 0, 1 do -- 333
												local tags = { } -- 334
												tags[#tags + 1] = relationTags[i1 + 1] -- 335
												local bodyTypeIndex = i2 -- 336
												if bodyTypeIndex ~= 0 then -- 337
													tags[#tags + 1] = bodyTypes[bodyTypeIndex] -- 338
												end -- 337
												local skillIndex = i3 -- 339
												if skillIndex ~= 0 then -- 340
													tags[#tags + 1] = skills[skillIndex] -- 341
												end -- 340
												if i4 ~= 0 then -- 342
													tags[#tags + 1] = unitTags[1] -- 342
												end -- 342
												if i5 ~= 0 then -- 343
													tags[#tags + 1] = unitTags[2] -- 343
												end -- 343
												if i6 ~= 0 then -- 344
													tags[#tags + 1] = unitTags[3] -- 344
												end -- 344
												if i7 ~= 0 then -- 345
													tags[#tags + 1] = unitTags[4] -- 345
												end -- 345
												if i8 ~= 0 then -- 346
													tags[#tags + 1] = unitTags[5] -- 346
												end -- 346
												if i9 ~= 0 then -- 347
													tags[#tags + 1] = unitTags[6] -- 347
												end -- 347
												local state = ML.QLearner:pack(hints, { -- 348
													i1, -- 348
													i2, -- 348
													i3, -- 348
													i4, -- 348
													i5, -- 348
													i6, -- 348
													i7, -- 348
													i8, -- 348
													i9 -- 348
												}) -- 348
												for action = 1, #actions do -- 349
													local result = getEffect(tags, action) -- 350
													local r = 0 -- 351
													for _index_0 = 1, #result do -- 352
														local _des_0 = result[_index_0] -- 352
														local k, v = _des_0[1], _des_0[2] -- 352
														if targetEffects[k] then -- 353
															r = r + v -- 354
														end -- 353
													end -- 354
													ql:update(state, action, r == 0 and -1 or r) -- 355
												end -- 355
											end -- 355
										end -- 355
									end -- 355
								end -- 355
							end -- 355
						end -- 355
					end -- 355
				end -- 355
			end -- 355
		end -- 317
		Separator() -- 356
		TextWrapped("总结人工训练思维逻辑") -- 357
		if Button("开始总结") and #records > 2 then -- 358
			local dataStr = table.concat(_anon_func_3(records, table), "\n") -- 359
			thread(function() -- 360
				local lines = { } -- 361
				ML.BuildDecisionTreeAsync(dataStr, 0, function(depth, name, op, value) -- 362
					local line = string.rep("\t", depth) .. _anon_func_4(name, op, tostring, value) -- 363
					lines[#lines + 1] = line -- 367
				end) -- 362
				decisionStr = table.concat(lines, "\n") -- 368
			end) -- 360
		end -- 358
		if decisionStr then -- 369
			return TextWrapped(decisionStr) -- 369
		end -- 369
	end) -- 369
end) -- 369
