-- [tsx]: HudDemo.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local DNode = ____Dora.Node -- 2
local loop = ____Dora.loop -- 2
local sleep = ____Dora.sleep -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local ____UIX = require("UIX") -- 4
local Button = ____UIX.Button -- 4
local CooldownButton = ____UIX.CooldownButton -- 4
local HealthBar = ____UIX.HealthBar -- 4
local Panel = ____UIX.Panel -- 4
local ResourceCounter = ____UIX.ResourceCounter -- 4
local Row = ____UIX.Row -- 4
local host = DNode() -- 6
Director.ui:addChild(host) -- 7
local hp = signal(0.82) -- 9
local coins = signal(1280) -- 10
local fireCooldown = signal(0) -- 11
local iceCooldown = signal(30) -- 12
local settingsOpen = signal(false) -- 13
local clicks = signal(0) -- 14
local panelWide = signal(false) -- 15
local root = createRoot(host) -- 17
local function App() -- 19
	local ____React_createElement_2 = React.createElement -- 19
	local ____array_1 = __TS__SparseArrayNew( -- 19
		"align-node", -- 19
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}}, -- 19
		React.createElement( -- 19
			Row, -- 22
			{style = {height = 52, width = "100%", alignItems = "center"}, gap = 14}, -- 22
			React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = 260, height = 22}}), -- 22
			React.createElement(ResourceCounter, {icon = "coin", value = coins.value, variant = "warm"}) -- 22
		), -- 22
		React.createElement( -- 22
			Button, -- 26
			{ -- 26
				variant = "secondary", -- 26
				icon = "gear", -- 26
				style = {position = "absolute", left = 18, top = 84, width = 190}, -- 26
				onClick = function() -- 26
					settingsOpen.value = not settingsOpen.value -- 31
					clicks.value = clicks.value + 1 -- 32
					panelWide.value = not panelWide.value -- 33
				end -- 30
			}, -- 30
			"Settings" -- 30
		) -- 30
	) -- 30
	local ____settingsOpen_value_0 -- 38
	if settingsOpen.value then -- 38
		____settingsOpen_value_0 = React.createElement( -- 38
			Panel, -- 39
			{key = "settings-panel", title = "Settings", variant = "glass", style = { -- 39
				position = "absolute", -- 43
				left = 18, -- 43
				top = 142, -- 43
				width = panelWide.value and 360 or 240, -- 43
				height = 150 -- 43
			}}, -- 43
			React.createElement( -- 43
				ResourceCounter, -- 45
				{ -- 45
					icon = "check", -- 45
					value = "Clicks " .. tostring(clicks.value), -- 45
					variant = "success" -- 45
				} -- 45
			) -- 45
		) -- 45
	else -- 45
		____settingsOpen_value_0 = nil -- 46
	end -- 46
	__TS__SparseArrayPush( -- 46
		____array_1, -- 46
		____settingsOpen_value_0, -- 46
		React.createElement( -- 46
			Panel, -- 47
			{ -- 47
				key = "skills-panel", -- 47
				title = "Skills", -- 47
				variant = "glass", -- 47
				padding = 12, -- 47
				headerHeight = 30, -- 47
				style = { -- 47
					position = "absolute", -- 53
					right = 18, -- 53
					bottom = 18, -- 53
					width = 286, -- 53
					height = 128 -- 53
				} -- 53
			}, -- 53
			React.createElement( -- 53
				Row, -- 55
				{gap = 8, style = {width = "100%", height = 56, alignItems = "center"}}, -- 55
				React.createElement( -- 55
					CooldownButton, -- 56
					{ -- 56
						icon = "heart", -- 56
						hotkey = "Q", -- 56
						cooldown = fireCooldown.value, -- 56
						maxCooldown = 5, -- 56
						onCast = function() -- 56
							fireCooldown.value = 5 -- 56
							return 5 -- 56
						end -- 56
					} -- 56
				), -- 56
				React.createElement( -- 56
					CooldownButton, -- 57
					{ -- 57
						icon = "mana", -- 57
						hotkey = "W", -- 57
						cooldown = iceCooldown.value, -- 57
						maxCooldown = 30, -- 57
						onCast = function() -- 57
							iceCooldown.value = 30 -- 57
							return 30 -- 57
						end -- 57
					} -- 57
				), -- 57
				React.createElement(CooldownButton, { -- 57
					icon = "warning", -- 57
					hotkey = "E", -- 57
					cooldown = 0, -- 57
					maxCooldown = 8, -- 57
					count = 3 -- 57
				}) -- 57
			) -- 57
		) -- 57
	) -- 57
	return ____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 20
end -- 19
root:render(function() return React.createElement(App, nil) end) -- 65
host:schedule(loop(function() -- 67
	sleep(0.25) -- 68
	hp.value = hp.value <= 0.18 and 0.95 or hp.value - 0.03 -- 69
	coins.value = coins.value + 3 -- 70
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 71
	iceCooldown.value = math.max(0, iceCooldown.value - 0.25) -- 72
	return false -- 73
end)) -- 67
host:onCleanup(function() -- 76
	host:unschedule() -- 77
	root:unmount() -- 78
end) -- 76
Director.clearColor = Color(4279310375) -- 81
return ____exports -- 81