-- [tsx]: RootFragmentTest.tsx
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
local toNode = ____DoraX.toNode -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXRootFragmentTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXRootFragmentTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local staticLabelRef = useRef() -- 16
local staticNode = toNode(React.createElement( -- 17
	React.Fragment, -- 17
	nil, -- 17
	React.createElement("label", {ref = staticLabelRef, fontName = "sarasa-mono-sc-regular", fontSize = 18}, "static"), -- 17
	React.createElement("node", {x = 12}) -- 17
)) -- 17
expect(staticNode ~= nil, "toNode fragment did not create a wrapper node") -- 23
expect(staticNode.hasChildren, "toNode fragment wrapper did not receive children") -- 24
expect(staticLabelRef.current ~= nil, "toNode did not assign label ref") -- 25
expect(staticLabelRef.current.text == "static", "toNode did not preserve primitive label text") -- 26
staticNode:removeFromParent(true) -- 27
local host = DNode() -- 29
Director.entry:addChild(host) -- 30
local root = createRoot(host) -- 32
local aRef = useRef() -- 33
local bRef = useRef() -- 34
root:render(React.createElement( -- 36
	React.Fragment, -- 36
	nil, -- 36
	React.createElement("node", {key = "a", ref = aRef, x = 1}), -- 36
	React.createElement("node", {key = "b", ref = bRef, x = 2}) -- 36
)) -- 36
local a = aRef.current -- 42
local b = bRef.current -- 43
expect(a ~= nil and b ~= nil, "root fragment children were not mounted") -- 44
expect(host.hasChildren, "root fragment did not add children to host") -- 45
root:render(React.createElement("node", {key = "a", ref = aRef, x = 3})) -- 47
expect(aRef.current == a, "root should reuse keyed child when fragment becomes single node") -- 48
expect(aRef.current.x == 3, "single-node render did not patch reused child") -- 49
expect(bRef.current == b, "removed child ref should remain last assigned value") -- 50
root:render({}) -- 52
expect(not host.hasChildren, "empty root render did not remove all children") -- 53
root:unmount() -- 55
host:removeFromParent(true) -- 56
Content:save(resultFile, "passed") -- 57
Log("Info", "[DoraXRootFragmentTest] passed") -- 58
return ____exports -- 58