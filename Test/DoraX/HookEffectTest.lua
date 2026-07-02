-- [tsx]: HookEffectTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local createRoot = ____DoraX.createRoot -- 2
local signal = ____DoraX.signal -- 2
local useEffect = ____DoraX.useEffect -- 2
local resultFile = Path(Content.writablePath, "DoraXHookEffectTest.result") -- 4
Content:save(resultFile, "running") -- 5
local function fail(message) -- 7
	Content:save(resultFile, "failed: " .. message) -- 8
	error("[DoraXHookEffectTest] " .. message) -- 9
end -- 7
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local function eventsText(events) -- 16
	return table.concat(events, ",") -- 17
end -- 16
local function expectEvents(events, expected, message) -- 20
	local actual = eventsText(events) -- 21
	expect(actual == expected, (message .. ": ") .. actual) -- 22
end -- 20
local host = DNode() -- 25
Director.entry:addChild(host) -- 26
local root = createRoot(host) -- 28
local dep = signal(1) -- 29
local spare = signal(0) -- 30
local visible = signal(true) -- 31
local events = {} -- 32
local outsideOk = pcall(function() return useEffect( -- 34
	function() return nil end, -- 34
	{} -- 34
) end) -- 34
expect(not outsideOk, "useEffect should throw outside function components") -- 35
local function EffectChild(props) -- 37
	useEffect( -- 38
		function() -- 38
			events[#events + 1] = "effect:" .. tostring(props.dep) -- 39
			return function() -- 40
				events[#events + 1] = "cleanup:" .. tostring(props.dep) -- 41
			end -- 40
		end, -- 38
		{props.dep} -- 43
	) -- 43
	return React.createElement("node", {key = "effect-child", x = spare.value}) -- 44
end -- 37
local function App() -- 47
	if not visible.value then -- 47
		return {} -- 48
	end -- 48
	return React.createElement(EffectChild, {key = "effect", dep = dep.value}) -- 49
end -- 47
root:render(App) -- 52
expectEvents(events, "effect:1", "initial effect should run after first render") -- 53
spare.value = 1 -- 55
Director.systemScheduler:schedule(once(function() -- 56
	expectEvents(events, "effect:1", "effect should not rerun when deps are unchanged") -- 57
	dep.value = 2 -- 58
	Director.systemScheduler:schedule(once(function() -- 59
		expectEvents(events, "effect:1,cleanup:1,effect:2", "effect should cleanup before rerun when deps change") -- 60
		visible.value = false -- 61
		Director.systemScheduler:schedule(once(function() -- 62
			expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2", "effect should cleanup when component is removed") -- 63
			dep.value = 3 -- 64
			visible.value = true -- 65
			Director.systemScheduler:schedule(once(function() -- 66
				expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2,effect:3", "effect should run when component mounts again") -- 67
				root:unmount() -- 68
				expectEvents(events, "effect:1,cleanup:1,effect:2,cleanup:2,effect:3,cleanup:3", "effect should cleanup on root unmount") -- 69
				host:removeFromParent(true) -- 70
				Content:save(resultFile, "passed") -- 71
				Log("Info", "[DoraXHookEffectTest] passed") -- 72
			end)) -- 66
		end)) -- 62
	end)) -- 59
end)) -- 56
return ____exports -- 56