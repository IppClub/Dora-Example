-- [tsx]: ActionDiffTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local once = ____Dora.once -- 1
local Dora = require("Dora") -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local reference = ____DoraX.reference -- 3
local signal = ____DoraX.signal -- 3
local resultFile = Path(Content.writablePath, "DoraXActionDiffTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	Content:save(resultFile, "failed: " .. message) -- 9
	error("[DoraXActionDiffTest] " .. message) -- 10
end -- 8
local function expect(condition, message) -- 13
	if not condition then -- 13
		fail(message) -- 14
	end -- 14
end -- 13
local function afterFrames(frames, callback) -- 17
	if frames <= 0 then -- 17
		callback() -- 19
		return -- 20
	end -- 20
	Director.systemScheduler:schedule(once(function() -- 22
		afterFrames(frames - 1, callback) -- 23
	end)) -- 22
end -- 17
local host = DNode() -- 27
local exclusiveHost = DNode() -- 28
local loopHost = DNode() -- 29
local multiHost = DNode() -- 30
local conflictHost = DNode() -- 31
Director.entry:addChild(host) -- 32
Director.entry:addChild(exclusiveHost) -- 33
Director.entry:addChild(loopHost) -- 34
Director.entry:addChild(multiHost) -- 35
Director.entry:addChild(conflictHost) -- 36
local root = createRoot(host) -- 38
local exclusiveRoot = createRoot(exclusiveHost) -- 39
local loopRoot = createRoot(loopHost) -- 40
local multiRoot = createRoot(multiHost) -- 41
local conflictRoot = createRoot(conflictHost) -- 42
local nodeRef = reference() -- 43
local exclusiveRef = reference() -- 44
local loopRef = reference() -- 45
local multiRef = reference() -- 46
local conflictRef = reference() -- 47
local nodeY = signal(0) -- 48
local actionStop = signal(10) -- 49
local exclusiveStop = signal(100) -- 50
local loopStop = signal(40) -- 51
local multiStop = signal(30) -- 52
local actionEnds = 0 -- 53
local exclusiveEnds = 0 -- 54
local warningCount = 0 -- 55
local doraRuntime = Dora -- 57
local originalLog = doraRuntime.Log -- 60
root:render(function() return React.createElement( -- 62
	"node", -- 62
	{ -- 62
		key = "animated", -- 62
		ref = nodeRef, -- 62
		y = nodeY.value, -- 62
		onActionEnd = function() -- 62
			actionEnds = actionEnds + 1 -- 68
		end -- 67
	}, -- 67
	React.createElement("move-x", {time = 0.01, start = 0, stop = actionStop.value}) -- 67
) end) -- 67
local node = nodeRef.current -- 75
expect(node ~= nil, "animated node was not mounted") -- 76
exclusiveRoot:render(function() return React.createElement( -- 78
	"node", -- 78
	{ -- 78
		key = "exclusive", -- 78
		ref = exclusiveRef, -- 78
		onActionEnd = function() -- 78
			exclusiveEnds = exclusiveEnds + 1 -- 83
		end -- 82
	}, -- 82
	React.createElement("move-x", {exclusive = true, time = exclusiveStop.value == 100 and 0.5 or 0.01, start = 0, stop = exclusiveStop.value}) -- 82
) end) -- 82
local exclusiveNode = exclusiveRef.current -- 95
expect(exclusiveNode ~= nil, "exclusive animated node was not mounted") -- 96
loopRoot:render(function() return React.createElement( -- 98
	"node", -- 98
	{key = "loop-exclusive", ref = loopRef}, -- 98
	React.createElement( -- 98
		"loop", -- 98
		{exclusive = true}, -- 98
		React.createElement("move-x", {time = 0.01, start = 0, stop = loopStop.value}), -- 98
		React.createElement("delay", {time = 0.5}) -- 98
	) -- 98
) end) -- 98
local loopNode = loopRef.current -- 107
expect(loopNode ~= nil, "loop exclusive node was not mounted") -- 108
multiRoot:render(function() return React.createElement( -- 110
	"node", -- 110
	{key = "multi-exclusive", ref = multiRef}, -- 110
	React.createElement("move-x", {exclusive = true, time = 0.01, start = 0, stop = multiStop.value}), -- 110
	React.createElement("move-y", {exclusive = true, time = 0.01, start = 0, stop = -multiStop.value}) -- 110
) end) -- 110
local multiNode = multiRef.current -- 117
expect(multiNode ~= nil, "multi exclusive node was not mounted") -- 118
doraRuntime.Log = function(level, msg) -- 120
	if level == "Warn" and ({string.find(msg, "exclusive action children")}) ~= nil then -- 120
		warningCount = warningCount + 1 -- 122
		return -- 123
	end -- 123
	originalLog(level, msg) -- 125
end -- 120
conflictRoot:render(React.createElement( -- 128
	"node", -- 128
	{key = "conflict", ref = conflictRef}, -- 128
	React.createElement( -- 128
		"loop", -- 128
		{exclusive = true}, -- 128
		React.createElement("move-x", {time = 0.01, start = 0, stop = 25}), -- 128
		React.createElement("delay", {time = 0.5}) -- 128
	), -- 128
	React.createElement("move-y", {exclusive = true, time = 0.01, start = 0, stop = 25}) -- 128
)) -- 128
local conflictNode = conflictRef.current -- 138
expect(conflictNode ~= nil, "conflict exclusive node was not mounted") -- 139
doraRuntime.Log = originalLog -- 140
afterFrames( -- 142
	8, -- 142
	function() -- 142
		expect(actionEnds == 1, "initial action child should run on mount") -- 143
		expect(nodeRef.current == node, "initial action should keep mounted node") -- 144
		expect(nodeRef.current.x == 10, "initial action did not apply final x") -- 145
		expect(loopRef.current == loopNode, "loop exclusive should keep mounted node") -- 146
		expect(loopRef.current.x == 40, "loop exclusive should run on mount") -- 147
		expect(multiRef.current == multiNode, "multi exclusive should keep mounted node") -- 148
		expect(multiRef.current.x == 30 and multiRef.current.y == -30, "multiple exclusive action children should run as a spawn") -- 149
		expect(warningCount == 1, "mixed loop and non-loop exclusive actions should warn once") -- 150
		expect(conflictRef.current == conflictNode, "conflict exclusive should keep mounted node") -- 151
		expect(conflictRef.current.x == 25, "first exclusive loop group should run during conflict") -- 152
		expect(conflictRef.current.y == 0, "conflicting non-loop exclusive group should be ignored") -- 153
		nodeY.value = 5 -- 155
		afterFrames( -- 157
			2, -- 157
			function() -- 157
				expect(nodeRef.current == node, "ordinary prop patch should reuse animated node") -- 158
				expect(nodeRef.current.y == 5, "ordinary prop patch did not apply") -- 159
				expect(actionEnds == 1, "unchanged action child should not run again") -- 160
				actionStop.value = 20 -- 162
				afterFrames( -- 164
					8, -- 164
					function() -- 164
						expect(nodeRef.current == node, "changed action child should patch animated node") -- 165
						expect(actionEnds == 2, "changed action child should run again") -- 166
						expect(nodeRef.current.x == 20, "changed action did not apply final x") -- 167
						exclusiveStop.value = 200 -- 169
						afterFrames( -- 171
							8, -- 171
							function() -- 171
								expect(exclusiveRef.current == exclusiveNode, "exclusive action patch should reuse node") -- 172
								expect(exclusiveEnds == 1, "exclusive action patch should replace the previous running action") -- 173
								expect(exclusiveRef.current.x == 200, "exclusive action patch should not be overwritten by the previous action") -- 174
								loopStop.value = 80 -- 176
								multiStop.value = 60 -- 177
								afterFrames( -- 179
									8, -- 179
									function() -- 179
										expect(loopRef.current == loopNode, "loop exclusive patch should reuse node") -- 180
										expect(loopRef.current.x == 80, "loop exclusive patch should perform with loop=true") -- 181
										expect(multiRef.current == multiNode, "multi exclusive patch should reuse node") -- 182
										expect(multiRef.current.x == 60 and multiRef.current.y == -60, "multiple exclusive patch should perform as a spawn") -- 183
										root:unmount() -- 184
										exclusiveRoot:unmount() -- 185
										loopRoot:unmount() -- 186
										multiRoot:unmount() -- 187
										conflictRoot:unmount() -- 188
										expect(not host.hasChildren, "action diff unmount did not clear host") -- 189
										expect(not exclusiveHost.hasChildren, "exclusive action diff unmount did not clear host") -- 190
										expect(not loopHost.hasChildren, "loop exclusive action diff unmount did not clear host") -- 191
										expect(not multiHost.hasChildren, "multi exclusive action diff unmount did not clear host") -- 192
										expect(not conflictHost.hasChildren, "conflict exclusive action diff unmount did not clear host") -- 193
										host:removeFromParent(true) -- 194
										exclusiveHost:removeFromParent(true) -- 195
										loopHost:removeFromParent(true) -- 196
										multiHost:removeFromParent(true) -- 197
										conflictHost:removeFromParent(true) -- 198
										Content:save(resultFile, "passed") -- 199
										Log("Info", "[DoraXActionDiffTest] passed") -- 200
									end -- 179
								) -- 179
							end -- 171
						) -- 171
					end -- 164
				) -- 164
			end -- 157
		) -- 157
	end -- 142
) -- 142
return ____exports -- 142