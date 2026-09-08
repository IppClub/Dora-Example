-- Shared Go language/Remix choice styling, without starting an Agent session.
local D = require("Dora")
local X = require("DoraX")
local C = require("Dev.Mobile.Controls")
local function find(node, tag)
	if node.tag == tag then return node end
	local result
	node:eachChild(function(child) result = find(child, tag); return result ~= nil end)
	return result
end
local ok, err = xpcall(function()
	for _, selected in ipairs({false, true}) do
		local tapped = 0
		local node = X.toNode(C.MobileChoiceButton({
			tag="test-choice", x=0, y=0, width=155, text="TypeScript",
			selected=selected, renderOrder=10, onTapped=function() tapped=tapped+1 end,
		}))
		assert(node.width == 155 and node.height == 40)
		assert(node.touchEnabled and node.swallowTouches)
		assert(find(node, "test-choice-radio"))
		assert((find(node, "test-choice-radio-dot") ~= nil) == selected)
		node:emit("Tapped")
		assert(tapped == 1)
		node:cleanup()
	end
end, debug.traceback)
D.Content:save("/tmp/dora-choice-button.result", ok and "passed: shared radio geometry, selected dot, tap and touch interception" or tostring(err))
