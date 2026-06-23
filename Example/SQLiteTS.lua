-- [ts]: SQLiteTS.ts
local ____exports = {} -- 1
local ImGui = require("ImGui") -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local DB = ____Dora.DB -- 4
local Vec2 = ____Dora.Vec2 -- 4
local thread = ____Dora.thread -- 4
local threadLoop = ____Dora.threadLoop -- 4
local sqls = {"DROP TABLE IF EXISTS test", "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT)", {"INSERT INTO test VALUES(?, ?)", {{false, "hello"}, {false, "world"}, {false, "ok"}}}} -- 6
local result = DB:transaction(sqls) -- 19
print(result and "Success" or "Failure") -- 20
print(DB:exist("test")) -- 21
p(DB:query("SELECT * FROM test", true)) -- 23
print( -- 25
	"row changed:", -- 25
	DB:exec("DELETE FROM test WHERE id > 1") -- 25
) -- 25
print( -- 26
	"row changed:", -- 26
	DB:exec("UPDATE test SET value = ? WHERE id = 1", {"hello world!"}) -- 26
) -- 26
thread(function() -- 28
	print("insert async") -- 29
	local data = {} -- 30
	for k in pairs(_G) do -- 31
		data[#data + 1] = {false, k} -- 32
	end -- 32
	p(DB:insertAsync("test", data)) -- 34
	print("query async...") -- 35
	local items = DB:queryAsync("SELECT value FROM test WHERE value NOT LIKE 'hello%' ORDER BY value ASC") -- 36
	local rows = {} -- 37
	if items then -- 37
		do -- 37
			local i = 0 -- 39
			while i < #items do -- 39
				local item = items[i + 1] -- 40
				rows[#rows + 1] = item[1] -- 41
				i = i + 1 -- 39
			end -- 39
		end -- 39
	end -- 39
	p(rows) -- 44
	return false -- 45
end) -- 28
print("OK") -- 48
local windowFlags = { -- 50
	"NoDecoration", -- 51
	"AlwaysAutoResize", -- 52
	"NoSavedSettings", -- 53
	"NoFocusOnAppearing", -- 54
	"NoMove" -- 55
} -- 55
threadLoop(function() -- 57
	local size = App.visualSize -- 58
	ImGui.SetNextWindowBgAlpha(0.35) -- 59
	ImGui.SetNextWindowPos( -- 60
		Vec2(size.width - 10, 10), -- 60
		"Always", -- 60
		Vec2(1, 0) -- 60
	) -- 60
	ImGui.SetNextWindowSize( -- 61
		Vec2(240, 0), -- 61
		"FirstUseEver" -- 61
	) -- 61
	ImGui.Begin( -- 62
		"SQLite", -- 62
		windowFlags, -- 62
		function() -- 62
			ImGui.Text("SQLite (TypeScript)") -- 63
			ImGui.Separator() -- 64
			ImGui.TextWrapped("Doing database operations in synchronous and asynchronous ways") -- 65
		end -- 62
	) -- 62
	return false -- 67
end) -- 57
return ____exports -- 57