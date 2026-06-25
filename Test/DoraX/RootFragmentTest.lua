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
local reference = ____DoraX.reference -- 3
local toNode = ____DoraX.toNode -- 3
local resultFile = Path(Content.writablePath, "DoraXRootFragmentTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXRootFragmentTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local staticLabelRef = reference() -- 17
local staticNode = toNode(React.createElement( -- 18
	React.Fragment, -- 18
	nil, -- 18
	React.createElement("label", {ref = staticLabelRef, fontName = "sarasa-mono-sc-regular", fontSize = 18}, "static"), -- 18
	React.createElement("node", {x = 12}) -- 18
)) -- 18
expect(staticNode ~= nil, "toNode fragment did not create a wrapper node") -- 24
expect(staticNode.hasChildren, "toNode fragment wrapper did not receive children") -- 25
expect(staticLabelRef.current ~= nil, "toNode did not assign label ref") -- 26
expect(staticLabelRef.current.text == "static", "toNode did not preserve primitive label text") -- 27
staticNode:removeFromParent(true) -- 28
local host = DNode() -- 30
Director.entry:addChild(host) -- 31
local root = createRoot(host) -- 33
local aRef = reference() -- 34
local bRef = reference() -- 35
root:render(React.createElement( -- 37
	React.Fragment, -- 37
	nil, -- 37
	React.createElement("node", {key = "a", ref = aRef, x = 1}), -- 37
	React.createElement("node", {key = "b", ref = bRef, x = 2}) -- 37
)) -- 37
local a = aRef.current -- 43
local b = bRef.current -- 44
expect(a ~= nil and b ~= nil, "root fragment children were not mounted") -- 45
expect(host.hasChildren, "root fragment did not add children to host") -- 46
root:render(React.createElement("node", {key = "a", ref = aRef, x = 3})) -- 48
expect(aRef.current == a, "root should reuse keyed child when fragment becomes single node") -- 49
expect(aRef.current.x == 3, "single-node render did not patch reused child") -- 50
expect(bRef.current == nil, "removed child ref should be cleared") -- 51
root:render({}) -- 53
expect(not host.hasChildren, "empty root render did not remove all children") -- 54
root:unmount() -- 56
host:removeFromParent(true) -- 57
Content:save(resultFile, "passed") -- 58
Log("Info", "[DoraXRootFragmentTest] passed") -- 59
return ____exports -- 59