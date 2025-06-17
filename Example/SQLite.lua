-- [yue]: Example/SQLite.yue
local DB = Dora.DB -- 1
local print = _G.print -- 1
local p = _G.p -- 1
local thread = Dora.thread -- 1
local pairs = _G.pairs -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local Vec2 = Dora.Vec2 -- 1
local result = DB:transaction({ -- 5
	"DROP TABLE IF EXISTS test", -- 5
	"CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)", -- 6
	{ -- 8
		"INSERT INTO test VALUES(?, ?)", -- 8
		{ -- 10
			{ -- 10
				false, -- 10
				"hello" -- 10
			}, -- 10
			{ -- 11
				false, -- 11
				"world" -- 11
			}, -- 11
			{ -- 12
				false, -- 12
				"ok" -- 12
			} -- 12
		} -- 9
	} -- 7
}) -- 4
print(result and "Success" or "Failure") -- 17
print(DB:exist("test")) -- 19
p(DB:query("SELECT * FROM test", true)) -- 21
print("row changed:", DB:exec("DELETE FROM test WHERE id > 1")) -- 23
print("row changed:", DB:exec("UPDATE test SET value = ? WHERE id = 1", { -- 25
	"hello world!" -- 25
})) -- 25
local _anon_func_0 = function(items) -- 34
	local _accum_0 = { } -- 34
	local _len_0 = 1 -- 34
	for _index_0 = 1, #items do -- 34
		local item = items[_index_0] -- 34
		_accum_0[_len_0] = item[1] -- 34
		_len_0 = _len_0 + 1 -- 34
	end -- 34
	return _accum_0 -- 34
end -- 34
thread(function() -- 27
	print("insert async") -- 28
	local data -- 29
	do -- 29
		local _accum_0 = { } -- 29
		local _len_0 = 1 -- 29
		for k in pairs(_G) do -- 29
			_accum_0[_len_0] = { -- 29
				false, -- 29
				k -- 29
			} -- 29
			_len_0 = _len_0 + 1 -- 29
		end -- 29
		data = _accum_0 -- 29
	end -- 29
	p(DB:insertAsync("test", data)) -- 30
	print("query async...") -- 32
	local items = DB:queryAsync("SELECT value FROM test WHERE value NOT LIKE 'hello%' ORDER BY value ASC") -- 33
	return p(_anon_func_0(items)) -- 34
end) -- 27
print("OK") -- 36
local windowFlags = { -- 41
	"NoDecoration", -- 41
	"AlwaysAutoResize", -- 41
	"NoSavedSettings", -- 41
	"NoFocusOnAppearing", -- 41
	"NoNav", -- 41
	"NoMove" -- 41
} -- 41
return threadLoop(function() -- 49
	local width -- 50
	width = App.visualSize.width -- 50
	ImGui.SetNextWindowBgAlpha(0.35) -- 51
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 52
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 53
	return ImGui.Begin("SQLite", windowFlags, function() -- 54
		ImGui.Text("SQLite (YueScript)") -- 55
		ImGui.Separator() -- 56
		return ImGui.TextWrapped("Doing database operations in synchronous and asynchronous ways.") -- 57
	end) -- 57
end) -- 57
