-- [tsx]: HookKeyedDiffTest.tsx
local ____exports = {} -- 1
local countFor, NestedItem, host, itemRefs, nestedNodes, nestedCreateCounts -- 1
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
local useRef = ____DoraX.useRef -- 3
local useSignal = ____DoraX.useSignal -- 3
function countFor(____table, id) -- 70
	return ____table[id] or 0 -- 71
end -- 71
function NestedItem(props) -- 121
	local ____props_2 = props -- 122
	local id = ____props_2.id -- 122
	local onCreate = useCallback( -- 123
		function() -- 123
			nestedCreateCounts[id] = countFor(nestedCreateCounts, id) + 1 -- 124
			return DNode() -- 125
		end, -- 123
		{id} -- 126
	) -- 126
	local onMount = useCallback( -- 127
		function(node) -- 127
			nestedNodes[id] = node -- 128
		end, -- 127
		{id} -- 129
	) -- 129
	return React.createElement("custom-node", {key = id, onCreate = onCreate, onMount = onMount}) -- 130
end -- 130
local resultFile = Path(Content.writablePath, "DoraXHookKeyedDiffTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXHookKeyedDiffTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local function expectSameNode(id, node, message) -- 17
	expect( -- 18
		node ~= nil, -- 18
		(message .. " missing baseline node ") .. tostring(id) -- 18
	) -- 18
	expect(itemRefs[id].current == node, message) -- 19
end -- 17
local function expectHostOrder(expected, message) -- 22
	local children = host.children -- 23
	expect(children ~= nil, message .. " missing host children") -- 24
	expect(children.count == #expected, message .. " child count mismatch") -- 25
	for i = 1, #expected do -- 25
		local child = children:get(i) -- 27
		expect( -- 28
			child.tag == "item-" .. tostring(expected[i]), -- 28
			(((((message .. " child ") .. tostring(i)) .. " expected item-") .. tostring(expected[i])) .. ", got ") .. child.tag -- 28
		) -- 28
	end -- 28
end -- 22
local function nextFrame(callback) -- 32
	Director.systemScheduler:schedule(once(callback)) -- 33
end -- 32
host = DNode() -- 36
Director.entry:addChild(host) -- 37
local root = createRoot(host) -- 45
local items = signal({{id = 1, kind = "a"}, {id = 2, kind = "a"}, {id = 3, kind = "a"}, {id = 4, kind = "a"}}) -- 46
itemRefs = {} -- 52
local itemNodes = {} -- 53
nestedNodes = {} -- 54
local localRefs = {} -- 55
local localSignals = {} -- 56
local createCounts = {} -- 57
nestedCreateCounts = {} -- 58
local unmountCounts = {} -- 59
local function getItemRef(id) -- 61
	local ref = itemRefs[id] -- 62
	if ref == nil then -- 62
		ref = reference() -- 64
		itemRefs[id] = ref -- 65
	end -- 65
	return ref -- 67
end -- 61
local function ItemA(props) -- 74
	local ____props_0 = props -- 75
	local id = ____props_0.id -- 75
	local localRef = useRef(id) -- 76
	local localSignal = useSignal(id * 10) -- 77
	if localRefs[id] == nil then -- 77
		localRefs[id] = localRef -- 79
	end -- 79
	if localSignals[id] == nil then -- 79
		localSignals[id] = localSignal -- 82
	end -- 82
	local onCreate = useCallback( -- 84
		function() -- 84
			createCounts[id] = countFor(createCounts, id) + 1 -- 85
			return DNode() -- 86
		end, -- 84
		{id} -- 87
	) -- 87
	local onMount = useCallback( -- 88
		function(node) -- 88
			itemNodes[id] = node -- 89
		end, -- 88
		{id} -- 90
	) -- 90
	local onUnmount = useCallback( -- 91
		function() -- 91
			unmountCounts[id] = countFor(unmountCounts, id) + 1 -- 92
		end, -- 91
		{id} -- 93
	) -- 93
	return React.createElement( -- 94
		"custom-node", -- 94
		{ -- 94
			key = id, -- 94
			ref = getItemRef(id), -- 94
			tag = "item-" .. tostring(id), -- 94
			x = id, -- 94
			onCreate = onCreate, -- 94
			onMount = onMount, -- 94
			onUnmount = onUnmount -- 94
		}, -- 94
		React.createElement(NestedItem, {key = id, id = id}) -- 94
	) -- 94
end -- 74
local function ItemB(props) -- 109
	local ____props_1 = props -- 110
	local id = ____props_1.id -- 110
	local onCreate = useCallback( -- 111
		function() -- 111
			createCounts[id] = countFor(createCounts, id) + 1 -- 112
			return DNode() -- 113
		end, -- 111
		{id} -- 114
	) -- 114
	local onMount = useCallback( -- 115
		function(node) -- 115
			itemNodes[id] = node -- 116
		end, -- 115
		{id} -- 117
	) -- 117
	return React.createElement( -- 118
		"custom-node", -- 118
		{ -- 118
			key = id, -- 118
			ref = getItemRef(id), -- 118
			tag = "item-" .. tostring(id), -- 118
			x = id * 10, -- 118
			onCreate = onCreate, -- 118
			onMount = onMount -- 118
		} -- 118
	) -- 118
end -- 109
local function renderItems() -- 133
	local elements = {} -- 134
	for i = 1, #items.value do -- 134
		local item = items.value[i] -- 136
		if item.kind == "a" then -- 136
			elements[#elements + 1] = React.createElement(ItemA, {key = item.id, id = item.id}) -- 138
		else -- 138
			elements[#elements + 1] = React.createElement(ItemB, {key = item.id, id = item.id}) -- 140
		end -- 140
	end -- 140
	return elements -- 143
end -- 133
root:render(renderItems) -- 146
local node1 = itemRefs[1].current -- 148
local node2 = itemRefs[2].current -- 149
local node3 = itemRefs[3].current -- 150
local node4 = itemRefs[4].current -- 151
local nested1 = nestedNodes[1] -- 152
local nested3 = nestedNodes[3] -- 153
local ref1 = localRefs[1] -- 154
local ref3 = localRefs[3] -- 155
local signal1 = localSignals[1] -- 156
local signal3 = localSignals[3] -- 157
expect(node1 ~= nil and node2 ~= nil and node3 ~= nil and node4 ~= nil, "initial keyed nodes were not mounted") -- 158
expect(nested1 ~= nil and nested3 ~= nil, "initial nested keyed nodes were not mounted") -- 159
expect(createCounts[1] == 1 and createCounts[4] == 1, "initial items should be created once") -- 160
expect(nestedCreateCounts[1] == 1 and nestedCreateCounts[3] == 1, "initial nested items should be created once") -- 161
expectHostOrder({1, 2, 3, 4}, "initial host children order") -- 162
items.value = {{id = 4, kind = "a"}, {id = 2, kind = "a"}, {id = 1, kind = "a"}, {id = 3, kind = "a"}} -- 164
nextFrame(function() -- 171
	expectSameNode(1, node1, "reordered keyed item 1 should keep node") -- 172
	expectSameNode(2, node2, "reordered keyed item 2 should keep node") -- 173
	expectSameNode(3, node3, "reordered keyed item 3 should keep node") -- 174
	expectSameNode(4, node4, "reordered keyed item 4 should keep node") -- 175
	expect(nestedNodes[1] == nested1, "nested keyed child should keep node after parent reorder") -- 176
	expect(localRefs[1] == ref1 and localSignals[1] == signal1, "useRef/useSignal should follow reordered key 1") -- 177
	expect(localRefs[3] == ref3 and localSignals[3] == signal3, "useRef/useSignal should follow reordered key 3") -- 178
	expect(createCounts[1] == 1 and createCounts[4] == 1, "reorder should not recreate keyed items") -- 179
	expect(nestedCreateCounts[1] == 1 and nestedCreateCounts[3] == 1, "reorder should not recreate nested keyed items") -- 180
	expectHostOrder({4, 2, 1, 3}, "reordered host children order") -- 181
	items.value = { -- 183
		{id = 4, kind = "a"}, -- 184
		{id = 2, kind = "a"}, -- 185
		{id = 5, kind = "a"}, -- 186
		{id = 1, kind = "a"}, -- 187
		{id = 3, kind = "a"} -- 188
	} -- 188
	nextFrame(function() -- 191
		local node5 = itemRefs[5].current -- 192
		expectSameNode(1, node1, "insert before keyed item 1 should keep node") -- 193
		expectSameNode(3, node3, "insert before keyed item 3 should keep node") -- 194
		expectSameNode(4, node4, "insert should keep earlier keyed item 4") -- 195
		expect(node5 ~= nil, "inserted keyed item 5 was not mounted") -- 196
		expect(createCounts[5] == 1, "inserted keyed item 5 should be created once") -- 197
		expect(createCounts[1] == 1 and createCounts[3] == 1, "insert should not recreate following keyed items") -- 198
		expectHostOrder({ -- 199
			4, -- 199
			2, -- 199
			5, -- 199
			1, -- 199
			3 -- 199
		}, "inserted host children order") -- 199
		items.value = {{id = 4, kind = "a"}, {id = 1, kind = "a"}, {id = 6, kind = "a"}, {id = 3, kind = "a"}} -- 201
		nextFrame(function() -- 208
			local node6 = itemRefs[6].current -- 209
			expectSameNode(1, node1, "delete insert reorder should keep keyed item 1") -- 210
			expectSameNode(3, node3, "delete insert reorder should keep keyed item 3") -- 211
			expectSameNode(4, node4, "delete insert reorder should keep keyed item 4") -- 212
			expect(node6 ~= nil, "mixed update inserted keyed item 6 was not mounted") -- 213
			expect(itemRefs[2].current == nil, "removed keyed item 2 ref should be cleared") -- 214
			expect(itemRefs[5].current == nil, "removed keyed item 5 ref should be cleared") -- 215
			expect(unmountCounts[2] == 1, "removed keyed item 2 should unmount once") -- 216
			expect(createCounts[1] == 1 and createCounts[3] == 1 and createCounts[4] == 1, "mixed update should not recreate kept keyed items") -- 217
			expectHostOrder({4, 1, 6, 3}, "mixed update host children order") -- 218
			items.value = {{id = 4, kind = "a"}, {id = 1, kind = "b"}, {id = 6, kind = "a"}, {id = 3, kind = "a"}} -- 220
			nextFrame(function() -- 227
				expect(itemRefs[1].current ~= node1, "same key with different component type should recreate item 1") -- 228
				expect(createCounts[1] == 2, "type change should create item 1 again") -- 229
				expectSameNode(3, node3, "type change of sibling should keep keyed item 3") -- 230
				expectSameNode(4, node4, "type change of sibling should keep keyed item 4") -- 231
				expectHostOrder({4, 1, 6, 3}, "type change host children order") -- 232
				root:unmount() -- 233
				expect(not host.hasChildren, "hook keyed diff test unmount did not clear host") -- 234
				host:removeFromParent(true) -- 235
				Content:save(resultFile, "passed") -- 236
				Log("Info", "[DoraXHookKeyedDiffTest] passed") -- 237
			end) -- 227
		end) -- 208
	end) -- 191
end) -- 171
return ____exports -- 171