-- Mock Git progress: no repository downloads or Agent sessions.
local D = require("Dora")
package.loaded["Dev.Mobile.Feed"] = nil
local F = require("Dev.Mobile.Feed")
local function find(node, tag)
	if node.tag == tag then return node end
	local result
	node:eachChild(function(child) result = find(child, tag); return result ~= nil end)
	return result
end
D.thread(function()
	local previousSize, hidden, host = D.App.winSize, {}, nil
	local ok, err = xpcall(function()
		assert(D.HttpServer.wsConnectionCount == 0, "Disconnect Web IDE before native UI tests")
		D.Director.systemUI:eachChild(function(node)
			if node.visible then hidden[#hidden+1] = node; node.visible = false end
			return false
		end)
		for _, size in ipairs({D.Size(390,820), D.Size(640,480), D.Size(960,400)}) do
			D.App.winSize = size; D.sleep(0.15)
			local progress, done
			local entry = {id="git-progress-fixture", title="Download preview", description="Mock repository", kind="discover", installed=false}
			host = F.startMobileFeed({initialEntry=entry,
				getLocalEntries=function() return {} end, getDiscoverEntries=function() return {entry} end,
				onPlay=function() error("Unexpected Play") end, onRemix=function() error("Unexpected Remix") end,
				prepare=function(_, _, onProgress, onDone) progress=onProgress; done=onDone end,
			})
			local function get(tag) return assert(find(host, tag), tag) end
			get("mobile-feed-remix"):emit("Tapped")
			assert(get("mobile-feed-download-percent").text == "0%")
			assert(not find(host,"mobile-feed-play"), "Download must replace action buttons")
			progress(0.5, "Receiving objects: 50%\n" .. string.rep("long Git status ", 12))
			assert(get("mobile-feed-download-percent").text == "50%")
			assert(math.abs(get("mobile-feed-download-fill").width / get("mobile-feed-download-track").width - 0.5) < 0.001)
			assert(not get("mobile-feed-download-message").text:find("\n",1,true))
			assert(get("mobile-feed-download-message-clip").width == get("mobile-feed-download-track").width)
			D.App:saveScreenshot("/tmp/dora-download-progress-" .. size.width); D.sleep(0.15)
			progress(2, "Complete"); assert(get("mobile-feed-download-percent").text == "100%")
			progress(-1, "Retry"); assert(get("mobile-feed-download-fill").width == 0)
			done(false,nil,"Test failure",true)
			assert(not find(host,"mobile-feed-download")); get("mobile-feed-remix"):emit("Tapped")
			assert(get("mobile-feed-download-percent").text == "0%", "Retry did not reset progress")
			host:removeFromParent(true); host=nil
		end
	end, debug.traceback)
	if host then host:removeFromParent(true) end
	D.App.winSize = previousSize
	for _, node in ipairs(hidden) do node.visible=true end
	D.Content:save("/tmp/dora-download-progress.result", ok and "passed: portrait/640x480/landscape; progress/clamp/retry/message clipping" or tostring(err))
end)
