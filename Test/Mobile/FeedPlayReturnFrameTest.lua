-- Native regression for the NanoVG gray/white frame when returning from Play.
-- Precondition: Go Feed is visible on a lightweight local game (BMFontDemo was
-- used for the regression), with no connected Web IDE. No project files change.
-- Captures three complete return sequences. Compare background/card/button
-- pixels in return frames 34..42; colors must be correct from frame 34 onward.
local D = require("Dora")
local function find(node, tag)
	if node.tag == tag then return node end
	local found
	node:eachChild(function(child) found = find(child, tag); return found ~= nil end)
	return found
end
assert(D.HttpServer.wsConnectionCount == 0, "Disconnect Web IDE before testing")
assert(find(D.Director.systemUI, "mobile-feed-play"), "Select a local Feed card first")
local host = D.Node()
host.tag = "feed-return-frame-test"
host:addTo(D.Director.systemUI)
local frame, cycle = 0, 1
host:schedule(function()
	local ok, err = xpcall(function()
		frame = frame + 1
		if frame == 3 then assert(find(D.Director.systemUI, "mobile-feed-play")):emit("Tapped") end
		if frame == 30 then assert(find(D.Director.systemUI, "mobile-play-handle")):emit("Tapped") end
		if frame == 34 then assert(find(D.Director.systemUI, "mobile-play-exit")):emit("Tapped") end
		if frame >= 31 and frame <= 42 then
			D.App:saveScreenshot("/tmp/dora-feed-return-" .. cycle .. "-" .. frame)
		end
		if frame == 45 then
			assert(find(D.Director.systemUI, "mobile-feed-play"))
			assert(not find(D.Director.systemUI, "mobile-play-overlay"))
			cycle, frame = cycle + 1, 0
		end
	end, debug.traceback)
	if not ok or cycle > 3 then
		D.Content:save("/tmp/dora-feed-return.result", ok and "passed: three Play/Feed return cycles; inspect captured frame colors" or tostring(err))
		host:removeFromParent(true)
		return true
	end
	return false
end)
