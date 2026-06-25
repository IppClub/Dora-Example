-- [tsx]: HookMemoTest.tsx
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
local useCallback = ____DoraX.useCallback -- 3
local useMemo = ____DoraX.useMemo -- 3
local useRef = ____DoraX.useRef -- 3
local useSignal = ____DoraX.useSignal -- 3
local resultFile = Path(Content.writablePath, "DoraXHookMemoTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXHookMemoTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local host = DNode() -- 17
Director.entry:addChild(host) -- 18
local root = createRoot(host) -- 20
local customRef = reference() -- 21
local labelRef = reference() -- 22
local tick = signal(0) -- 23
local spare = signal(0) -- 24
local dep = signal(1) -- 25
local creates = 0 -- 26
local memoBuilds = 0 -- 27
local stableRefObject -- 28
local localSignalObject -- 29
local plainRef = reference(1) -- 31
expect(plainRef.current == 1, "reference should be available outside function components") -- 32
local useRefOk = pcall(function() return useRef(1) end) -- 34
local useSignalOk = pcall(function() return useSignal(1) end) -- 35
local useMemoOk = pcall(function() return useMemo( -- 36
	function() return 1 end, -- 36
	{} -- 36
) end) -- 36
local useCallbackOk = pcall(function() return useCallback( -- 37
	function() return 1 end, -- 37
	{} -- 37
) end) -- 37
expect(not useRefOk, "useRef should throw outside function components") -- 38
expect(not useSignalOk, "useSignal should throw outside function components") -- 39
expect(not useMemoOk, "useMemo should throw outside function components") -- 40
expect(not useCallbackOk, "useCallback should throw outside function components") -- 41
local function StableCustom() -- 43
	local localRef = useRef(3) -- 44
	local localSignal = useSignal(5) -- 45
	if stableRefObject == nil then -- 45
		stableRefObject = localRef -- 47
	end -- 47
	if localSignalObject == nil then -- 47
		localSignalObject = localSignal -- 50
	end -- 50
	if spare.value == 1 then -- 50
		localRef.current = 9 -- 53
		localSignal.value = 8 -- 54
	end -- 54
	local onCreate = useCallback( -- 56
		function() -- 56
			creates = creates + 1 -- 57
			return DNode() -- 58
		end, -- 56
		{} -- 59
	) -- 59
	return React.createElement("custom-node", {key = "custom", ref = customRef, x = tick.value, onCreate = onCreate}) -- 60
end -- 43
local function MemoLabel() -- 63
	local memo = useMemo( -- 64
		function() -- 64
			memoBuilds = memoBuilds + 1 -- 65
			return {text = "dep:" .. tostring(dep.value)} -- 66
		end, -- 64
		{dep.value} -- 67
	) -- 67
	return React.createElement( -- 68
		"label", -- 68
		{ -- 68
			key = "label", -- 68
			ref = labelRef, -- 68
			fontName = "sarasa-mono-sc-regular", -- 68
			fontSize = 18, -- 68
			text = (memo.text .. ";spare:") .. tostring(spare.value) -- 68
		} -- 68
	) -- 68
end -- 63
root:render(function() return React.createElement( -- 79
	"node", -- 79
	nil, -- 79
	React.createElement(StableCustom, nil), -- 79
	React.createElement(MemoLabel, nil) -- 79
) end) -- 79
local customNode = customRef.current -- 86
expect(customNode ~= nil, "custom node was not mounted") -- 87
expect(creates == 1, "custom node should be created once on mount") -- 88
expect(memoBuilds == 1, "memo should build once on mount") -- 89
expect(labelRef.current.text == "dep:1;spare:0", "initial memo label text was wrong") -- 90
tick.value = 10 -- 92
spare.value = 1 -- 93
Director.systemScheduler:schedule(once(function() -- 95
	expect(customRef.current == customNode, "stable useCallback should prevent custom-node recreation") -- 96
	expect(creates == 1, "stable custom onCreate should not run again") -- 97
	expect(customRef.current.x == 10, "custom node prop should still patch after stable callback render") -- 98
	expect(stableRefObject ~= nil and stableRefObject.current == 9, "useRef should reuse the same ref object across renders") -- 99
	expect(localSignalObject ~= nil and localSignalObject.value == 8, "useSignal should reuse the same signal across renders") -- 100
	expect(memoBuilds == 1, "useMemo should not rebuild when deps are unchanged") -- 101
	expect(labelRef.current.text == "dep:1;spare:1", "label should still patch with memoized value") -- 102
	dep.value = 2 -- 104
	Director.systemScheduler:schedule(once(function() -- 106
		expect(memoBuilds == 2, "useMemo should rebuild when deps change") -- 107
		expect(labelRef.current.text == "dep:2;spare:1", "label should render rebuilt memo value") -- 108
		root:unmount() -- 109
		expect(not host.hasChildren, "hook memo test unmount did not clear host") -- 110
		host:removeFromParent(true) -- 111
		Content:save(resultFile, "passed") -- 112
		Log("Info", "[DoraXHookMemoTest] passed") -- 113
	end)) -- 106
end)) -- 95
return ____exports -- 95