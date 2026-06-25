-- [tsx]: RootUnmountTest.tsx
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
local resultFile = Path(Content.writablePath, "DoraXRootUnmountTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXRootUnmountTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local value = signal(0) -- 20
local labelRef = reference() -- 21
local renders = 0 -- 22
root:render(function() -- 24
	renders = renders + 1 -- 25
	return React.createElement( -- 26
		"label", -- 26
		{ -- 26
			ref = labelRef, -- 26
			fontName = "sarasa-mono-sc-regular", -- 26
			fontSize = 18, -- 26
			text = "value:" .. tostring(value.value) -- 26
		} -- 26
	) -- 26
end) -- 24
expect(renders == 1, "initial render count was wrong") -- 29
expect(host.hasChildren, "initial root render did not mount child") -- 30
root:unmount() -- 32
expect(not host.hasChildren, "unmount should remove root children") -- 33
value.value = 1 -- 35
Director.systemScheduler:schedule(once(function() -- 37
	expect(renders == 1, "unmounted root should not update after signal change") -- 38
	root:render(function() -- 40
		renders = renders + 1 -- 41
		return React.createElement( -- 42
			"label", -- 42
			{ -- 42
				ref = labelRef, -- 42
				fontName = "sarasa-mono-sc-regular", -- 42
				fontSize = 18, -- 42
				text = "value:" .. tostring(value.value) -- 42
			} -- 42
		) -- 42
	end) -- 40
	expect(renders == 2, "unmounted root should be renderable again") -- 44
	expect(labelRef.current.text == "value:1", "rerendered root did not read latest signal value") -- 45
	value.value = 2 -- 47
	Director.systemScheduler:schedule(once(function() -- 49
		expect(renders == 3, "rerendered root should subscribe to signal again") -- 50
		expect(labelRef.current.text == "value:2", "rerendered root did not patch signal value") -- 51
		root:unmount() -- 52
		host:removeFromParent(true) -- 53
		Content:save(resultFile, "passed") -- 54
		Log("Info", "[DoraXRootUnmountTest] passed") -- 55
	end)) -- 49
end)) -- 37
return ____exports -- 37