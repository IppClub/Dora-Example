-- [ts]: Dora-Example/Test/Love/Fixtures/LanguageWorkflow/fault-ts.ts
local ____exports = {} -- 1
require("love") -- 1
love.update = function() -- 3
	assert(false, "LOVE_TS_SOURCE_MAP_FAILURE") -- 4
end -- 3
return ____exports -- 3