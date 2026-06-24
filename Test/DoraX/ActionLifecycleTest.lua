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
local unmounts = 0 -- 26
local action = toAction(React.createElement( -- 28
	"sequence", -- 28
	nil, -- 28
	React.createElement("scale", {time = 0.01, start = 1, stop = 1.1, easing = Ease.OutQuad}), -- 28
	React.createElement("move-x", {time = 0.01, start = 0, stop = 8}) -- 28
)) -- 28
expect(action ~= nil, "toAction should build a sequence action") -- 34
Director.systemScheduler:schedule(once(function() -- 36
	root:render(React.createElement( -- 37
		"node", -- 37
		{ -- 37
			key = "tracked", -- 37
			ref = nodeRef, -- 37
			onMount = function(node) -- 37
				mounts = mounts + 1 -- 42
				node:perform(action) -- 43
			end, -- 41
			onEnter = function() -- 41
				enters = enters + 1 -- 46
			end, -- 45
			onExit = function() -- 45
				exits = exits + 1 -- 49
			end, -- 48
			onCleanup = function() -- 48
				cleanups = cleanups + 1 -- 52
			end, -- 51
			onUnmount = function() -- 51
				unmounts = unmounts + 1 -- 55
			end -- 54
		} -- 54
	)) -- 54
	local tracked = nodeRef.current -- 60
	expect(tracked ~= nil, "tracked node was not mounted") -- 61
	expect(mounts == 1, "onMount should run once on initial mount") -- 62
	Director.systemScheduler:schedule(once(function() -- 64
		root:render({}) -- 65
		Director.systemScheduler:schedule(once(function() -- 67
			expect(mounts == 1, "onMount should not rerun when node is removed") -- 68
			expect(not host.hasChildren, "diff removal should clear tracked node from host") -- 69
			expect(unmounts == 1, "onUnmount should run when diff removes node") -- 70
			root:render(React.createElement( -- 72
				"node", -- 72
				{ -- 72
					key = "tracked", -- 72
					ref = nodeRef, -- 72
					onEnter = function() -- 72
						enters = enters + 1 -- 77
					end, -- 76
					onExit = function() -- 76
						exits = exits + 1 -- 80
					end, -- 79
					onCleanup = function() -- 79
						cleanups = cleanups + 1 -- 83
					end, -- 82
					onUnmount = function() -- 82
						unmounts = unmounts + 1 -- 86
					end -- 85
				} -- 85
			)) -- 85
			Director.systemScheduler:schedule(once(function() -- 91
				expect(nodeRef.current ~= tracked, "removed node should mount as a new instance when added again") -- 92
				root:unmount() -- 94
				Director.systemScheduler:schedule(once(function() -- 96
					expect(not host.hasChildren, "lifecycle unmount did not clear host") -- 97
					expect(unmounts == 2, "onUnmount should run during root unmount") -- 98
					host:removeFromParent(true) -- 99
					Content:save(resultFile, "passed") -- 100
					Log("Info", "[DoraXActionLifecycleTest] passed") -- 101
				end)) -- 96
			end)) -- 91
		end)) -- 67
	end)) -- 64
end)) -- 36
return ____exports -- 36