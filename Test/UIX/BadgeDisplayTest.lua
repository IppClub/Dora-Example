-- [tsx]: BadgeDisplayTest.tsx
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
local Badge = ____UIX.Badge -- 4
local Row = ____UIX.Row -- 4
local resultFile = Path(Content.writablePath, "UIXBadgeDisplayTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXBadgeDisplayTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local readyRef = reference() -- 21
local rareRef = reference() -- 22
local manaRef = reference() -- 23
root:render(function() return React.createElement( -- 25
	"align-node", -- 25
	{windowRoot = true, style = {padding = 8}}, -- 25
	React.createElement( -- 25
		Row, -- 27
		{gap = 6}, -- 27
		React.createElement(Badge, {ref = readyRef, tone = "success", icon = "check"}, "Ready"), -- 27
		React.createElement(Badge, {ref = rareRef, tone = "warm", dot = true}, "Rare"), -- 27
		React.createElement(Badge, {ref = manaRef, tone = "mana", outline = true, text = "Mana"}) -- 27
	) -- 27
) end) -- 27
Director.systemScheduler:schedule(once(function() -- 35
	expect(readyRef.current ~= nil, "ready badge ref missing") -- 36
	expect(rareRef.current ~= nil, "rare badge ref missing") -- 37
	expect(manaRef.current ~= nil, "mana badge ref missing") -- 38
	expect(readyRef.current.width > 0, "ready badge width missing") -- 39
	expect(rareRef.current.height > 0, "rare badge height missing") -- 40
	Content:save(resultFile, "passed") -- 41
	Log("Info", "[UIXBadgeDisplayTest] passed") -- 42
	host:removeFromParent(true) -- 43
	root:unmount() -- 44
end)) -- 35
return ____exports -- 35