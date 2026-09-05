-- Native, deterministic controller-event regression. Does not send LLM requests
-- or change user projects/configuration. Physical controller testing is separate.
local D = require("Dora")
local G = require("Dev.Mobile.Gamepad")
local F = require("Dev.Mobile.Feed")
local R = require("Dev.Mobile.Remix")
local P = require("Dev.Mobile.PlayOverlay")
local L = require("Dev.Mobile.LLMSetup")
local find = G.findGamepadNode
local function controller()
	local last
	D.Director.systemUI:eachChild(function(n)
		if n.tag == "mobile-gamepad" and n.visible then last = n end
		return false
	end)
	return assert(last, "Missing controller router")
end
local function press(button, node)
	node = node or controller()
	node:emit("ButtonDown", 0, button)
	node:emit("ButtonUp", 0, button)
	D.sleep(0.04)
end
local function focus(tag)
	local actual="none"
	controller():eachChild(function(n) actual=n.tag; return false end)
	assert(find(controller(), "mobile-gamepad-focus:" .. tag), "Wrong focus: " .. tag .. ", actual " .. actual)
end
local function button(parent, tag, x, y, cb)
	local n = D.Node()
	n.tag, n.position, n.size, n.anchor = tag, D.Vec2(x, y), D.Size(80, 40), D.Vec2.zero
	n.touchEnabled = true
	n:onTapped(cb or function() end)
	n:addTo(parent)
	return n
end
local function item(id, kind)
	return {id=id, title=id, description="Controller fixture", kind=kind or "local",
		workDir="/fixture/"..id, fileName="/fixture/"..id.."/init", installed=true}
end
local session = {id=91995,projectRoot=D.Content.assetPath,title="Gamepad",kind="main",
	rootSessionId=91995,memoryScope="main",workMode="code",status="IDLE",createdAt=1,updatedAt=1}
local cfg = {url="https://example.invalid",model="test",apiKey="test",contextWindow=64000,
	temperature=0,maxTokens=1000,supportsFunctionCalling=true}
local messages = {}
for i=1,12 do
	messages[i]={id=i,sessionId=session.id,role=i%2==1 and "user" or "assistant",
		content="Controller scroll fixture "..i.."\nA longer message for viewport testing.",createdAt=i}
end
local services = {
	createSession=function() return {success=true,session=session} end,
	getSession=function() return {success=true,session=session,relatedSessions={},messages=messages,steps={},checkpoints={},hasActivePlan=false} end,
	getLLMConfigSummaries=function() return {{id=94995,name="test",model="test",active=true}} end,
	getLLMConfig=function() return {success=true,id=94995,config=cfg} end,
	getActiveLLMConfig=function() return {success=true,id=94995,config=cfg} end,
	setWorkMode=function(_,mode) session.workMode=mode; return {success=true} end,
	sendPrompt=function() error("Unexpected send") end,
	respondQuestionnaire=function() error("Unexpected questionnaire") end,
	stopSessionTask=function() return {success=true} end,
}
D.thread(function()
	D.Content:save("/tmp/dora-gamepad.result", "running\n")
	local hidden, fixtures = {}, {}
	local previousSize = D.App.winSize
	D.Director.systemUI:eachChild(function(n)
		if n.visible then hidden[#hidden+1]=n; n.visible=false end
		return false
	end)
	local function keep(n) fixtures[#fixtures+1]=n; return n end
	local ok, err = xpcall(function()
		assert(D.HttpServer.wsConnectionCount == 0, "Close Web IDE before native controller tests")
		D.App.winSize=D.Size(640,480); D.sleep(0.2)
		local host=keep(D.Node()); host.tag="gamepad-fixture"; host:addTo(D.Director.systemUI)
		local hits, backs, scrolled = 0, 0, 0
		button(host,"remix-mode-plan",0,80,function() hits=hits+1 end)
		local disabled=button(host,"remix-mode-code",100,80); disabled.touchEnabled=false
		button(host,"remix-play",200,80,function() hits=hits+10 end)
		button(host,"remix-input",0,0):slot("GamepadActivate",function() hits=hits+100 end)
		G.attachGamepad(host,{initialTag="remix-mode-plan",onBack=function() backs=backs+1 end,
			onScroll=function(amount) scrolled=scrolled+amount end})
		D.sleep(0.04)
		press("a"); assert(hits==1); focus("remix-mode-plan")
		press("dpright"); focus("remix-play"); press("a"); assert(hits==11,"Disabled control was focused")
		host:removeAllChildren()
		button(host,"remix-mode-plan",0,80)
		button(host,"remix-play",200,80,function() hits=hits+10 end)
		button(host,"remix-input",0,0):slot("GamepadActivate",function() hits=hits+100 end)
		D.sleep(0.04); focus("remix-play"); press("a"); assert(hits==21,"Focus lost on redraw")
		press("dpleft"); press("dpdown"); focus("remix-input"); press("a"); assert(hits==121,"Input activation failed")
		press("b"); assert(backs==1)
		controller():emit("Axis",0,"lefty",-0.2); D.sleep(0.06); focus("remix-input")
		controller():emit("Axis",0,"lefty",-0.8); D.sleep(0.04); focus("remix-mode-plan")
		controller():emit("Axis",0,"lefty",0)
		controller():emit("Axis",0,"righty",0.8); D.sleep(0.1)
		controller():emit("Axis",0,"righty",0); assert(scrolled>0,"Right stick scroll failed")
		controller():emit("Axis",0,"righty",0.8)
		controller():emit("ControllerRemoved",0)
		local stopped=scrolled; D.sleep(0.1); assert(scrolled==stopped,"Disconnected controller kept scrolling")
		local lower=controller()
		local modal=keep(D.Node()); modal.tag="modal-fixture"; modal:addTo(D.Director.systemUI)
		local modalHits=0
		button(modal,"mobile-llm-close",0,0,function() modalHits=modalHits+1 end)
		G.attachGamepad(modal,{onBack=function() modal:removeFromParent(true) end})
		D.sleep(0.04); press("a",lower); assert(hits==121,"Underlying screen received input")
		press("a"); assert(modalHits==1); press("b"); assert(not modal.parent)
		-- Synchronously opened screens cannot activate again from the same event.
		local nextHits=0
		find(host,"remix-mode-plan"):onTapped(function()
			local nextHost=keep(D.Node()); nextHost.tag="next-fixture"; nextHost:addTo(D.Director.systemUI)
			button(nextHost,"mobile-llm-close",0,0,function() nextHits=nextHits+1 end)
			G.attachGamepad(nextHost,{onBack=function() nextHost:removeFromParent(true) end})
			controller():emit("ButtonDown",0,"a")
		end)
		press("a"); assert(nextHits==0,"A leaked across screen transition")
		press("a"); assert(nextHits==1); press("b")
		host:removeFromParent(true); D.sleep(0.04)
		local feed, remix, played, remixed
		local locals, discover={item("A"),item("B"),item("C"),item("D")},{item("X","discover")}
		feed=keep(F.startMobileFeed({getLocalEntries=function() return locals end,
			getDiscoverEntries=function() return discover end,
			prepare=function() error("Unexpected download") end,
			createProject=function() error("Unexpected project creation") end,
			onPlay=function(entry) played=entry.id end,
			onRemix=function(entry)
				remixed=entry.id; feed.visible=false
				remix=keep(R.startMobileRemix({entry=entry,services=services,onPlay=function() end,
					onBack=function() feed.visible=true end}))
			end}))
		local function title(s) assert(find(feed,"mobile-feed-current-title").text==s,"Wrong card: "..s) end
		D.sleep(0.1); title("A"); press("dpdown"); D.sleep(0.25); title("B")
		press("dpup"); D.sleep(0.25); title("A")
		press("leftshoulder"); title("X"); press("rightshoulder"); title("A")
		controller():emit("Axis",0,"lefty",0.8); D.sleep(1.1)
		controller():emit("Axis",0,"lefty",0); D.sleep(0.25)
		assert(find(feed,"mobile-feed-current-title").text~="B","Stick did not repeat across card transitions")
		feed:emit("RestoreFeedEntry",locals[1]); D.sleep(0.04)
		press("start"); D.sleep(0.08)
		assert(find(feed,"mobile-project-index-container"),"Start did not open project index")
		press("dpdown"); focus("mobile-project-index-entry-1")
		press("a"); D.sleep(0.08); assert(not find(feed,"mobile-project-index-container"),"A did not close project index")
		title("B"); feed:emit("RestoreFeedEntry",locals[1]); D.sleep(0.04)
		press("y"); assert(find(D.Director.systemUI,"mobile-package-panel"),"Y did not open add menu")
		assert(find(D.Director.systemUI,"mobile-package-new")):emit("Tapped"); D.sleep(0.04)
		assert(find(feed,"mobile-project-create-sheet")); focus("mobile-project-create-input")
		press("a"); press("b"); assert(find(feed,"mobile-project-create-sheet"),"B closed sheet instead of IME")
		press("b"); assert(not find(feed,"mobile-project-create-sheet")); focus("mobile-feed-play")
		D.App:saveScreenshot("/tmp/dora-gamepad-feed"); D.sleep(0.08)
		press("a"); assert(played=="A")
		press("x"); D.sleep(0.25); assert(remixed=="A" and remix and remix.parent)
		local scroll=assert(find(remix,"remix-scroll"))
		local oldOffset=scroll.offset.y
		controller():emit("Axis",0,"righty",-0.8); D.sleep(0.3); controller():emit("Axis",0,"righty",0)
		assert(scroll.offset.y<oldOffset,"Transcript did not scroll to earlier messages")
		press("a"); focus("remix-input"); press("b"); assert(remix.parent,"B did not dismiss IME first")
		press("dpup"); D.sleep(0.04)
		D.App:saveScreenshot("/tmp/dora-gamepad-remix"); D.sleep(0.08)
		press("b"); D.sleep(0.1); assert(not remix.parent and feed.visible)
		-- Model panels are exercised read-only: never save a key/select/delete.
		local setup=keep(L.startMobileLLMSetup({onSaved=function() error("Unexpected key save") end}))
		D.sleep(0.04); press("a"); focus("mobile-llm-provider")
		press("dpdown"); focus("mobile-llm-key"); press("a"); press("b"); assert(setup.parent)
		press("b"); assert(not setup.parent)
		local configs=D.DB:query("select id from LLMConfig order by id") or {}
		if #configs>0 then
			local id=tonumber(configs[1][1])
			local manager=keep(L.startMobileLLMManager({selectedId=id+0.0,onSelected=function() error("Unexpected config selection") end}))
			D.sleep(0.04); press("dpright"); focus("mobile-llm-detail-"..tostring(id)); press("a")
			focus("mobile-llm-detail-key-edit"); press("a"); focus("mobile-llm-detail-key-input")
			press("a"); press("b"); assert(find(manager,"mobile-llm-detail-key-input"))
			press("b"); focus("mobile-llm-detail-key-edit")
			press("dpright"); press("a"); focus("mobile-llm-detail-delete-cancel")
			press("b"); focus("mobile-llm-detail-delete")
			press("b"); press("b"); assert(not manager.parent)
		end
		local exited=false
		local overlay=keep(P.startMobilePlayOverlay({onExit=function() exited=true end}))
		D.sleep(0.04)
		for _,name in ipairs({"a","b","x","y","dpup","dpdown","start"}) do press(name) end
		assert(not exited and find(overlay,"mobile-play-handle"),"Game buttons activated exit")
		find(overlay,"mobile-play-handle"):emit("Tapped"); press("a")
		assert(not exited and find(overlay,"mobile-play-exit"),"A exited expanded overlay")
		press("b"); assert(find(overlay,"mobile-play-handle"),"B did not collapse overlay")
	end,debug.traceback)
	for i=#fixtures,1,-1 do if fixtures[i].parent then fixtures[i]:removeFromParent(true) end end
	D.App.winSize=previousSize
	for _,n in ipairs(hidden) do if n.parent then n.visible=true end end
	D.Content:save("/tmp/dora-gamepad.result",ok and "passed disabledSkip focusRedraw inputActivation back deadzone axisNavigation axisRepeat rightScroll disconnect modalIsolation sameFrameGuard feedCards feedTabs projectIndex createIME remixIME transcriptScroll modelPanels playIsolation\n" or "failed "..tostring(err))
end)
