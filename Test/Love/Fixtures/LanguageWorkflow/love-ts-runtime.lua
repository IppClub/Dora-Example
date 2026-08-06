-- [ts]: Dora-Example/Test/Love/Fixtures/LanguageWorkflow/love-ts-runtime.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
require("love") -- 1
local runtimeLabel = table.concat( -- 3
	__TS__ArrayMap( -- 3
		{"LOVE", "TS", "RUNTIME"}, -- 3
		function(____, part) return string.lower(part) end -- 3
	), -- 3
	"_" -- 3
) -- 3
love.load = function() -- 5
	assert(runtimeLabel == "love_ts_runtime") -- 6
	print("LOVE_TS_RUNTIME_LOAD_PASS") -- 7
end -- 5
love.update = function() -- 10
	love.event.quit(0) -- 11
end -- 10
love.quit = function() -- 14
	print("LOVE_TS_RUNTIME_QUIT_PASS") -- 15
	return false -- 16
end -- 14
return ____exports -- 14