-- [tsx]: UnmountCleanupTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local createRoot = ____DoraX.createRoot -- 2
local signal = ____DoraX.signal -- 2
local ____UIX = require("UIX") -- 3
local PaintNode = ____UIX.PaintNode -- 3
local UiProvider = ____UIX.UiProvider -- 3
local resultFile = Path(Content.writablePath, "UIXUnmountCleanupTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[UIXUnmountCleanupTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local host = DNode() -- 17
Director.ui:addChild(host) -- 18
local root = createRoot(host) -- 19
local width = signal(80) -- 20
local renderPasses = 0 -- 21
local mountCount = 0 -- 22
root:render(function() -- 24
	renderPasses = renderPasses + 1 -- 25
	return React.createElement( -- 26
		UiProvider, -- 27
		nil, -- 27
		React.createElement( -- 27
			"align-node", -- 27
			{windowRoot = true, style = {padding = 8}}, -- 27
			React.createElement( -- 27
				"align-node", -- 27
				{style = {width = width.value, height = 40}}, -- 27
				React.createElement( -- 27
					PaintNode, -- 30
					{ -- 30
						onMountNode = function() -- 30
							mountCount = mountCount + 1 -- 32
						end, -- 31
						painter = function() -- 31
						end -- 34
					} -- 34
				) -- 34
			) -- 34
		) -- 34
	) -- 34
end) -- 24
Director.systemScheduler:schedule(once(function() -- 42
	expect( -- 43
		mountCount == 1, -- 43
		"paint node did not mount once; mountCount=" .. tostring(mountCount) -- 43
	) -- 43
	root:unmount() -- 44
	expect(not host.hasChildren, "root unmount did not remove host children") -- 45
	local before = renderPasses -- 46
	width.value = 180 -- 47
	Director.systemScheduler:schedule(once(function() -- 48
		expect(renderPasses == before, "signal rerendered after root unmount") -- 49
		Content:save(resultFile, "passed") -- 50
		Log("Info", "[UIXUnmountCleanupTest] passed") -- 51
		host:removeFromParent(true) -- 52
	end)) -- 48
end)) -- 42
return ____exports -- 42