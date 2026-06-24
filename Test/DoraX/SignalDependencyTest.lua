-- [tsx]: SignalDependencyTest.tsx
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
local signal = ____DoraX.signal -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXSignalDependencyTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXSignalDependencyTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local hostA = DNode() -- 16
local hostB = DNode() -- 17
local hostStatic = DNode() -- 18
Director.entry:addChild(hostA) -- 19
Director.entry:addChild(hostB) -- 20
Director.entry:addChild(hostStatic) -- 21
local rootA = createRoot(hostA) -- 23
local rootB = createRoot(hostB) -- 24
local rootStatic = createRoot(hostStatic) -- 25
local signalA = signal(0) -- 26
local signalB = signal(0) -- 27
local labelA = useRef() -- 28
local labelB = useRef() -- 29
local labelStatic = useRef() -- 30
local rendersA = 0 -- 31
local rendersB = 0 -- 32
local rendersStatic = 0 -- 33
rootA:render(function() -- 35
	rendersA = rendersA + 1 -- 36
	return React.createElement( -- 37
		"label", -- 37
		{ -- 37
			ref = labelA, -- 37
			fontName = "sarasa-mono-sc-regular", -- 37
			fontSize = 18, -- 37
			text = "A:" .. tostring(signalA.value) -- 37
		} -- 37
	) -- 37
end) -- 35
rootB:render(function() -- 39
	rendersB = rendersB + 1 -- 40
	return React.createElement( -- 41
		"label", -- 41
		{ -- 41
			ref = labelB, -- 41
			fontName = "sarasa-mono-sc-regular", -- 41
			fontSize = 18, -- 41
			text = "B:" .. tostring(signalB.value) -- 41
		} -- 41
	) -- 41
end) -- 39
rootStatic:render(function() -- 43
	rendersStatic = rendersStatic + 1 -- 44
	return React.createElement("label", {ref = labelStatic, fontName = "sarasa-mono-sc-regular", fontSize = 18, text = "static"}) -- 45
end) -- 43
expect(rendersA == 1 and rendersB == 1 and rendersStatic == 1, "initial render counts were wrong") -- 48
signalA.value = 1 -- 50
Director.systemScheduler:schedule(once(function() -- 52
	expect(rendersA == 2, "signalA should update rootA") -- 53
	expect(rendersB == 1, "signalA should not update rootB") -- 54
	expect(rendersStatic == 1, "signalA should not update a root that reads no signal") -- 55
	expect(labelA.current.text == "A:1", "rootA did not patch signalA value") -- 56
	expect(labelB.current.text == "B:0", "rootB text changed unexpectedly") -- 57
	signalB.value = 2 -- 59
	signalB.value = 3 -- 60
	Director.systemScheduler:schedule(once(function() -- 62
		expect(rendersA == 2, "signalB should not update rootA") -- 63
		expect(rendersB == 2, "batched signalB changes should update rootB once") -- 64
		expect(rendersStatic == 1, "signalB should not update static root") -- 65
		expect(labelB.current.text == "B:3", "rootB did not render latest signalB value") -- 66
		rootA:unmount() -- 68
		rootB:unmount() -- 69
		rootStatic:unmount() -- 70
		hostA:removeFromParent(true) -- 71
		hostB:removeFromParent(true) -- 72
		hostStatic:removeFromParent(true) -- 73
		Content:save(resultFile, "passed") -- 74
		Log("Info", "[DoraXSignalDependencyTest] passed") -- 75
	end)) -- 62
end)) -- 52
return ____exports -- 52