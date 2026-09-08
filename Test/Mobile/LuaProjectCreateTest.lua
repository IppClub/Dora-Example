-- Test Lua creation without compiler output, rollback, and runnable entry.
local D = require("Dora")
local P = require("Dev.Mobile.ProjectCreate")
local result = "/tmp/dora-lua-project-create.result"
local root = D.Path(D.Content.writablePath, ".lua-create-test-" .. D.App.rand)
local ok, err = xpcall(function()
	assert(D.Content:mkdir(root))
	local storage = {
		workspace = root,
		getDirs = function(path) return D.Content:getDirs(path) end,
		getFiles = function(path) return D.Content:getFiles(path) end,
		exist = function(path) return D.Content:exist(path) end,
		mkdir = function(path) return D.Content:mkdir(path) end,
		save = function(path, text) return D.Content:save(path, text) end,
		remove = function(path) return D.Content:remove(path) end,
	}
	local lua = P.createMobileProject(" Lua 项目 ", "lua", storage)
	assert(lua.success and lua.name == "Lua 项目")
	assert(D.Content:load(D.Path(lua.workDir, "init.lua")) == P.mobileLuaProjectTemplate)
	assert(not D.Content:exist(D.Path(lua.workDir, "init.ts")), "Lua project contains TypeScript")
	assert(lua.fileName == D.Path(lua.workDir, "init"))
	dofile(D.Path(lua.workDir, "init.lua"))
	assert(P.createMobileProject("Lua 项目", "lua", storage).error == "target-existed")
	assert(P.createMobileProject("../escape", "lua", storage).error == "invalid-name")
	local ts = P.createMobileTypeScriptProject("TS", storage)
	assert(ts.success and D.Content:exist(D.Path(ts.workDir, "init.ts")))
	assert(D.Content:load(D.Path(ts.workDir, "init.lua")) == P.mobileTypeScriptProjectLuaTemplate)
	storage.save = function() return false end
	assert(P.createMobileProject("Broken", "lua", storage).error == "create-entry-failed")
	assert(not D.Content:exist(D.Path(root, "Broken")), "Failed Lua project was not rolled back")
end, debug.traceback)
D.Content:remove(root)
D.Content:save(result, ok and "passed: Lua entry runs; no TS; names/collisions; rollback; TS compatibility" or "failed: " .. tostring(err))
