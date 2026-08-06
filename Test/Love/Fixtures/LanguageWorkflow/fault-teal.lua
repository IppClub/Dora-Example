-- [tl]: Dora-Example/Test/Love/Fixtures/LanguageWorkflow/fault-teal.tl
local love = require("love")

love.update = function()
	error("LOVE_TEAL_SOURCE_MAP_FAILURE")
end