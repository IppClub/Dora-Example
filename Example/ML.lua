-- [yue]: Example/ML.yue
local _ENV = Dora(Dora.ImGui) -- 2
local App <const> = App -- 3
local table <const> = table -- 3
local ML <const> = ML -- 3
local math <const> = math -- 3
local pairs <const> = pairs -- 3
local threadLoop <const> = threadLoop -- 3
local SetNextWindowPos <const> = SetNextWindowPos -- 3
local Vec2 <const> = Vec2 -- 3
local SetNextWindowSize <const> = SetNextWindowSize -- 3
local Begin <const> = Begin -- 3
local Text <const> = Text -- 3
local Separator <const> = Separator -- 3
local TextWrapped <const> = TextWrapped -- 3
local tostring <const> = tostring -- 3
local Button <const> = Button -- 3
local SameLine <const> = SameLine -- 3
local Checkbox <const> = Checkbox -- 3
local thread <const> = thread -- 3
local string <const> = string -- 3
local actions = { -- 5
	"观察", -- 5
	"侦查", -- 5
	"攀爬", -- 5
	"挥舞", -- 5
	"攻击", -- 5
	"破坏", -- 5
	"投掷", -- 5
	"采集", -- 5
	"挖掘", -- 5
	"采收", -- 5
	"沟通", -- 5
	"鼓舞", -- 5
	"恐吓" -- 5
} -- 5
local relationTags = { -- 7
	"友善", -- 7
	"中立", -- 7
	"敌对" -- 7
} -- 7
local bodyTypes = { -- 9
	"大型", -- 9
	"巨型" -- 9
} -- 9
local skills = { -- 11
	"迅速Lv1", -- 11
	"迅速Lv2" -- 11
} -- 11
local unitTags = { -- 13
	"生物", -- 13
	"挖掘资源", -- 13
	"采集资源", -- 13
	"可破坏", -- 13
	"可攀爬", -- 13
	"飞行" -- 13
} -- 13
local effectNames = { -- 15
	"揭示", -- 15
	"伤害", -- 15
	"破坏", -- 15
	"采集", -- 15
	"擒抱", -- 15
	"攀爬", -- 15
	"交涉", -- 15
	"恐吓" -- 15
} -- 15
local actionEffects = { -- 18
	["观察"] = { -- 19
		["生物"] = { -- 19
			"揭示", -- 19
			0, -- 19
			1 -- 19
		}, -- 19
		["友善"] = { -- 20
			"揭示", -- 20
			0, -- 20
			1 -- 20
		}, -- 20
		["中立"] = { -- 21
			"揭示", -- 21
			0, -- 21
			1 -- 21
		}, -- 21
		["敌对"] = { -- 22
			"揭示", -- 22
			0, -- 22
			1 -- 22
		}, -- 22
		["挖掘资源"] = { -- 23
			"揭示", -- 23
			0, -- 23
			1 -- 23
		}, -- 23
		["采集资源"] = { -- 24
			"揭示", -- 24
			0, -- 24
			1 -- 24
		}, -- 24
		["可破坏"] = { -- 25
			"揭示", -- 25
			0, -- 25
			1 -- 25
		}, -- 25
		["可攀爬"] = { -- 26
			"揭示", -- 26
			0, -- 26
			1 -- 26
		}, -- 26
		["巨型"] = { -- 27
			"揭示", -- 27
			0, -- 27
			0 -- 27
		}, -- 27
		["迅速Lv2"] = { -- 28
			"揭示", -- 28
			0, -- 28
			0 -- 28
		} -- 28
	}, -- 18
	["侦查"] = { -- 31
		["生物"] = { -- 31
			"揭示", -- 31
			1, -- 31
			1 -- 31
		}, -- 31
		["挖掘资源"] = { -- 32
			"揭示", -- 32
			1, -- 32
			1 -- 32
		}, -- 32
		["采集资源"] = { -- 33
			"揭示", -- 33
			1, -- 33
			1 -- 33
		}, -- 33
		["可破坏"] = { -- 34
			"揭示", -- 34
			1, -- 34
			1 -- 34
		}, -- 34
		["可攀爬"] = { -- 35
			"揭示", -- 35
			1, -- 35
			1 -- 35
		}, -- 35
		["飞行"] = { -- 36
			"揭示", -- 36
			1, -- 36
			1 -- 36
		}, -- 36
		["大型"] = { -- 37
			"揭示", -- 37
			1, -- 37
			1 -- 37
		}, -- 37
		["巨型"] = { -- 38
			"揭示", -- 38
			1, -- 38
			1 -- 38
		}, -- 38
		["迅速Lv1"] = { -- 39
			"揭示", -- 39
			1, -- 39
			1 -- 39
		}, -- 39
		["迅速Lv2"] = { -- 40
			"揭示", -- 40
			1, -- 40
			1 -- 40
		} -- 40
	}, -- 30
	["攀爬"] = { -- 43
		["友善"] = { -- 43
			"擒抱", -- 43
			0, -- 43
			1 -- 43
		}, -- 43
		["中立"] = { -- 44
			"擒抱", -- 44
			0, -- 44
			1 -- 44
		}, -- 44
		["可攀爬"] = { -- 45
			"攀爬", -- 45
			1, -- 45
			1 -- 45
		}, -- 45
		["大型"] = { -- 46
			"攀爬", -- 46
			1, -- 46
			1 -- 46
		}, -- 46
		["巨型"] = { -- 47
			"攀爬", -- 47
			1, -- 47
			1 -- 47
		} -- 47
	}, -- 42
	["挥舞"] = { -- 50
		["生物"] = { -- 50
			"伤害", -- 50
			0, -- 50
			1 -- 50
		}, -- 50
		["友善"] = { -- 51
			"取消伤害" -- 51
		}, -- 51
		["中立"] = { -- 52
			"取消伤害" -- 52
		}, -- 52
		["敌对"] = { -- 53
			"伤害", -- 53
			0, -- 53
			1 -- 53
		}, -- 53
		["挖掘资源"] = { -- 54
			"采集", -- 54
			0, -- 54
			1 -- 54
		}, -- 54
		["采集资源"] = { -- 55
			"采集", -- 55
			0, -- 55
			1 -- 55
		}, -- 55
		["可破坏"] = { -- 56
			"破坏", -- 56
			0, -- 56
			1 -- 56
		}, -- 56
		["可攀爬"] = { -- 57
			"破坏", -- 57
			0, -- 57
			1 -- 57
		}, -- 57
		["飞行"] = { -- 58
			"伤害", -- 58
			-1, -- 58
			1 -- 58
		}, -- 58
		["大型"] = { -- 59
			"伤害", -- 59
			0, -- 59
			1 -- 59
		}, -- 59
		["巨型"] = { -- 60
			"伤害", -- 60
			0, -- 60
			1 -- 60
		}, -- 60
		["迅速Lv1"] = { -- 61
			"伤害", -- 61
			0, -- 61
			0 -- 61
		}, -- 61
		["迅速Lv2"] = { -- 62
			"伤害", -- 62
			0, -- 62
			0 -- 62
		} -- 62
	}, -- 49
	["攻击"] = { -- 65
		["生物"] = { -- 65
			"伤害", -- 65
			1, -- 65
			1 -- 65
		}, -- 65
		["友善"] = { -- 66
			"取消伤害" -- 66
		}, -- 66
		["中立"] = { -- 67
			"伤害", -- 67
			0, -- 67
			1 -- 67
		}, -- 67
		["敌对"] = { -- 68
			"伤害", -- 68
			1, -- 68
			1 -- 68
		}, -- 68
		["挖掘资源"] = { -- 69
			"破坏", -- 69
			0, -- 69
			1 -- 69
		}, -- 69
		["采集资源"] = { -- 70
			"采集", -- 70
			0, -- 70
			1 -- 70
		}, -- 70
		["可破坏"] = { -- 71
			"破坏", -- 71
			1, -- 71
			1 -- 71
		}, -- 71
		["飞行"] = { -- 72
			"伤害", -- 72
			-1, -- 72
			1 -- 72
		}, -- 72
		["大型"] = { -- 73
			"伤害", -- 73
			1, -- 73
			1 -- 73
		}, -- 73
		["巨型"] = { -- 74
			"伤害", -- 74
			1, -- 74
			1 -- 74
		}, -- 74
		["迅速Lv1"] = { -- 75
			"伤害", -- 75
			0, -- 75
			1 -- 75
		}, -- 75
		["迅速Lv2"] = { -- 76
			"伤害", -- 76
			0, -- 76
			1 -- 76
		} -- 76
	}, -- 64
	["破坏"] = { -- 79
		["生物"] = { -- 79
			"伤害", -- 79
			0, -- 79
			1 -- 79
		}, -- 79
		["友善"] = { -- 80
			"取消伤害" -- 80
		}, -- 80
		["中立"] = { -- 81
			"伤害", -- 81
			0, -- 81
			1 -- 81
		}, -- 81
		["敌对"] = { -- 82
			"伤害", -- 82
			0, -- 82
			1 -- 82
		}, -- 82
		["挖掘资源"] = { -- 83
			"采集", -- 83
			0, -- 83
			1 -- 83
		}, -- 83
		["采集资源"] = { -- 84
			"破坏", -- 84
			1, -- 84
			1 -- 84
		}, -- 84
		["可破坏"] = { -- 85
			"破坏", -- 85
			1, -- 85
			1 -- 85
		}, -- 85
		["巨型"] = { -- 86
			"伤害", -- 86
			1, -- 86
			1 -- 86
		}, -- 86
		["迅速Lv1"] = { -- 87
			"伤害", -- 87
			0, -- 87
			0 -- 87
		}, -- 87
		["迅速Lv2"] = { -- 88
			"伤害", -- 88
			0, -- 88
			0 -- 88
		} -- 88
	}, -- 78
	["投掷"] = { -- 91
		["生物"] = { -- 91
			"伤害", -- 91
			1, -- 91
			1 -- 91
		}, -- 91
		["友善"] = { -- 92
			"取消伤害" -- 92
		}, -- 92
		["中立"] = { -- 93
			"伤害", -- 93
			0, -- 93
			1 -- 93
		}, -- 93
		["敌对"] = { -- 94
			"伤害", -- 94
			1, -- 94
			1 -- 94
		}, -- 94
		["可破坏"] = { -- 95
			"破坏", -- 95
			1, -- 95
			1 -- 95
		}, -- 95
		["飞行"] = { -- 96
			"伤害", -- 96
			1, -- 96
			1 -- 96
		}, -- 96
		["大型"] = { -- 97
			"伤害", -- 97
			1, -- 97
			1 -- 97
		}, -- 97
		["巨型"] = { -- 98
			"伤害", -- 98
			1, -- 98
			1 -- 98
		}, -- 98
		["迅速Lv1"] = { -- 99
			"伤害", -- 99
			0, -- 99
			1 -- 99
		}, -- 99
		["迅速Lv2"] = { -- 100
			"伤害", -- 100
			0, -- 100
			1 -- 100
		} -- 100
	}, -- 90
	["采集"] = { -- 103
		["生物"] = { -- 103
			"伤害", -- 103
			0, -- 103
			1 -- 103
		}, -- 103
		["友善"] = { -- 104
			"伤害", -- 104
			0, -- 104
			1 -- 104
		}, -- 104
		["中立"] = { -- 105
			"伤害", -- 105
			0, -- 105
			1 -- 105
		}, -- 105
		["敌对"] = { -- 106
			"伤害", -- 106
			0, -- 106
			1 -- 106
		}, -- 106
		["挖掘资源"] = { -- 107
			"采集", -- 107
			0, -- 107
			1 -- 107
		}, -- 107
		["采集资源"] = { -- 108
			"采集", -- 108
			0, -- 108
			1 -- 108
		}, -- 108
		["可破坏"] = { -- 109
			"揭示", -- 109
			0, -- 109
			1 -- 109
		}, -- 109
		["可攀爬"] = { -- 110
			"揭示", -- 110
			0, -- 110
			1 -- 110
		}, -- 110
		["大型"] = { -- 111
			"伤害", -- 111
			0, -- 111
			1 -- 111
		} -- 111
	}, -- 102
	["挖掘"] = { -- 114
		["挖掘资源"] = { -- 114
			"采集", -- 114
			1, -- 114
			1 -- 114
		}, -- 114
		["采集资源"] = { -- 115
			"采集", -- 115
			0, -- 115
			1 -- 115
		}, -- 115
		["可破坏"] = { -- 116
			"破坏", -- 116
			1, -- 116
			1 -- 116
		}, -- 116
		["可攀爬"] = { -- 117
			"破坏", -- 117
			0, -- 117
			1 -- 117
		} -- 117
	}, -- 113
	["采收"] = { -- 120
		["友善"] = { -- 120
			"采集", -- 120
			0, -- 120
			1 -- 120
		}, -- 120
		["挖掘资源"] = { -- 121
			"采集", -- 121
			0, -- 121
			1 -- 121
		}, -- 121
		["采集资源"] = { -- 122
			"采集", -- 122
			1, -- 122
			1 -- 122
		} -- 122
	}, -- 119
	["沟通"] = { -- 125
		["生物"] = { -- 125
			"揭示", -- 125
			0, -- 125
			1 -- 125
		}, -- 125
		["友善"] = { -- 126
			"交涉", -- 126
			0, -- 126
			1 -- 126
		}, -- 126
		["中立"] = { -- 127
			"交涉", -- 127
			0, -- 127
			1 -- 127
		}, -- 127
		["敌对"] = { -- 128
			"揭示", -- 128
			0, -- 128
			1 -- 128
		}, -- 128
		["挖掘资源"] = { -- 129
			"揭示", -- 129
			0, -- 129
			1 -- 129
		}, -- 129
		["采集资源"] = { -- 130
			"揭示", -- 130
			0, -- 130
			1 -- 130
		}, -- 130
		["巨型"] = { -- 131
			"交涉", -- 131
			0, -- 131
			0 -- 131
		} -- 131
	}, -- 124
	["鼓舞"] = { -- 134
		["友善"] = { -- 134
			"交涉", -- 134
			0, -- 134
			1 -- 134
		}, -- 134
		["中立"] = { -- 135
			"交涉", -- 135
			0, -- 135
			1 -- 135
		} -- 135
	}, -- 133
	["恐吓"] = { -- 138
		["生物"] = { -- 138
			"恐吓", -- 138
			1, -- 138
			1 -- 138
		}, -- 138
		["友善"] = { -- 139
			"恐吓", -- 139
			1, -- 139
			1 -- 139
		}, -- 139
		["中立"] = { -- 140
			"恐吓", -- 140
			1, -- 140
			1 -- 140
		}, -- 140
		["敌对"] = { -- 141
			"恐吓", -- 141
			1, -- 141
			1 -- 141
		}, -- 141
		["飞行"] = { -- 142
			"恐吓", -- 142
			1, -- 142
			1 -- 142
		}, -- 142
		["大型"] = { -- 143
			"恐吓", -- 143
			0, -- 143
			1 -- 143
		} -- 143
	} -- 137
} -- 17
local newCreature -- 147
newCreature = function() -- 147
	local hints = { } -- 148
	local values = { } -- 149
	local tags = { } -- 150
	local record = { } -- 151
	local relationIndex = App.rand % #relationTags -- 152
	tags[#tags + 1] = relationTags[relationIndex + 1] -- 153
	hints[#hints + 1] = #relationTags -- 154
	values[#values + 1] = relationIndex -- 155
	record[#record + 1] = relationTags[relationIndex + 1] -- 156
	local bodyTypeIndex = App.rand % (#bodyTypes + 1) -- 157
	if bodyTypeIndex ~= 0 then -- 158
		tags[#tags + 1] = bodyTypes[bodyTypeIndex] -- 159
		record[#record + 1] = bodyTypes[bodyTypeIndex] -- 160
	else -- 162
		record[#record + 1] = "无" -- 162
	end -- 158
	hints[#hints + 1] = #bodyTypes + 1 -- 163
	values[#values + 1] = bodyTypeIndex -- 164
	local skillIndex = App.rand % (#skills + 1) -- 165
	if skillIndex ~= 0 then -- 166
		tags[#tags + 1] = skills[skillIndex] -- 167
		record[#record + 1] = skills[skillIndex] -- 168
	else -- 170
		record[#record + 1] = "无" -- 170
	end -- 166
	hints[#hints + 1] = #skills + 1 -- 171
	values[#values + 1] = skillIndex -- 172
	for i = 1, #unitTags do -- 173
		hints[#hints + 1] = 2 -- 174
		if App.rand % 2 == 1 then -- 175
			tags[#tags + 1] = unitTags[i] -- 176
			values[#values + 1] = 1 -- 177
			record[#record + 1] = "有" -- 178
		else -- 180
			values[#values + 1] = 0 -- 180
			record[#record + 1] = "无" -- 181
		end -- 175
	end -- 173
	return { -- 183
		name = table.concat(tags, ","), -- 183
		tags = tags, -- 184
		hints = hints, -- 185
		values = values, -- 186
		record = record -- 187
	} -- 182
end -- 147
local ql = ML.QLearner() -- 190
local getEffect -- 192
getEffect = function(tags, action) -- 192
	local effects = actionEffects[actions[action]] -- 193
	local cancelHarm = false -- 194
	local eset = { } -- 195
	for _index_0 = 1, #tags do -- 196
		local tag = tags[_index_0] -- 196
		local eff = effects[tag] -- 197
		if not eff then -- 198
			goto _continue_0 -- 198
		end -- 198
		if eff[1] == "取消伤害" then -- 199
			cancelHarm = true -- 200
		else -- 202
			local e = eset[eff[1]] -- 202
			if e then -- 202
				local _update_0 = 1 -- 203
				e[_update_0] = e[_update_0] + eff[2] -- 203
				e[2] = math.max(e[2], eff[3]) -- 204
			else -- 206
				eset[eff[1]] = { -- 206
					eff[2], -- 206
					eff[3] -- 206
				} -- 206
			end -- 202
		end -- 199
		::_continue_0:: -- 197
	end -- 196
	if cancelHarm then -- 207
		eset["伤害"] = nil -- 208
	end -- 207
	local _accum_0 = { } -- 209
	local _len_0 = 1 -- 209
	for k, v in pairs(eset) do -- 209
		local p = math.min(100, 50 + 20 * v[1]) -- 210
		if (1 + App.rand % 100) <= p then -- 211
			_accum_0[_len_0] = { -- 212
				k, -- 212
				v[2] -- 212
			} -- 212
			_len_0 = _len_0 + 1 -- 210
		else -- 213
			goto _continue_1 -- 213
		end -- 211
		::_continue_1:: -- 210
	end -- 209
	return _accum_0 -- 209
end -- 192
local newRoundTraining -- 215
newRoundTraining = function() -- 215
	local result = { } -- 216
	while #result == 0 do -- 217
		local unit = newCreature() -- 218
		local state = ML.QLearner:pack(unit.hints, unit.values) -- 219
		local action = ql:getBestAction(state) -- 220
		local randomAction = false -- 221
		if action == 0 then -- 222
			randomAction = true -- 223
			action = App.rand % #actions + 1 -- 224
		end -- 222
		do -- 225
			local _obj_0 = unit.record -- 225
			_obj_0[#_obj_0 + 1] = actions[action] -- 225
		end -- 225
		result = getEffect(unit.tags, action) -- 226
		if #result > 0 then -- 227
			return { -- 229
				name = unit.name, -- 229
				state = state, -- 230
				action = action, -- 231
				result = result, -- 232
				rand = randomAction, -- 233
				record = unit.record -- 234
			} -- 228
		else -- 237
			ql:update(state, action, -1) -- 237
		end -- 227
	end -- 217
end -- 215
local training = nil -- 239
local laborResult = nil -- 240
local effectFlags -- 241
do -- 241
	local _accum_0 = { } -- 241
	local _len_0 = 1 -- 241
	for i = 1, #effectNames do -- 241
		_accum_0[_len_0] = false -- 241
		_len_0 = _len_0 + 1 -- 241
	end -- 241
	effectFlags = _accum_0 -- 241
end -- 241
local manualOp = 0 -- 242
local selfTrained = false -- 243
local records = { -- 245
	{ -- 245
		"关系", -- 245
		"体型", -- 245
		"技能", -- 245
		"生物", -- 245
		"挖掘资源", -- 245
		"采集资源", -- 245
		"可破坏", -- 245
		"可攀爬", -- 245
		"飞行", -- 245
		"行动" -- 245
	}, -- 245
	{ -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C", -- 246
		"C" -- 246
	} -- 246
} -- 244
local decisionStr = nil -- 248
local windowFlags = { -- 250
	"NoResize", -- 250
	"NoSavedSettings", -- 250
	"NoMove", -- 250
	"NoCollapse", -- 250
	"NoDecoration", -- 250
	"NoNav", -- 250
	"AlwaysVerticalScrollbar", -- 250
	"NoSavedSettings" -- 250
} -- 250
local _anon_func_0 = function(training) -- 266
	local _accum_0 = { } -- 266
	local _len_0 = 1 -- 266
	local _list_0 = training.result -- 266
	for _index_0 = 1, #_list_0 do -- 266
		local item = _list_0[_index_0] -- 266
		_accum_0[_len_0] = tostring(item[1]) .. ":" .. tostring(item[2]) -- 266
		_len_0 = _len_0 + 1 -- 266
	end -- 266
	return _accum_0 -- 266
end -- 266
local _anon_func_1 = function(result) -- 302
	local _accum_0 = { } -- 302
	local _len_0 = 1 -- 302
	for _index_0 = 1, #result do -- 302
		local _des_0 = result[_index_0] -- 302
		local k, v = _des_0[1], _des_0[2] -- 302
		_accum_0[_len_0] = tostring(k) .. ":" .. tostring(v) -- 302
		_len_0 = _len_0 + 1 -- 302
	end -- 302
	return _accum_0 -- 302
end -- 302
local _anon_func_2 = function(effectFlags, effectNames) -- 308
	local _accum_0 = { } -- 308
	local _len_0 = 1 -- 308
	for i = 1, #effectFlags do -- 308
		if effectFlags[i] then -- 308
			_accum_0[_len_0] = effectNames[i] -- 308
			_len_0 = _len_0 + 1 -- 308
		end -- 308
	end -- 308
	return _accum_0 -- 308
end -- 308
local _anon_func_3 = function(records) -- 360
	local _accum_0 = { } -- 360
	local _len_0 = 1 -- 360
	for _index_0 = 1, #records do -- 360
		local r = records[_index_0] -- 360
		_accum_0[_len_0] = table.concat(r, ",") -- 360
		_len_0 = _len_0 + 1 -- 360
	end -- 360
	return _accum_0 -- 360
end -- 360
local _anon_func_4 = function(name, op, value) -- 364
	if name ~= "" then -- 364
		return "if " .. tostring(name) .. " " .. tostring(op) .. " " .. tostring(op == '==' and "\"" .. tostring(value) .. "\"" or value) -- 365
	else -- 367
		return tostring(op) .. " \"" .. tostring(value) .. "\"" -- 367
	end -- 364
end -- 364
return threadLoop(function() -- 256
	local width, height -- 257
	do -- 257
		local _obj_0 = App.visualSize -- 257
		width, height = _obj_0.width, _obj_0.height -- 257
	end -- 257
	SetNextWindowPos(Vec2.zero, "Always", Vec2.zero) -- 258
	SetNextWindowSize(Vec2(width, height - 50), "Always") -- 259
	return Begin("Fairy", windowFlags, function() -- 260
		Text("AI Fairy") -- 261
		Separator() -- 262
		if training then -- 263
			TextWrapped("生物: " .. tostring(training.name)) -- 264
			TextWrapped("执行动作: " .. tostring(actions[training.action])) -- 265
			TextWrapped("取得效果: " .. tostring(table.concat(_anon_func_0(training), ", "))) -- 266
			TextWrapped("手工训练记录数: " .. tostring(manualOp)) -- 267
			if training.rand then -- 268
				TextWrapped("[执行了随机动作]") -- 269
			else -- 271
				TextWrapped("[执行了已习得动作]") -- 271
			end -- 268
			if Button("表扬") then -- 272
				manualOp = manualOp + 1 -- 273
				ql:update(training.state, training.action, 1) -- 274
				training = newRoundTraining() -- 275
				records[#records + 1] = training.record -- 276
			end -- 272
			SameLine() -- 277
			if Button("批评") then -- 278
				manualOp = manualOp + 1 -- 279
				ql:update(training.state, training.action, -1) -- 280
				training = newRoundTraining() -- 281
			end -- 278
			SameLine() -- 282
			if Button("跳过") then -- 283
				training = newRoundTraining() -- 284
			end -- 283
		else -- 286
			if Button("开始人工训练") then -- 286
				training = newRoundTraining() -- 287
			end -- 286
		end -- 263
		Separator() -- 288
		if Button("对付100个随机生物") then -- 289
			local result = { } -- 290
			local validAction = 0 -- 291
			for i = 1, 100 do -- 292
				local res = newRoundTraining() -- 293
				if not res.rand then -- 294
					validAction = validAction + 1 -- 294
				end -- 294
				local _list_0 = res.result -- 295
				for _index_0 = 1, #_list_0 do -- 295
					local item = _list_0[_index_0] -- 295
					if result[item[1]] then -- 296
						local _update_0 = item[1] -- 297
						result[_update_0] = result[_update_0] + item[2] -- 297
					else -- 299
						result[item[1]] = item[2] -- 299
					end -- 296
				end -- 295
			end -- 292
			do -- 300
				local _accum_0 = { } -- 300
				local _len_0 = 1 -- 300
				for k, v in pairs(result) do -- 300
					_accum_0[_len_0] = { -- 300
						k, -- 300
						v -- 300
					} -- 300
					_len_0 = _len_0 + 1 -- 300
				end -- 300
				result = _accum_0 -- 300
			end -- 300
			table.sort(result, function(a, b) -- 301
				return b[2] < a[2] -- 301
			end) -- 301
			laborResult = table.concat(_anon_func_1(result), ", ") -- 302
			laborResult = laborResult .. "\n习得动作生效次数: " .. tostring(validAction) .. "/100" -- 303
		end -- 289
		if laborResult then -- 304
			TextWrapped(laborResult) -- 304
		end -- 304
		Separator() -- 305
		local doSelfTraining = false -- 306
		if selfTrained then -- 307
			local target = table.concat(_anon_func_2(effectFlags, effectNames), ", ") -- 308
			TextWrapped("已完成自我训练, 目标: " .. tostring(target)) -- 309
			if Button("遗忘") then -- 310
				selfTrained = false -- 311
				ql = ML.QLearner() -- 312
			end -- 310
		else -- 314
			TextWrapped("选择训练目标") -- 314
			for i = 1, #effectFlags do -- 315
				local _ -- 316
				_, effectFlags[i] = Checkbox(effectNames[i], effectFlags[i]) -- 316
			end -- 315
			doSelfTraining = Button("进行自我训练") -- 317
		end -- 307
		if doSelfTraining then -- 318
			selfTrained = true -- 319
			ql = ML.QLearner() -- 320
			local targetEffects -- 321
			do -- 321
				local _tbl_0 = { } -- 321
				for i = 1, #effectFlags do -- 321
					if effectFlags[i] then -- 321
						_tbl_0[effectNames[i]] = true -- 321
					end -- 321
				end -- 321
				targetEffects = _tbl_0 -- 321
			end -- 321
			local hints = { -- 323
				#relationTags, -- 323
				#bodyTypes + 1, -- 324
				#skills + 1 -- 325
			} -- 322
			for i = 1, #unitTags do -- 327
				hints[#hints + 1] = 2 -- 328
			end -- 327
			local l1 = #relationTags - 1 -- 329
			local l2 = #bodyTypes -- 330
			local l3 = #skills -- 331
			for i1 = 0, l1 do -- 332
				for i2 = 0, l2 do -- 332
					for i3 = 0, l3 do -- 332
						for i4 = 0, 1 do -- 333
							for i5 = 0, 1 do -- 333
								for i6 = 0, 1 do -- 333
									for i7 = 0, 1 do -- 334
										for i8 = 0, 1 do -- 334
											for i9 = 0, 1 do -- 334
												local tags = { } -- 335
												tags[#tags + 1] = relationTags[i1 + 1] -- 336
												local bodyTypeIndex = i2 -- 337
												if bodyTypeIndex ~= 0 then -- 338
													tags[#tags + 1] = bodyTypes[bodyTypeIndex] -- 339
												end -- 338
												local skillIndex = i3 -- 340
												if skillIndex ~= 0 then -- 341
													tags[#tags + 1] = skills[skillIndex] -- 342
												end -- 341
												if i4 ~= 0 then -- 343
													tags[#tags + 1] = unitTags[1] -- 343
												end -- 343
												if i5 ~= 0 then -- 344
													tags[#tags + 1] = unitTags[2] -- 344
												end -- 344
												if i6 ~= 0 then -- 345
													tags[#tags + 1] = unitTags[3] -- 345
												end -- 345
												if i7 ~= 0 then -- 346
													tags[#tags + 1] = unitTags[4] -- 346
												end -- 346
												if i8 ~= 0 then -- 347
													tags[#tags + 1] = unitTags[5] -- 347
												end -- 347
												if i9 ~= 0 then -- 348
													tags[#tags + 1] = unitTags[6] -- 348
												end -- 348
												local state = ML.QLearner:pack(hints, { -- 349
													i1, -- 349
													i2, -- 349
													i3, -- 349
													i4, -- 349
													i5, -- 349
													i6, -- 349
													i7, -- 349
													i8, -- 349
													i9 -- 349
												}) -- 349
												for action = 1, #actions do -- 350
													local result = getEffect(tags, action) -- 351
													local r = 0 -- 352
													for _index_0 = 1, #result do -- 353
														local _des_0 = result[_index_0] -- 353
														local k, v = _des_0[1], _des_0[2] -- 353
														if targetEffects[k] then -- 354
															r = r + v -- 355
														end -- 354
													end -- 353
													ql:update(state, action, r == 0 and -1 or r) -- 356
												end -- 350
											end -- 334
										end -- 334
									end -- 334
								end -- 333
							end -- 333
						end -- 333
					end -- 332
				end -- 332
			end -- 332
		end -- 318
		Separator() -- 357
		TextWrapped("总结人工训练思维逻辑") -- 358
		if Button("开始总结") and #records > 2 then -- 359
			local dataStr = table.concat(_anon_func_3(records), "\n") -- 360
			thread(function() -- 361
				local lines = { } -- 362
				ML.BuildDecisionTreeAsync(dataStr, 0, function(depth, name, op, value) -- 363
					local line = string.rep("\t", depth) .. _anon_func_4(name, op, value) -- 364
					lines[#lines + 1] = line -- 368
				end) -- 363
				decisionStr = table.concat(lines, "\n") -- 369
			end) -- 361
		end -- 359
		if decisionStr then -- 370
			return TextWrapped(decisionStr) -- 370
		end -- 370
	end) -- 260
end) -- 256
