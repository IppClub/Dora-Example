-- [tsx]: LayoutPatchTest.tsx
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
local ____UIX = require("UIX") -- 4
local UiProvider = ____UIX.UiProvider -- 4
local resultFile = Path(Content.writablePath, "UIXLayoutPatchTest.result") -- 6
Content:save(resultFile, "running") -- 7
local function fail(message) -- 9
	Content:save(resultFile, "failed: " .. message) -- 10
	error("[UIXLayoutPatchTest] " .. message) -- 11
end -- 9
local function expect(condition, message) -- 14
	if not condition then -- 14
		fail(message) -- 15
	end -- 15
end -- 14
local host = DNode() -- 18
Director.ui:addChild(host) -- 19
local root = createRoot(host) -- 20
local wide = signal(false) -- 21
local panelRef = reference() -- 22
local layoutCount = 0 -- 23
local renderCount = 0 -- 24
local function pass() -- 26
	Content:save(resultFile, "passed") -- 27
	Log("Info", "[UIXLayoutPatchTest] passed") -- 28
	host:removeFromParent(true) -- 29
	root:unmount() -- 30
end -- 26
local function waitForPatch(framesLeft, firstNode) -- 33
	expect(panelRef.current ~= nil, "panel ref missing") -- 34
	if renderCount >= 2 then -- 34
		expect( -- 36
			renderCount >= 2, -- 36
			"root did not rerender after signal; renderCount=" .. tostring(renderCount) -- 36
		) -- 36
		expect(panelRef.current == firstNode, "style patch rebuilt align-node instead of patching it") -- 37
		pass() -- 38
		return -- 39
	end -- 39
	if framesLeft <= 0 then -- 39
		fail((("root did not rerender after signal; renderCount=" .. tostring(renderCount)) .. "; layoutCount=") .. tostring(layoutCount)) -- 42
	end -- 42
	Director.systemScheduler:schedule(once(function() return waitForPatch(framesLeft - 1, firstNode) end)) -- 44
end -- 33
root:render(function() -- 47
	renderCount = renderCount + 1 -- 48
	return React.createElement( -- 49
		UiProvider, -- 50
		nil, -- 50
		React.createElement( -- 50
			"align-node", -- 50
			{windowRoot = true, style = {padding = 8}}, -- 50
			React.createElement( -- 50
				"align-node", -- 50
				{ -- 50
					ref = panelRef, -- 50
					style = {width = wide.value and 420 or 220, height = 120}, -- 50
					onLayout = function() -- 50
						layoutCount = layoutCount + 1 -- 56
					end -- 55
				} -- 55
			) -- 55
		) -- 55
	) -- 55
end) -- 47
Director.systemScheduler:schedule(once(function() -- 64
	expect(panelRef.current ~= nil, "panel ref missing before patch") -- 65
	local firstNode = panelRef.current -- 66
	wide.value = true -- 67
	Director.systemScheduler:schedule(once(function() return waitForPatch(8, firstNode) end)) -- 68
end)) -- 64
return ____exports -- 64