-- Native header spacing and transient back-feedback regression; no real Agent calls.
local D = require("Dora")
local Remix = require("Dev.Mobile.Remix")
local function find(node, tag)
	if node.tag == tag then return node end
	local found
	node:eachChild(function(child) found = find(child, tag); return found ~= nil end)
	return found
end
D.thread(function()
	local result = "/tmp/dora-remix-header-feedback.result"
	D.Content:save(result, "running")
	local hidden, host = {}, nil
	local oldSize = D.App.winSize
	D.Director.systemUI:eachChild(function(node)
		if node.visible then hidden[#hidden + 1] = node; node.visible = false end
		return false
	end)
	local session = {id = 91998, status = "RUNNING", workMode = "plan", currentTaskId = 92998, currentTaskStatus = "RUNNING"}
	local detail = {success = true, session = session, messages = {}, steps = {}, hasActivePlan = false}
	local services = {
		createSession = function() return {success = true, session = session} end,
		getSession = function() return detail end,
		getLLMConfigSummaries = function() return {{id = 1, name = "ZAI Coding"}} end,
		getActiveLLMConfig = function() return {success = false, message = "unused"} end,
		getLLMConfig = function() return {success = false, message = "unused"} end,
		setWorkMode = function() return {success = true} end,
		sendPrompt = function() error("Unexpected Agent request") end,
		respondQuestionnaire = function() error("Unexpected Agent request") end,
		stopSessionTask = function() error("Unexpected Agent request") end,
	}
	local ok, err = xpcall(function()
		D.App.winSize = D.Size(430, 700)
		D.sleep(0.15)
		host = Remix.startMobileRemix({entry = {id = "header-test", title = "Long project title", workDir = D.Content.writablePath},
			onBack = function() error("Running session must not exit") end, onPlay = function() end, services = services})
		local function checkSpacing()
			local model = assert(find(host, "remix-model-config"))
			local back = assert(find(host, "remix-back"))
			local title = assert(find(host, "remix-title")).parent
			assert(math.abs(back.x - model.x - model.width - 12) < 0.01, "Uneven right header gap")
			assert(math.abs(model.x - title.x - title.width - 12) < 0.01, "Uneven left header gap")
		end
		checkSpacing()
		find(host, "remix-back"):emit("Tapped")
		assert(find(host, "remix-error"), "Missing busy notice")
		D.sleep(2)
		find(host, "remix-back"):emit("Tapped")
		D.sleep(1.5)
		assert(find(host, "remix-error"), "Repeated tap did not restart notice timeout")
		D.sleep(1.8)
		assert(not find(host, "remix-error"), "Busy notice did not expire")
		assert(host.parent and session.status == "RUNNING", "Notice expiry changed session")
		D.App.winSize = D.Size(960, 480)
		D.sleep(0.2)
		checkSpacing()
	end, debug.traceback)
	if host then host:removeFromParent(true) end
	D.App.winSize = oldSize
	for _, node in ipairs(hidden) do if node.parent then node.visible = true end end
	D.Content:save(result, ok and "passed: portrait/landscape spacing, notice expiry, repeated-tap timer, running session preserved" or "failed: " .. tostring(err))
end)
