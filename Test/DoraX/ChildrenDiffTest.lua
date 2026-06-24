-- [tsx]: ChildrenDiffTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXChildrenDiffTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXChildrenDiffTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local aRef = useRef() -- 20
local bRef = useRef() -- 21
local cRef = useRef() -- 22
local dRef = useRef() -- 23
root:render(React.createElement( -- 25
	"node", -- 25
	nil, -- 25
	React.createElement("node", {key = "a", ref = aRef, x = 1}), -- 25
	React.createElement("node", {key = "b", ref = bRef, x = 2}), -- 25
	React.createElement("node", {key = "c", ref = cRef, x = 3}) -- 25
)) -- 25
local a = aRef.current -- 33
local b = bRef.current -- 34
local c = cRef.current -- 35
expect(a ~= nil and b ~= nil and c ~= nil, "initial keyed children were not mounted") -- 36
root:render(React.createElement( -- 38
	"node", -- 38
	nil, -- 38
	React.createElement("node", {key = "c", ref = cRef, x = 30}), -- 38
	React.createElement("node", {key = "a", ref = aRef, x = 10}), -- 38
	React.createElement("node", {key = "d", ref = dRef, x = 40}) -- 38
)) -- 38
expect(cRef.current == c, "keyed child c should survive move to front") -- 46
expect(aRef.current == a, "keyed child a should survive move to middle") -- 47
expect(dRef.current ~= nil, "inserted keyed child d was not mounted") -- 48
expect(dRef.current ~= b, "new key d must not reuse removed key b") -- 49
expect(cRef.current.x == 30, "moved child c was not patched") -- 50
expect(aRef.current.x == 10, "moved child a was not patched") -- 51
expect(dRef.current.x == 40, "inserted child d prop was not applied") -- 52
local firstRef = useRef() -- 54
local secondRef = useRef() -- 55
root:render(React.createElement( -- 56
	"node", -- 56
	nil, -- 56
	React.createElement("node", {ref = firstRef, x = 5}), -- 56
	React.createElement("node", {ref = secondRef, x = 6}) -- 56
)) -- 56
local first = firstRef.current -- 62
local second = secondRef.current -- 63
expect(first ~= nil and second ~= nil, "initial unkeyed children were not mounted") -- 64
root:render(React.createElement( -- 66
	"node", -- 66
	nil, -- 66
	React.createElement("node", {ref = firstRef, x = 50}), -- 66
	React.createElement("node", {ref = secondRef, x = 60}) -- 66
)) -- 66
expect(firstRef.current == first, "first unkeyed child should be reused by index") -- 72
expect(secondRef.current == second, "second unkeyed child should be reused by index") -- 73
expect(firstRef.current.x == 50, "first unkeyed child prop was not patched") -- 74
expect(secondRef.current.x == 60, "second unkeyed child prop was not patched") -- 75
root:render({ -- 77
	React.createElement("node", {key = "multi-a", ref = aRef, x = 7}), -- 77
	React.createElement("node", {key = "multi-b", ref = bRef, x = 8}) -- 77
}) -- 77
expect(host.hasChildren, "multi-root render did not mount children") -- 81
expect(aRef.current ~= nil and bRef.current ~= nil, "multi-root children refs were not assigned") -- 82
root:unmount() -- 84
expect(not host.hasChildren, "unmount did not remove diffed children") -- 85
host:removeFromParent(true) -- 86
Content:save(resultFile, "passed") -- 87
Log("Info", "[DoraXChildrenDiffTest] passed") -- 88
return ____exports -- 88