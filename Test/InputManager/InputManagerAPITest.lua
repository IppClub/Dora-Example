-- [tsx]: InputManagerAPITest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Log = ____Dora.Log -- 1
local Path = ____Dora.Path -- 1
local ____InputManager = require("InputManager") -- 2
local CreateManager = ____InputManager.CreateManager -- 2
local Trigger = ____InputManager.Trigger -- 2
local resultFile = Path(Content.writablePath, "InputManagerAPITest.result") -- 4
Content:save(resultFile, "running") -- 5
local function fail(message) -- 7
	error("[InputManagerAPITest] " .. message) -- 8
end -- 7
local function expect(condition, message) -- 11
	if not condition then -- 11
		fail(message) -- 12
	end -- 12
end -- 11
local jumpTrigger = Trigger.Down({{key = "Space"}, {button = "a"}}) -- 15
local qteTrigger = Trigger.Sequence({ -- 19
	Trigger.Selector({ -- 20
		Trigger.Selector({ -- 21
			Trigger.KeyPressed("J"), -- 22
			Trigger.Block(Trigger.AnyKeyPressed()) -- 23
		}), -- 23
		Trigger.Selector({ -- 25
			Trigger.ButtonPressed("a"), -- 26
			Trigger.Block(Trigger.AnyButtonPressed()) -- 27
		}) -- 27
	}), -- 27
	Trigger.Selector({ -- 30
		Trigger.KeyTimed("J", 1), -- 31
		Trigger.ButtonTimed("a", 1) -- 32
	}) -- 32
}) -- 32
local qteUpdate = qteTrigger -- 35
local triggerListenerHits = 0 -- 37
local function triggerListener() -- 38
	triggerListenerHits = triggerListenerHits + 1 -- 39
end -- 38
jumpTrigger:addListener(triggerListener) -- 41
local inputManager = CreateManager({ -- 43
	Gameplay = { -- 44
		Jump = jumpTrigger, -- 45
		Charge = Trigger.Hold({key = "LShift"}, 0.05), -- 46
		Combo = Trigger.Down({button = {"x", "y"}}) -- 47
	}, -- 47
	QTE = {QuickTime = qteTrigger} -- 49
}) -- 49
local allEvents = 0 -- 54
local completedEvents = 0 -- 55
local onceEvents = 0 -- 56
local lastEvent -- 57
local function onJump(event) -- 59
	allEvents = allEvents + 1 -- 60
	lastEvent = event -- 61
	expect(event.action == "Jump", "event action should be Jump") -- 62
	expect(event.context == "Gameplay", "event context should be Gameplay") -- 63
	expect(event.inputManager == inputManager, "event should carry the source manager") -- 64
	expect(event.trigger == jumpTrigger, "event should carry the source trigger") -- 65
end -- 59
inputManager:on("Jump", onJump) -- 68
inputManager:once( -- 69
	"Jump", -- 69
	function() -- 69
		onceEvents = onceEvents + 1 -- 70
	end -- 69
) -- 69
inputManager:onCompleted( -- 72
	"Jump", -- 72
	function(event) -- 72
		completedEvents = completedEvents + 1 -- 73
		expect(event.state == "Completed", "onCompleted should only receive completed events") -- 74
	end -- 72
) -- 72
expect( -- 77
	inputManager:getEventName("Jump") == "Input.Jump", -- 77
	"getEventName should add Input prefix" -- 77
) -- 77
expect( -- 78
	inputManager:pushContext("Gameplay"), -- 78
	"Gameplay context should push" -- 78
) -- 78
inputManager:emitKeyDown("Space") -- 80
expect(allEvents == 1, "key binding should emit one Jump event") -- 81
expect(completedEvents == 1, "key binding should emit one completed event") -- 82
expect(onceEvents == 1, "once handler should run once after first input") -- 83
expect(triggerListenerHits == 1, "trigger listener should run after first input") -- 84
expect((lastEvent and lastEvent.state) == "Completed", "last event should be completed") -- 85
inputManager:emitKeyUp("Space") -- 86
jumpTrigger:removeListener(triggerListener) -- 88
inputManager:emitButtonDown("a") -- 89
expect(allEvents == 2, "button binding should emit another Jump event") -- 90
expect(completedEvents == 2, "button binding should emit another completed event") -- 91
expect(onceEvents == 1, "once handler should not run again") -- 92
expect(triggerListenerHits == 1, "removed trigger listener should not run again") -- 93
inputManager:emitButtonUp("a") -- 94
inputManager:off("Jump", onJump) -- 96
inputManager:emitKeyDown("Space") -- 97
expect(allEvents == 2, "off should disable the registered handler") -- 98
expect(completedEvents == 3, "other handlers should stay active after off") -- 99
inputManager:emitKeyUp("Space") -- 100
local qteCanceled = 0 -- 102
local qteCompleted = 0 -- 103
inputManager:on( -- 104
	"QuickTime", -- 104
	function(event) -- 104
		if event.state == "Canceled" then -- 104
			qteCanceled = qteCanceled + 1 -- 106
		elseif event.state == "Completed" then -- 106
			qteCompleted = qteCompleted + 1 -- 108
		end -- 108
	end -- 104
) -- 104
expect( -- 111
	inputManager:pushContext("QTE"), -- 111
	"QTE context should push" -- 111
) -- 111
inputManager:emitButtonDown("b") -- 112
local ____opt_2 = qteUpdate.onUpdate -- 112
if ____opt_2 ~= nil then -- 112
	____opt_2(qteUpdate, 0.016) -- 113
end -- 113
expect(qteCanceled >= 1, "wrong QTE button should cancel the QTE action") -- 114
expect(qteCompleted == 0, "wrong QTE button should not complete the QTE action") -- 115
inputManager:emitButtonUp("b") -- 116
expect( -- 117
	inputManager:popContext(), -- 117
	"QTE context should restart after failed QTE" -- 117
) -- 117
expect( -- 118
	inputManager:pushContext("QTE"), -- 118
	"QTE context should restart for QTE success" -- 118
) -- 118
inputManager:emitButtonDown("a") -- 120
local ____opt_4 = qteUpdate.onUpdate -- 120
if ____opt_4 ~= nil then -- 120
	____opt_4(qteUpdate, 0.016) -- 121
end -- 121
expect(qteCompleted >= 1, "correct QTE button should complete the QTE action") -- 122
inputManager:emitButtonUp("a") -- 123
expect( -- 125
	inputManager:popContext(), -- 125
	"QTE context should pop" -- 125
) -- 125
expect( -- 126
	inputManager:popContext(), -- 126
	"Gameplay context should pop" -- 126
) -- 126
inputManager:destroy() -- 127
Content:save(resultFile, "passed") -- 129
Log("Info", "[InputManagerAPITest] passed") -- 130
return ____exports -- 130