-- Native regression for the Go local-project index. No project files are changed.
local D = require("Dora")
local Feed = require("Dev.Mobile.Feed")

local resultPath = "/tmp/dora-project-index.result"

local function find(node, tag)
	if node.tag == tag then return node end
	local result
	node:eachChild(function(child)
		result = find(child, tag)
		return result ~= nil
	end)
	return result
end

local function item(id, title)
	return {
		id = id,
		title = title,
		description = "Index fixture",
		kind = "local",
		workDir = "/fixture/" .. id,
		fileName = "/fixture/" .. id .. "/init",
		installed = true,
	}
end

D.thread(function()
	D.Content:save(resultPath, "running\n")
	local previousSize = D.App.winSize
	local hidden = {}
	D.Director.systemUI:eachChild(function(node)
		if node.visible then hidden[#hidden + 1] = node; node.visible = false end
		return false
	end)
	D.App.winSize = D.Size(390, 568)
	D.sleep(0.15)
	local alpha, beta, charlie = item("alpha", "Alpha"), item("beta", "beta"), item("charlie", "Charlie")
	local number, chinese = item("number", "01 Demo"), item("chinese", "中文作品")
	local entries = {chinese, beta, number, charlie, alpha}
	local host = Feed.startMobileFeed({
		initialEntry = chinese,
		getLocalEntries = function() return entries end,
		getDiscoverEntries = function() return {} end,
		prepare = function() end,
		onPlay = function() end,
		onRemix = function() end,
		createProject = function() return {success = false, error = "fixture"} end,
	})
	local ok, err = xpcall(function()
		assert(find(host, "mobile-feed-index"), "Local Feed has no project-index entry")
		find(host, "mobile-feed-index"):emit("Tapped")
		D.sleep(0.05)
		assert(find(host, "mobile-project-index-container"), "Project index did not open")
		local card = assert(find(host, "mobile-feed-current-title"))
		local visible = true
		while card do
			visible = visible and card.visible
			card = card.parent
		end
		assert(not visible, "Feed content is visible through the project index")
		assert(not find(host, "mobile-project-index-new"), "Project index should not contain a new-project button")
		assert(find(host, "mobile-project-index-group-A"), "A group missing")
		assert(find(host, "mobile-project-index-group-B"), "B group missing")
		assert(find(host, "mobile-project-index-group-C"), "C group missing")
		assert(find(host, "mobile-project-index-group-#"), "Other group missing")
		assert(not find(host, "mobile-project-index-group-中"), "Chinese title escaped the Other group")
		local rail = assert(find(host, "mobile-project-index-rail"))
		local world = rail:convertToWorldSpace(D.Vec2(rail.width / 2, 2))
		rail:emit("TapBegan", {worldLocation = world})
		assert(find(host, "mobile-project-index-popup-label").text == "其它", "Ruler did not label the Other group")
		rail:emit("TapEnded", {worldLocation = world})
		D.sleep(0.08)
		local screenshot = D.App:saveScreenshot("/tmp/dora-project-index")
		assert(screenshot ~= "", "Project-index screenshot failed")
		D.Content:save("/tmp/dora-project-index-screenshot.path", screenshot)
		D.sleep(0.25)
		find(host, "mobile-project-index-entry-1"):emit("Tapped")
		D.sleep(0.05)
		assert(not find(host, "mobile-project-index-container"), "Project index remained open after selection")
		assert(find(host, "mobile-feed-current-title").text == beta.title, "Project index selected the wrong sorted item")
		host:removeFromParent(true)
		D.App.winSize = D.Size(640, 480)
		D.sleep(0.15)
		host = Feed.startMobileFeed({
			initialEntry = chinese,
			getLocalEntries = function() return entries end,
			getDiscoverEntries = function() return {} end,
			prepare = function() end,
			onPlay = function() end,
			onRemix = function() end,
			createProject = function() return {success = false, error = "fixture"} end,
		})
		find(host, "mobile-feed-index"):emit("Tapped")
		D.sleep(0.08)
		assert(find(host, "mobile-project-index-container"), "Landscape project index did not open")
		assert(find(host, "mobile-project-index-rail").height > 200, "Landscape ruler lost its usable drag area")
		assert(D.App:saveScreenshot("/tmp/dora-project-index-landscape") ~= "", "Landscape screenshot failed")
		D.sleep(0.25)
	end, debug.traceback)
	if host.parent then host:removeFromParent(true) end
	D.App.winSize = previousSize
	for _, node in ipairs(hidden) do node.visible = true end
	D.Content:save(resultPath, ok and "passed groups=1 other=1 ruler=1 select=1 portrait=1 landscape=1\n" or "failed " .. tostring(err))
end)
