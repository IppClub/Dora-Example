-- [tsx]: InteractionStateTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local Vec2 = ____Dora.Vec2 -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local Button = ____UIX.Button -- 4
local CooldownButton = ____UIX.CooldownButton -- 4
local resultFile = Path(Content.writablePath, "UIXInteractionStateTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXInteractionStateTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local disabledClicks = signal(0) -- 21
local castCount = signal(0) -- 22
local cooldown = signal(1) -- 23
local dragButtonClicks = signal(0) -- 24
local disabledButtonRef = reference() -- 25
local cooldownButtonRef = reference() -- 26
local dragButtonRef = reference() -- 27
root:render(function() return React.createElement( -- 29
	"align-node", -- 29
	{windowRoot = true, style = {padding = 8, flexDirection = "row", gap = 8}}, -- 29
	React.createElement( -- 29
		Button, -- 31
		{ -- 31
			ref = disabledButtonRef, -- 31
			disabled = true, -- 31
			onClick = function() -- 31
				local ____disabledClicks_0, ____value_1 = disabledClicks, "value" -- 31
				local ____disabledClicks_value_2 = ____disabledClicks_0[____value_1] + 1 -- 31
				____disabledClicks_0[____value_1] = ____disabledClicks_value_2 -- 31
				return ____disabledClicks_value_2 -- 31
			end -- 31
		}, -- 31
		"Disabled" -- 31
	), -- 31
	React.createElement( -- 31
		CooldownButton, -- 32
		{ -- 32
			ref = cooldownButtonRef, -- 32
			icon = "play", -- 32
			cooldown = cooldown.value, -- 32
			maxCooldown = 2, -- 32
			onCast = function() -- 32
				local ____castCount_3, ____value_4 = castCount, "value" -- 32
				local ____castCount_value_5 = ____castCount_3[____value_4] + 1 -- 32
				____castCount_3[____value_4] = ____castCount_value_5 -- 32
				return ____castCount_value_5 -- 32
			end -- 32
		} -- 32
	), -- 32
	React.createElement( -- 32
		Button, -- 33
		{ -- 33
			ref = dragButtonRef, -- 33
			swallowTouches = false, -- 33
			onClick = function() -- 33
				local ____dragButtonClicks_6, ____value_7 = dragButtonClicks, "value" -- 33
				local ____dragButtonClicks_value_8 = ____dragButtonClicks_6[____value_7] + 1 -- 33
				____dragButtonClicks_6[____value_7] = ____dragButtonClicks_value_8 -- 33
				return ____dragButtonClicks_value_8 -- 33
			end -- 33
		}, -- 33
		"Drag" -- 33
	) -- 33
) end) -- 33
Director.systemScheduler:schedule(once(function() -- 37
	expect(disabledButtonRef.current ~= nil, "disabled button was not mounted") -- 38
	expect(cooldownButtonRef.current ~= nil, "cooldown button was not mounted") -- 39
	expect(dragButtonRef.current ~= nil, "drag button was not mounted") -- 40
	disabledButtonRef.current:emit("Tapped") -- 41
	cooldownButtonRef.current:emit("Tapped") -- 42
	dragButtonRef.current:emit("TapBegan") -- 43
	dragButtonRef.current:emit( -- 44
		"TapMoved", -- 44
		{delta = Vec2(0, 12)} -- 44
	) -- 44
	dragButtonRef.current:emit("Tapped") -- 45
	expect(disabledClicks.value == 0, "disabled button should not be invoked during render") -- 46
	expect(castCount.value == 0, "cooling button should not cast while cooling") -- 47
	expect(dragButtonClicks.value == 0, "dragged button should not click") -- 48
	dragButtonRef.current:emit("TapBegan") -- 49
	dragButtonRef.current:emit("Tapped") -- 50
	expect(dragButtonClicks.value == 1, "non-dragged button should click") -- 51
	cooldown.value = 0 -- 52
	Director.systemScheduler:schedule(once(function() -- 53
		expect(cooldown.value == 0, "cooldown signal did not patch") -- 54
		cooldownButtonRef.current:emit("Tapped") -- 55
		expect(castCount.value == 1, "ready cooldown button should cast when tapped") -- 56
		Content:save(resultFile, "passed") -- 57
		Log("Info", "[UIXInteractionStateTest] passed") -- 58
		host:removeFromParent(true) -- 59
		root:unmount() -- 60
	end)) -- 53
end)) -- 37
return ____exports -- 37