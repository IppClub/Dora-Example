-- Offline regression: force refresh, feedback, cache fallback and Discover-only UI.
local D = require("Dora")
package.loaded["Dev.Mobile.Feed"] = nil
package.loaded["Dev.Mobile.ProjectIndex"] = nil
package.loaded["Dev.Mobile.MobileCatalog"] = nil
local Feed = require("Dev.Mobile.Feed")
local function find(node, tag)
	if node.tag == tag then return node end
	local result
	node:eachChild(function(child) result = find(child, tag); return result ~= nil end)
	return result
end
D.thread(function()
	local host, hidden, size = nil, {}, D.App.winSize
	local ok, err = xpcall(function()
		assert(D.HttpServer.wsConnectionCount == 0, "Disconnect Web IDE before UI tests")
		D.Director.systemUI:eachChild(function(node)
			if node.visible then hidden[#hidden+1] = node; node.visible = false end
			return false
		end)
		local catalog = require("Dev.Mobile.MobileCatalog")
		catalog.syncMobileCatalog(function() end, function(success, message)
			assert(not success and message == "offline", "Cache fallback must not claim updated")
		end, function(options)
			assert(options.force == true)
			return {addCallbacks=function(_, done) done(nil, {success=true, usedCache=true, message="offline"}) end}
		end, true)
		for _, width in ipairs({390,640,960}) do
			D.App.winSize = D.Size(width, width == 390 and 820 or 480); D.sleep(0.15)
			local entry = {id="alpha",title="Alpha",description="Fixture",kind="discover",installed=false}
			local localEntry = {id="local",title="Local",description="Fixture",kind="local",installed=true,fileName="/fixture/init",workDir="/fixture"}
			local entries, calls, progress, done, forced = {entry}, 0
			host = Feed.startMobileFeed({initialEntry=entry,
				getLocalEntries=function() return {localEntry} end, getDiscoverEntries=function() return entries end,
				onPlay=function() error("Unexpected Play") end, onRemix=function() error("Unexpected Remix") end, prepare=function() error("Unexpected download") end,
				syncDiscover=function(p,d,f) calls=calls+1; progress=p; done=d; forced=f end})
			local function get(tag) return assert(find(host,tag),tag) end
			assert(calls == 1 and forced == false)
			get("mobile-feed-index"):emit("Tapped")
			get("mobile-project-index-refresh"):emit("Tapped"); assert(calls == 1)
			done(true)
			get("mobile-project-index-refresh"):emit("Tapped"); assert(calls == 2 and forced == true)
			local scroll = get("mobile-project-index-scroll")
			progress("Receiving catalog: 50% " .. string.rep("long message ",20))
			assert(get("mobile-project-index-scroll") == scroll, "Progress must preserve list state")
			assert(get("mobile-project-index-refresh-status").text:find("…",1,true))
			get("mobile-project-index-refresh"):emit("Tapped"); assert(calls == 2)
			done(false,"offline"); assert(get("mobile-project-index-refresh").touchEnabled)
			assert(get("mobile-project-index-entry-0"))
			get("mobile-project-index-refresh"):emit("Tapped")
			entries={entry,{id="beta",title="Beta",description="Fixture",kind="discover",installed=false}}; done(true)
			assert(get("mobile-project-index-entry-1"))
			D.App:saveScreenshot("/tmp/dora-catalog-refresh-" .. width); D.sleep(0.2)
			-- Removing the selected entry used to fall back to the Local tab.
			get("mobile-project-index-refresh"):emit("Tapped")
			entries={entries[2]}; done(true)
			assert(get("mobile-project-index-refresh"), "Removed entry switched to Local")
			assert(not find(host,"mobile-project-index-entry-1"))
			-- Even an installed copy with identical paths must not cause navigation.
			entries[1].fileName=localEntry.fileName; entries[1].workDir=localEntry.workDir
			get("mobile-project-index-refresh"):emit("Tapped")
			entries={}; done(true)
			assert(get("mobile-project-index-refresh"), "Empty catalog switched to Local")
			assert(not find(host,"mobile-project-index-entry-0"))
			get("mobile-project-index-back"):emit("Tapped")
			get("mobile-feed-empty-index"):emit("Tapped")
			get("mobile-project-index-refresh"):emit("Tapped")
			-- A user switching tabs while refreshing must also keep their choice.
			get("mobile-project-index-back"):emit("Tapped")
			get("mobile-feed-local-tab"):emit("Tapped"); get("mobile-feed-index"):emit("Tapped")
			entries={entry}; done(true)
			assert(not find(host,"mobile-project-index-refresh"))
			host:removeFromParent(true); host=nil
		end
	end, debug.traceback)
	if host then host:removeFromParent(true) end
	D.App.winSize = size
	for _, node in ipairs(hidden) do node.visible=true end
	D.Content:save("/tmp/dora-catalog-refresh.result",ok and "passed: force, retry, stable progress, removed entry, installed copy, empty catalog, user tab choice, 3 layouts" or tostring(err))
end)
