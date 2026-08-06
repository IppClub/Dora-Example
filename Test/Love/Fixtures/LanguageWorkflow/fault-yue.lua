-- [yue]: Dora-Example/Test/Love/Fixtures/LanguageWorkflow/fault-yue.yue
local love = require("love") -- 1
love.update = function() -- 3
	return error("LOVE_YUE_SOURCE_MAP_FAILURE") -- 4
end -- 3
