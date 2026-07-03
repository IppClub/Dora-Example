-- [tsx]: TextMultilineTest.tsx
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
local ____UIX = require("UIX") -- 4
local Column = ____UIX.Column -- 4
local Text = ____UIX.Text -- 4
local resultFile = Path(Content.writablePath, "UIXTextMultilineTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXTextMultilineTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local plainRef = reference() -- 21
local wrapRef = reference() -- 22
root:render(function() return React.createElement( -- 24
	"align-node", -- 24
	{windowRoot = true, style = {padding = 8}}, -- 24
	React.createElement( -- 24
		Column, -- 26
		{style = {width = 260, gap = 8}}, -- 26
		React.createElement(Text, { -- 26
			ref = plainRef, -- 26
			key = "plain-newline", -- 26
			text = "First line\nSecond line", -- 26
			alignment = "Left", -- 26
			verticalAlign = "top" -- 26
		}), -- 26
		React.createElement(Text, { -- 26
			ref = wrapRef, -- 26
			key = "wrap-newline", -- 26
			text = "Alpha beta gamma\nDelta epsilon zeta", -- 26
			alignment = "Left", -- 26
			wrap = true, -- 26
			style = {width = 120} -- 26
		}) -- 26
	) -- 26
) end) -- 26
Director.systemScheduler:schedule(once(function() -- 46
	expect(plainRef.current ~= nil, "plain multiline text did not mount") -- 47
	expect(wrapRef.current ~= nil, "wrapped multiline text did not mount") -- 48
	expect( -- 49
		plainRef.current.height >= 40, -- 49
		"plain multiline height is too small: " .. tostring(plainRef.current.height) -- 49
	) -- 49
	expect( -- 50
		wrapRef.current.height >= 40, -- 50
		"wrapped multiline height is too small: " .. tostring(wrapRef.current.height) -- 50
	) -- 50
	Content:save(resultFile, "passed") -- 51
	Log("Info", "[UIXTextMultilineTest] passed") -- 52
	host:removeFromParent(true) -- 53
	root:unmount() -- 54
end)) -- 46
return ____exports -- 46