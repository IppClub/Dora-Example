-- Capture the badge over a real Sprite banner, in both tabs and orientations.
local D = require("Dora")
local Feed = require("Dev.Mobile.Feed")
local function find(node, tag)
	if node.tag == tag then return node end
	local found
	node:eachChild(function(child) found = find(child, tag); return found ~= nil end)
	return found
end
D.thread(function()
	local hidden, host = {}, nil
	local oldSize = D.App.winSize
	D.Content:save("/tmp/dora-feed-badge.result", "running")
	D.Director.systemUI:eachChild(function(node)
		if node.visible then hidden[#hidden + 1] = node; node.visible = false end
		return false
	end)
	local ok, err = xpcall(function()
		local banner = D.Path(D.Content.writablePath, "Dora-Demo/Dismantlism/Image/banner.jpg")
		assert(D.Content:exist(banner), "Install Dora-Demo/Dismantlism for this visual fixture")
		for _, size in ipairs({D.Size(430, 670), D.Size(640, 480)}) do
			D.App.winSize = size
			D.sleep(0.2)
			for _, kind in ipairs({"discover", "local"}) do
				local item = {id = "badge", title = "Dora 演示", kind = kind, bannerFile = banner, description = "Preview badge layering", installed = true}
				host = Feed.startMobileFeed({initialEntry = item,
					getLocalEntries = function() return kind == "local" and {item} or {} end,
					getDiscoverEntries = function() return kind == "discover" and {item} or {} end,
					onPlay = function() end, onRemix = function() end, prepare = function() end})
				D.sleep(0.25)
				assert(D.App:saveScreenshot("/tmp/dora-feed-badge-" .. kind .. "-" .. size.width) ~= "")
				D.sleep(0.15)
				if kind == "local" then
					find(host, "mobile-feed-index"):emit("Tapped")
					assert(find(host, "mobile-project-index-container"), "Badge no longer opens the project index")
				end
				host:removeFromParent(true); host = nil
			end
		end
	end, debug.traceback)
	if host then host:removeFromParent(true) end
	D.App.winSize = oldSize
	for _, node in ipairs(hidden) do if node.parent then node.visible = true end end
	D.Content:save("/tmp/dora-feed-badge.result", ok and "captured: discover/local portrait/landscape; local badge click passed" or "failed: " .. tostring(err))
end)
