-- [tsx]: SignalSchedulerTest.tsx
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
local resultFile = Path(Content.writablePath, "DoraXSignalSchedulerTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXSignalSchedulerTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local hostA = DNode() -- 16
local hostB = DNode() -- 17
Director.entry:addChild(hostA) -- 18
Director.entry:addChild(hostB) -- 19
local rootA = createRoot(hostA) -- 21
local rootB = createRoot(hostB) -- 22
local value = signal(0) -- 23
local labelA = reference() -- 24
local labelB = reference() -- 25
local rendersA = 0 -- 26
local rendersB = 0 -- 27
rootA:render(function() -- 29
	rendersA = rendersA + 1 -- 30
	return React.createElement( -- 31
		"label", -- 31
		{ -- 31
			key = "a", -- 31
			ref = labelA, -- 31
			fontName = "sarasa-mono-sc-regular", -- 31
			fontSize = 18, -- 31
			text = "A:" .. tostring(value.value) -- 31
		} -- 31
	) -- 31
end) -- 29
rootB:render(function() -- 33
	rendersB = rendersB + 1 -- 34
	return React.createElement( -- 35
		"label", -- 35
		{ -- 35
			key = "b", -- 35
			ref = labelB, -- 35
			fontName = "sarasa-mono-sc-regular", -- 35
			fontSize = 18, -- 35
			text = "B:" .. tostring(value.value) -- 35
		} -- 35
	) -- 35
end) -- 33
expect(rendersA == 1 and rendersB == 1, "initial root render counts were wrong") -- 38
expect(labelA.current.text == "A:0" and labelB.current.text == "B:0", "initial signal text was wrong") -- 39
value.value = 1 -- 41
value.value = 2 -- 42
value.value = 3 -- 43
Director.systemScheduler:schedule(once(function() -- 45
	expect(rendersA == 2 and rendersB == 2, "batched signal changes should schedule one update per root") -- 46
	expect(labelA.current.text == "A:3" and labelB.current.text == "B:3", "batched signal value was not rendered") -- 47
	rootB:unmount() -- 49
	value.value = 4 -- 50
	Director.systemScheduler:schedule(once(function() -- 52
		expect(rendersA == 3, "mounted root did not update after second signal change") -- 53
		expect(rendersB == 2, "unmounted root should not re-render after signal change") -- 54
		expect(labelA.current.text == "A:4", "mounted root label did not patch after second signal change") -- 55
		expect(not hostB.hasChildren, "unmounted root host still has children") -- 56
		rootA:unmount() -- 57
		hostA:removeFromParent(true) -- 58
		hostB:removeFromParent(true) -- 59
		Content:save(resultFile, "passed") -- 60
		Log("Info", "[DoraXSignalSchedulerTest] passed") -- 61
	end)) -- 52
end)) -- 45
return ____exports -- 45