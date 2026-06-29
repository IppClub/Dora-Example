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
local keyedItems = signal({1, 2, 3, 4}) -- 26
local creates = 0 -- 27
local memoBuilds = 0 -- 28
local keyedCreates = 0 -- 29
local stableRefObject -- 30
local localSignalObject -- 31
local keyedNodes = {} -- 32
local keyedCreateCounts = {} -- 33
local plainRef = reference(1) -- 35
expect(plainRef.current == 1, "reference should be available outside function components") -- 36
local useRefOk, outsideRef = pcall(function() return useRef(1) end) -- 38
local useSignalOk = pcall(function() return useSignal(1) end) -- 39
local useMemoOk = pcall(function() return useMemo( -- 40
	function() return 1 end, -- 40
	{} -- 40
) end) -- 40
local useCallbackOk = pcall(function() return useCallback( -- 41
	function() return 1 end, -- 41
	{} -- 41
) end) -- 41
expect(useRefOk and outsideRef.current == 1, "useRef should fall back to reference outside function components") -- 42
expect(not useSignalOk, "useSignal should throw outside function components") -- 43
expect(not useMemoOk, "useMemo should throw outside function components") -- 44
expect(not useCallbackOk, "useCallback should throw outside function components") -- 45
local function StableCustom() -- 47
	local localRef = useRef(3) -- 48
	local localSignal = useSignal(5) -- 49
	if stableRefObject == nil then -- 49
		stableRefObject = localRef -- 51
	end -- 51
	if localSignalObject == nil then -- 51
		localSignalObject = localSignal -- 54
	end -- 54
	if spare.value == 1 then -- 54
		localRef.current = 9 -- 57
		localSignal.value = 8 -- 58
	end -- 58
	local onCreate = useCallback( -- 60
		function() -- 60
			creates = creates + 1 -- 61
			return DNode() -- 62
		end, -- 60
		{} -- 63
	) -- 63
	return React.createElement("custom-node", {key = "custom", ref = customRef, x = tick.value, onCreate = onCreate}) -- 64
end -- 47
local function MemoLabel() -- 67
	local memo = useMemo( -- 68
		function() -- 68
			memoBuilds = memoBuilds + 1 -- 69
			return {text = "dep:" .. tostring(dep.value)} -- 70
		end, -- 68
		{dep.value} -- 71
	) -- 71
	return React.createElement( -- 72
		"label", -- 72
		{ -- 72
			key = "label", -- 72
			ref = labelRef, -- 72
			fontName = "sarasa-mono-sc-regular", -- 72
			fontSize = 18, -- 72
			text = (memo.text .. ";spare:") .. tostring(spare.value) -- 72
		} -- 72
	) -- 72
end -- 67
local function KeyedCustom(props) -- 83
	local ____props_0 = props -- 84
	local id = ____props_0.id -- 84
	local onCreate = useCallback( -- 85
		function() -- 85
			keyedCreates = keyedCreates + 1 -- 86
			keyedCreateCounts[id] = (keyedCreateCounts[id] or 0) + 1 -- 87
			return DNode() -- 88
		end, -- 85
		{id} -- 89
	) -- 89
	local onMount = useCallback( -- 90
		function(node) -- 90
			keyedNodes[id] = node -- 91
		end, -- 90
		{id} -- 92
	) -- 92
	return React.createElement("custom-node", {key = id, x = spare.value, onCreate = onCreate, onMount = onMount}) -- 93
end -- 83
local function renderKeyedItems() -- 103
	local elements = { -- 104
		React.createElement(StableCustom, {key = "stable"}), -- 104
		React.createElement(MemoLabel, {key = "memo"}) -- 104
	} -- 104
	for i = 1, #keyedItems.value do -- 104
		local id = keyedItems.value[i] -- 109
		elements[#elements + 1] = React.createElement(KeyedCustom, {key = id, id = id}) -- 110
	end -- 110
	return elements -- 112
end -- 103
root:render(renderKeyedItems) -- 115
local customNode = customRef.current -- 117
local keyedNode3 = keyedNodes[3] -- 118
local keyedNode4 = keyedNodes[4] -- 119
expect(customNode ~= nil, "custom node was not mounted") -- 120
expect(keyedNode3 ~= nil and keyedNode4 ~= nil, "initial keyed custom nodes were not mounted") -- 121
expect(creates == 1, "custom node should be created once on mount") -- 122
expect(keyedCreates == 4, "keyed custom nodes should be created once on mount") -- 123
expect(memoBuilds == 1, "memo should build once on mount") -- 124
expect(labelRef.current.text == "dep:1;spare:0", "initial memo label text was wrong") -- 125
tick.value = 10 -- 127
spare.value = 1 -- 128
Director.systemScheduler:schedule(once(function() -- 130
	expect(customRef.current == customNode, "stable useCallback should prevent custom-node recreation") -- 131
	expect(creates == 1, "stable custom onCreate should not run again") -- 132
	expect(customRef.current.x == 10, "custom node prop should still patch after stable callback render") -- 133
	expect(stableRefObject ~= nil and stableRefObject.current == 9, "useRef should reuse the same ref object across renders") -- 134
	expect(localSignalObject ~= nil and localSignalObject.value == 8, "useSignal should reuse the same signal across renders") -- 135
	expect(memoBuilds == 1, "useMemo should not rebuild when deps are unchanged") -- 136
	expect(labelRef.current.text == "dep:1;spare:1", "label should still patch with memoized value") -- 137
	keyedItems.value = {1, 3, 4} -- 139
	Director.systemScheduler:schedule(once(function() -- 141
		expect(keyedNodes[3] == keyedNode3, "keyed function component after deletion should keep node 3") -- 142
		expect(keyedNodes[4] == keyedNode4, "keyed function component after deletion should keep node 4") -- 143
		expect(keyedCreates == 4, "deleting a keyed function component should not recreate following items") -- 144
		expect(keyedCreateCounts[3] == 1, "keyed function component 3 should keep its hook callback") -- 145
		expect(keyedCreateCounts[4] == 1, "keyed function component 4 should keep its hook callback") -- 146
		dep.value = 2 -- 148
		Director.systemScheduler:schedule(once(function() -- 150
			expect(memoBuilds == 2, "useMemo should rebuild when deps change") -- 151
			expect(labelRef.current.text == "dep:2;spare:1", "label should render rebuilt memo value") -- 152
			root:unmount() -- 153
			expect(not host.hasChildren, "hook memo test unmount did not clear host") -- 154
			host:removeFromParent(true) -- 155
			Content:save(resultFile, "passed") -- 156
			Log("Info", "[DoraXHookMemoTest] passed") -- 157
		end)) -- 150
	end)) -- 141
end)) -- 130
return ____exports -- 130
