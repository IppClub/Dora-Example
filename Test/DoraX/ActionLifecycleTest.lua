-- [tsx]: ActionLifecycleTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Ease = ____Dora.Ease -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local toAction = ____DoraX.toAction -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXActionLifecycleTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXActionLifecycleTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local host = DNode() -- 17
Director.entry:addChild(host) -- 18
local root = createRoot(host) -- 20
local nodeRef = useRef() -- 21
local enters = 0 -- 22
local exits = 0 -- 23
local cleanups = 0 -- 24
local mounts = 0 -- 25
local action = toAction(React.createElement( -- 27
	"sequence", -- 27
	nil, -- 27
	React.createElement("scale", {time = 0.01, start = 1, stop = 1.1, easing = Ease.OutQuad}), -- 27
	React.createElement("move-x", {time = 0.01, start = 0, stop = 8}) -- 27
)) -- 27
expect(action ~= nil, "toAction should build a sequence action") -- 33
Director.systemScheduler:schedule(once(function() -- 35
	root:render(React.createElement( -- 36
		"node", -- 36
		{ -- 36
			key = "tracked", -- 36
			ref = nodeRef, -- 36
			onMount = function(node) -- 36
				mounts = mounts + 1 -- 41
				node:perform(action) -- 42
			end, -- 40
			onEnter = function() -- 40
				enters = enters + 1 -- 45
			end, -- 44
			onExit = function() -- 44
				exits = exits + 1 -- 48
			end, -- 47
			onCleanup = function() -- 47
				cleanups = cleanups + 1 -- 51
			end -- 50
		} -- 50
	)) -- 50
	local tracked = nodeRef.current -- 56
	expect(tracked ~= nil, "tracked node was not mounted") -- 57
	expect(mounts == 1, "onMount should run once on initial mount") -- 58
	Director.systemScheduler:schedule(once(function() -- 60
		root:render({}) -- 61
		Director.systemScheduler:schedule(once(function() -- 63
			expect(mounts == 1, "onMount should not rerun when node is removed") -- 64
			expect(not host.hasChildren, "diff removal should clear tracked node from host") -- 65
			root:render(React.createElement( -- 67
				"node", -- 67
				{ -- 67
					key = "tracked", -- 67
					ref = nodeRef, -- 67
					onEnter = function() -- 67
						enters = enters + 1 -- 72
					end, -- 71
					onExit = function() -- 71
						exits = exits + 1 -- 75
					end, -- 74
					onCleanup = function() -- 74
						cleanups = cleanups + 1 -- 78
					end -- 77
				} -- 77
			)) -- 77
			Director.systemScheduler:schedule(once(function() -- 83
				expect(nodeRef.current ~= tracked, "removed node should mount as a new instance when added again") -- 84
				root:unmount() -- 86
				Director.systemScheduler:schedule(once(function() -- 88
					expect(not host.hasChildren, "lifecycle unmount did not clear host") -- 89
					host:removeFromParent(true) -- 90
					Content:save(resultFile, "passed") -- 91
					Log("Info", "[DoraXActionLifecycleTest] passed") -- 92
				end)) -- 88
			end)) -- 83
		end)) -- 63
	end)) -- 60
end)) -- 35
return ____exports -- 35