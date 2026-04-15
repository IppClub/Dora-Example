-- [yue]: Example/SQLite.yue
local _ENV = Dora -- 2
local DB <const> = DB -- 3
local print <const> = print -- 3
local p <const> = p -- 3
local thread <const> = thread -- 3
local pairs <const> = pairs -- 3
local _G <const> = _G -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local Vec2 <const> = Vec2 -- 3
local result = DB:transaction({ -- 6
	"DROP TABLE IF EXISTS test", -- 6
	"CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)", -- 7
	{ -- 9
		"INSERT INTO test VALUES(?, ?)", -- 9
		{ -- 11
			{ -- 11
				false, -- 11
				"hello" -- 11
			}, -- 11
			{ -- 12
				false, -- 12
				"world" -- 12
			}, -- 12
			{ -- 13
				false, -- 13
				"ok" -- 13
			} -- 13
		} -- 10
	} -- 8
}) -- 5
print(result and "Success" or "Failure") -- 18
print(DB:exist("test")) -- 20
p(DB:query("SELECT * FROM test", true)) -- 22
print("row changed:", DB:exec("DELETE FROM test WHERE id > 1")) -- 24
print("row changed:", DB:exec("UPDATE test SET value = ? WHERE id = 1", { -- 26
	"hello world!" -- 26
})) -- 26
local _anon_func_0 = function(items) -- 35
	local _accum_0 = { } -- 35
	local _len_0 = 1 -- 35
	for _index_0 = 1, #items do -- 35
		local item = items[_index_0] -- 35
		_accum_0[_len_0] = item[1] -- 35
		_len_0 = _len_0 + 1 -- 35
	end -- 35
	return _accum_0 -- 35
end -- 35
thread(function() -- 28
	print("insert async") -- 29
	local data -- 30
	do -- 30
		local _accum_0 = { } -- 30
		local _len_0 = 1 -- 30
		for k in pairs(_G) do -- 30
			_accum_0[_len_0] = { -- 30
				false, -- 30
				k -- 30
			} -- 30
			_len_0 = _len_0 + 1 -- 30
		end -- 30
		data = _accum_0 -- 30
	end -- 30
	p(DB:insertAsync("test", data)) -- 31
	print("query async...") -- 33
	local items = DB:queryAsync("SELECT value FROM test WHERE value NOT LIKE 'hello%' ORDER BY value ASC") -- 34
	return p(_anon_func_0(items)) -- 35
end) -- 28
print("OK") -- 37
local windowFlags = { -- 42
	"NoDecoration", -- 42
	"AlwaysAutoResize", -- 42
	"NoSavedSettings", -- 42
	"NoFocusOnAppearing", -- 42
	"NoNav", -- 42
	"NoMove" -- 42
} -- 42
return threadLoop(function() -- 50
	local width -- 51
	width = App.visualSize.width -- 51
	ImGui.SetNextWindowBgAlpha(0.35) -- 52
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 53
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 54
	return ImGui.Begin("SQLite", windowFlags, function() -- 55
		ImGui.Text("SQLite (YueScript)") -- 56
		ImGui.Separator() -- 57
		return ImGui.TextWrapped("Doing database operations in synchronous and asynchronous ways.") -- 58
	end) -- 55
end) -- 50
