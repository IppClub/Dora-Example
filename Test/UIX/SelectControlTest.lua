-- [tsx]: SelectControlTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local ScrollView = ____UIX.ScrollView -- 4
local Select = ____UIX.Select -- 4
local resultFile = Path(Content.writablePath, "UIXSelectControlTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXSelectControlTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local selected = signal("normal") -- 21
local open = signal(false) -- 22
local selectRef = reference() -- 23
local scrollRef = reference() -- 24
local mountedScroll -- 25
root:render(function() return React.createElement( -- 27
	"align-node", -- 27
	{windowRoot = true, style = {padding = 8}}, -- 27
	React.createElement( -- 27
		ScrollView, -- 29
		{ -- 29
			key = "select-scroll", -- 29
			ref = scrollRef, -- 29
			width = 220, -- 29
			height = 96, -- 29
			contentHeight = open.value and 220 or 116 -- 29
		}, -- 29
		React.createElement( -- 29
			Select, -- 30
			{ -- 30
				ref = selectRef, -- 30
				value = selected.value, -- 30
				open = open.value, -- 30
				items = {{id = "story", label = "Story", icon = "heart"}, {id = "normal", label = "Normal", icon = "check"}, {id = "hard", label = "Hard", icon = "warning"}, {id = "locked", label = "Locked", icon = "lock", disabled = true}}, -- 30
				onOpenChange = function(value) -- 30
					local ____value_0 = value -- 40
					open.value = ____value_0 -- 40
					return ____value_0 -- 40
				end, -- 40
				onValueChange = function(value) -- 40
					local ____value_1 = value -- 41
					selected.value = ____value_1 -- 41
					return ____value_1 -- 41
				end, -- 41
				style = {width = 180} -- 41
			} -- 41
		) -- 41
	) -- 41
) end) -- 41
Director.systemScheduler:schedule(once(function() -- 48
	expect(scrollRef.current ~= nil, "scroll ref missing") -- 49
	mountedScroll = scrollRef.current -- 50
	expect(selectRef.current ~= nil, "select ref missing") -- 51
	expect(selectRef.current.children ~= nil and selectRef.current.children.count == 1, "closed select should only render trigger") -- 52
	local trigger = selectRef.current.children:get(1) -- 53
	trigger:emit("Tapped") -- 54
	Director.systemScheduler:schedule(once(function() -- 55
		expect(scrollRef.current == mountedScroll, "scroll view remounted after opening select") -- 56
		expect(open.value == true, "trigger did not open select") -- 57
		expect(selectRef.current.children ~= nil and selectRef.current.children.count == 2, "open select did not render menu") -- 58
		local menu = selectRef.current.children:get(2) -- 59
		expect(menu.children ~= nil and menu.children.count == 5, "menu should render surface plus four items") -- 60
		local hard = menu.children:get(4) -- 61
		hard:emit("Tapped") -- 62
		Director.systemScheduler:schedule(once(function() -- 63
			expect(scrollRef.current == mountedScroll, "scroll view remounted after selecting item") -- 64
			expect(selected.value == "hard", "select item did not update value") -- 65
			expect(open.value == false, "select did not close after item click") -- 66
			open.value = true -- 67
			Director.systemScheduler:schedule(once(function() -- 68
				expect(scrollRef.current == mountedScroll, "scroll view remounted after reopening select") -- 69
				local reopenedMenu = selectRef.current.children:get(2) -- 70
				local locked = reopenedMenu.children:get(5) -- 71
				locked:emit("Tapped") -- 72
				Director.systemScheduler:schedule(once(function() -- 73
					expect(selected.value == "hard", "disabled select item should not update value") -- 74
					Content:save(resultFile, "passed") -- 75
					Log("Info", "[UIXSelectControlTest] passed") -- 76
					host:removeFromParent(true) -- 77
					root:unmount() -- 78
				end)) -- 73
			end)) -- 68
		end)) -- 63
	end)) -- 55
end)) -- 48
return ____exports -- 48