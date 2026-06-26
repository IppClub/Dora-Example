-- [tsx]: UserTestDemo.tsx
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
local ____Button = require("UIX.controls.Button") -- 4
local Button = ____Button.Button -- 4
local ____Column = require("UIX.layout.Column") -- 5
local Column = ____Column.Column -- 5
local ____CooldownButton = require("UIX.game.CooldownButton") -- 6
local CooldownButton = ____CooldownButton.CooldownButton -- 6
local ____HealthBar = require("UIX.game.HealthBar") -- 7
local HealthBar = ____HealthBar.HealthBar -- 7
local ____InventoryGrid = require("UIX.game.InventoryGrid") -- 8
local InventoryGrid = ____InventoryGrid.InventoryGrid -- 8
local ____Panel = require("UIX.layout.Panel") -- 9
local Panel = ____Panel.Panel -- 9
local ____ProgressBar = require("UIX.controls.ProgressBar") -- 10
local ProgressBar = ____ProgressBar.ProgressBar -- 10
local ____ResourceCounter = require("UIX.game.ResourceCounter") -- 11
local ResourceCounter = ____ResourceCounter.ResourceCounter -- 11
local ____Row = require("UIX.layout.Row") -- 12
local Row = ____Row.Row -- 12
local ____ScrollView = require("UIX.layout.ScrollView") -- 13
local ScrollView = ____ScrollView.ScrollView -- 13
local ____Slider = require("UIX.controls.Slider") -- 14
local Slider = ____Slider.Slider -- 14
local ____Tabs = require("UIX.controls.Tabs") -- 15
local Tabs = ____Tabs.Tabs -- 15
local ____Text = require("UIX.foundation.Text") -- 16
local Text = ____Text.Text -- 16
local ____Modal = require("UIX.overlay.Modal") -- 17
local Modal = ____Modal.Modal -- 17
local ____ToastStack = require("UIX.overlay.ToastStack") -- 18
local ToastStack = ____ToastStack.ToastStack -- 18
local ____Tooltip = require("UIX.overlay.Tooltip") -- 19
local Tooltip = ____Tooltip.Tooltip -- 19
local ____Toggle = require("UIX.controls.Toggle") -- 20
local Toggle = ____Toggle.Toggle -- 20
local host = DNode() -- 22
Director.ui:addChild(host) -- 23
local modalHost = DNode() -- 24
Director.ui:addChild(modalHost, 10000) -- 25
Director.clearColor = Color(4279113510) -- 26
local hp = signal(0.74) -- 28
local mana = signal(0.52) -- 29
local gold = signal(1460) -- 30
local gems = signal(18) -- 31
local autoRegen = signal(true) -- 32
local compact = signal(false) -- 33
local difficulty = signal(0.45) -- 34
local activeTab = signal("combat") -- 35
local selectedItem = signal("potion") -- 36
local logText = signal("Ready") -- 37
local clicks = signal(0) -- 38
local modalOpen = signal(false) -- 39
local tooltipVisible = signal(true) -- 40
local fireCooldown = signal(0) -- 41
local shieldCooldown = signal(0) -- 42
local blinkCooldown = signal(0) -- 43
local settingsOpen = signal(true) -- 44
local function pushLog(text) -- 46
	clicks.value = clicks.value + 1 -- 47
	logText.value = (text .. " #") .. tostring(clicks.value) -- 48
end -- 46
local function castFire() -- 51
	fireCooldown.value = 5 -- 52
	mana.value = math.max(0, mana.value - 0.14) -- 53
	pushLog("Fire") -- 54
end -- 51
local function castShield() -- 57
	shieldCooldown.value = 8 -- 58
	hp.value = math.min(1, hp.value + 0.12) -- 59
	pushLog("Shield") -- 60
end -- 57
local function castBlink() -- 63
	blinkCooldown.value = 3 -- 64
	gems.value = math.max(0, gems.value - 1) -- 65
	pushLog("Blink") -- 66
end -- 63
local function CombatPage() -- 69
	return React.createElement( -- 70
		Column, -- 71
		{key = "combat-page", style = {gap = 10, width = "100%"}}, -- 71
		React.createElement( -- 71
			Row, -- 72
			{gap = 10, style = {height = 72, alignItems = "center"}}, -- 72
			React.createElement(CooldownButton, {icon = "warning", cooldown = fireCooldown.value, maxCooldown = 5, onCast = castFire}), -- 72
			React.createElement(CooldownButton, {icon = "heart", cooldown = shieldCooldown.value, maxCooldown = 8, onCast = castShield}), -- 72
			React.createElement(CooldownButton, { -- 72
				icon = "mana", -- 72
				cooldown = blinkCooldown.value, -- 72
				maxCooldown = 3, -- 72
				disabled = gems.value <= 0, -- 72
				onCast = castBlink -- 72
			}) -- 72
		), -- 72
		React.createElement( -- 72
			Row, -- 77
			{gap = 10, style = {height = 42}}, -- 77
			React.createElement( -- 77
				Button, -- 78
				{ -- 78
					variant = "danger", -- 78
					icon = "warning", -- 78
					style = {width = 110}, -- 78
					onClick = function() -- 78
						hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12) -- 79
						pushLog("Damage") -- 80
					end -- 78
				}, -- 78
				"Damage" -- 78
			), -- 78
			React.createElement( -- 78
				Button, -- 84
				{ -- 84
					variant = "secondary", -- 84
					icon = "heart", -- 84
					style = {width = 96}, -- 84
					onClick = function() -- 84
						hp.value = math.min(1, hp.value + 0.18) -- 85
						pushLog("Heal") -- 86
					end -- 84
				}, -- 84
				"Heal" -- 84
			) -- 84
		) -- 84
	) -- 84
end -- 69
local function InventoryPage() -- 95
	local items = { -- 96
		{id = "potion", icon = "heart", quality = "common", count = 3}, -- 97
		{id = "crystal", icon = "mana", quality = "rare", count = gems.value}, -- 98
		{id = "bomb", icon = "warning", quality = "epic", count = 2}, -- 99
		{ -- 100
			id = "coin", -- 100
			icon = "coin", -- 100
			quality = "legendary", -- 100
			count = math.floor(gold.value / 100) -- 100
		}, -- 100
		{id = "lock", icon = "lock", quality = "common", disabled = true}, -- 101
		{id = "shield", icon = "check", quality = "rare", count = 1}, -- 102
		{id = "blink", icon = "mana", quality = "epic", count = gems.value}, -- 103
		{id = "kit", icon = "heart", quality = "common", count = 5}, -- 104
		{id = "map", icon = "gear", quality = "legendary", count = 1}, -- 105
		{id = "rune", icon = "warning", quality = "rare", count = 4}, -- 106
		{id = "empty", icon = "close", quality = "common", disabled = true} -- 107
	} -- 107
	return React.createElement( -- 109
		Column, -- 110
		{key = "inventory-page", style = {gap = 10, width = "100%", height = 264}}, -- 110
		React.createElement( -- 110
			InventoryGrid, -- 111
			{ -- 111
				key = "bag-grid", -- 111
				items = items, -- 111
				columns = 4, -- 111
				rows = 3, -- 111
				slotSize = 48, -- 111
				gap = 8, -- 111
				selectedId = selectedItem.value, -- 111
				slotSwallowTouches = false, -- 111
				onSelect = function(id) -- 111
					selectedItem.value = id -- 121
					pushLog("Item " .. id) -- 122
				end -- 120
			} -- 120
		), -- 120
		React.createElement( -- 120
			Row, -- 125
			{key = "bag-resources", gap = 12, style = {height = 42, alignItems = "center"}}, -- 125
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 125
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value, variant = "default"}) -- 125
		), -- 125
		React.createElement( -- 125
			Row, -- 129
			{key = "bag-actions", gap = 10, style = {height = 42}}, -- 129
			React.createElement( -- 129
				Button, -- 130
				{ -- 130
					variant = "secondary", -- 130
					icon = "coin", -- 130
					swallowTouches = false, -- 130
					style = {width = 120}, -- 130
					onClick = function() -- 130
						gold.value = gold.value + 75 -- 131
						pushLog("Loot") -- 132
					end -- 130
				}, -- 130
				"Loot" -- 130
			), -- 130
			React.createElement( -- 130
				Button, -- 136
				{ -- 136
					variant = "ghost", -- 136
					icon = "check", -- 136
					disabled = gold.value < 200, -- 136
					swallowTouches = false, -- 136
					style = {width = 120}, -- 136
					onClick = function() -- 136
						gold.value = gold.value - 200 -- 137
						gems.value = gems.value + 1 -- 138
						pushLog("Trade") -- 139
					end -- 136
				}, -- 136
				"Trade" -- 136
			) -- 136
		) -- 136
	) -- 136
end -- 95
local function SettingsPage() -- 148
	return React.createElement( -- 149
		Column, -- 150
		{key = "settings-page", style = {gap = 12, width = "100%"}}, -- 150
		React.createElement( -- 150
			Toggle, -- 151
			{ -- 151
				checked = autoRegen.value, -- 151
				label = "Auto Regen", -- 151
				onChange = function(value) -- 151
					autoRegen.value = value -- 152
					pushLog(value and "Regen On" or "Regen Off") -- 153
				end -- 151
			} -- 151
		), -- 151
		React.createElement( -- 151
			Toggle, -- 155
			{ -- 155
				checked = compact.value, -- 155
				label = "Compact HUD", -- 155
				onChange = function(value) -- 155
					compact.value = value -- 156
					pushLog(value and "Compact" or "Expanded") -- 157
				end -- 155
			} -- 155
		), -- 155
		React.createElement( -- 155
			Slider, -- 159
			{ -- 159
				value = difficulty.value, -- 159
				min = 0, -- 159
				max = 1, -- 159
				step = 0.05, -- 159
				showValue = true, -- 159
				onValueChange = function(value) -- 159
					difficulty.value = value -- 160
					pushLog("Difficulty") -- 161
				end -- 159
			} -- 159
		) -- 159
	) -- 159
end -- 148
local function ActivePage() -- 167
	repeat -- 167
		local ____switch18 = activeTab.value -- 167
		local ____cond18 = ____switch18 == "inventory" -- 167
		if ____cond18 then -- 167
			return React.createElement(InventoryPage, nil) -- 169
		end -- 169
		____cond18 = ____cond18 or ____switch18 == "settings" -- 169
		if ____cond18 then -- 169
			return React.createElement(SettingsPage, nil) -- 170
		end -- 170
		do -- 170
			return React.createElement(CombatPage, nil) -- 171
		end -- 171
	until true -- 171
end -- 167
local function App() -- 175
	local panelWidth = compact.value and 316 or 420 -- 176
	local pageScrollHeight = 156 -- 177
	local inventoryContentHeight = 284 -- 178
	local ____React_createElement_9 = React.createElement -- 178
	local ____array_8 = __TS__SparseArrayNew( -- 178
		"align-node", -- 178
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}}, -- 178
		React.createElement( -- 178
			Row, -- 181
			{key = "top-hud", gap = 14, style = {width = "100%", height = 58, alignItems = "center"}}, -- 181
			React.createElement( -- 181
				Column, -- 182
				{style = {width = compact.value and 220 or 320, gap = 7}}, -- 182
				React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = "100%", height = 22}}), -- 182
				React.createElement(ProgressBar, { -- 182
					value = mana.value, -- 182
					max = 1, -- 182
					variant = "mana", -- 182
					showValue = true, -- 182
					style = {width = "100%", height = 14} -- 182
				}) -- 182
			), -- 182
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 182
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value}), -- 182
			React.createElement( -- 182
				Button, -- 188
				{ -- 188
					variant = settingsOpen.value and "primary" or "secondary", -- 188
					icon = "gear", -- 188
					style = {width = 128}, -- 188
					onClick = function() -- 188
						settingsOpen.value = not settingsOpen.value -- 189
						pushLog(settingsOpen.value and "Panel Open" or "Panel Close") -- 190
					end -- 188
				}, -- 188
				"Panel" -- 188
			), -- 188
			React.createElement( -- 188
				Button, -- 194
				{ -- 194
					variant = "secondary", -- 194
					icon = "warning", -- 194
					style = {width = 128}, -- 194
					onClick = function() -- 194
						modalOpen.value = true -- 195
						pushLog("Modal") -- 196
					end -- 194
				}, -- 194
				"Modal" -- 194
			) -- 194
		) -- 194
	) -- 194
	local ____settingsOpen_value_6 -- 201
	if settingsOpen.value then -- 201
		local ____React_createElement_5 = React.createElement -- 201
		local ____Panel_3 = Panel -- 202
		local ____temp_4 = { -- 202
			key = "user-test-panel", -- 202
			title = "UIX Test", -- 202
			variant = "glass", -- 202
			padding = 14, -- 202
			headerHeight = 34, -- 202
			style = { -- 202
				position = "absolute", -- 208
				left = 18, -- 208
				top = 92, -- 208
				width = panelWidth, -- 208
				height = 280 -- 208
			} -- 208
		} -- 208
		local ____React_createElement_2 = React.createElement -- 208
		local ____array_1 = __TS__SparseArrayNew( -- 208
			Column, -- 210
			{key = "panel-body", style = {gap = 12, width = "100%"}}, -- 210
			React.createElement( -- 210
				Tabs, -- 211
				{ -- 211
					key = "main-tabs", -- 211
					value = activeTab.value, -- 211
					items = {{id = "combat", label = "Combat"}, {id = "inventory", label = "Bag"}, {id = "settings", label = "Tune"}}, -- 211
					onValueChange = function(value) -- 211
						activeTab.value = value -- 220
						pushLog(value) -- 221
					end -- 219
				} -- 219
			) -- 219
		) -- 219
		local ____temp_0 -- 224
		if activeTab.value == "inventory" then -- 224
			____temp_0 = React.createElement( -- 224
				ScrollView, -- 225
				{ -- 225
					key = "inventory-scroll", -- 225
					width = panelWidth - 28, -- 225
					height = pageScrollHeight, -- 225
					contentHeight = inventoryContentHeight, -- 225
					wheelSpeed = 18 -- 225
				}, -- 225
				React.createElement(InventoryPage, nil) -- 225
			) -- 225
		else -- 225
			____temp_0 = React.createElement(ActivePage, nil) -- 225
		end -- 225
		__TS__SparseArrayPush(____array_1, ____temp_0) -- 225
		____settingsOpen_value_6 = ____React_createElement_5( -- 225
			____Panel_3, -- 202
			____temp_4, -- 202
			____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 202
		) -- 202
	else -- 202
		____settingsOpen_value_6 = nil -- 237
	end -- 237
	__TS__SparseArrayPush( -- 237
		____array_8, -- 237
		____settingsOpen_value_6, -- 237
		React.createElement( -- 237
			Panel, -- 238
			{ -- 238
				key = "status-panel", -- 238
				title = "Status", -- 238
				variant = "solid", -- 238
				padding = 12, -- 238
				headerHeight = 30, -- 238
				style = { -- 238
					position = "absolute", -- 244
					right = 18, -- 244
					bottom = 18, -- 244
					width = 300, -- 244
					height = 132 -- 244
				} -- 244
			}, -- 244
			React.createElement( -- 244
				Column, -- 246
				{style = {gap = 8, width = "100%"}}, -- 246
				React.createElement(Text, {text = logText.value, fontSize = 18, style = {width = "100%", height = 28}}), -- 246
				React.createElement( -- 246
					Row, -- 248
					{gap = 8, style = {height = 42}}, -- 248
					React.createElement( -- 248
						Button, -- 249
						{ -- 249
							variant = "ghost", -- 249
							icon = "close", -- 249
							style = {width = 92}, -- 249
							onClick = function() -- 249
								hp.value = 0.74 -- 250
								mana.value = 0.52 -- 251
								gold.value = 1460 -- 252
								gems.value = 18 -- 253
								fireCooldown.value = 0 -- 254
								shieldCooldown.value = 0 -- 255
								blinkCooldown.value = 0 -- 256
								pushLog("Reset") -- 257
							end -- 249
						}, -- 249
						"Reset" -- 249
					), -- 249
					React.createElement( -- 249
						Button, -- 261
						{ -- 261
							variant = "secondary", -- 261
							icon = "check", -- 261
							style = {width = 108}, -- 261
							onClick = function() -- 261
								gold.value = gold.value + 10 -- 262
								mana.value = math.min(1, mana.value + 0.08) -- 263
								pushLog("Tick") -- 264
							end -- 261
						}, -- 261
						"Tick" -- 261
					) -- 261
				) -- 261
			) -- 261
		) -- 261
	) -- 261
	local ____tooltipVisible_value_7 -- 271
	if tooltipVisible.value then -- 271
		____tooltipVisible_value_7 = React.createElement(Tooltip, {key = "hint-tooltip", title = "UIX", text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", style = {position = "absolute", left = 18, bottom = 18}}) -- 271
	else -- 271
		____tooltipVisible_value_7 = nil -- 277
	end -- 277
	__TS__SparseArrayPush( -- 277
		____array_8, -- 277
		____tooltipVisible_value_7, -- 277
		React.createElement( -- 277
			ToastStack, -- 278
			{ -- 278
				key = "toast-stack", -- 278
				items = { -- 278
					{id = "last", title = "Last Action", message = logText.value}, -- 281
					{ -- 282
						id = "hp", -- 282
						message = ((("HP " .. tostring(math.floor(hp.value * 100))) .. "%  Mana ") .. tostring(math.floor(mana.value * 100))) .. "%" -- 282
					} -- 282
				}, -- 282
				style = {right = 18, top = 92} -- 282
			} -- 282
		) -- 282
	) -- 282
	return ____React_createElement_9(__TS__SparseArraySpread(____array_8)) -- 179
end -- 175
local function ModalLayer() -- 290
	return React.createElement( -- 291
		Modal, -- 292
		{ -- 292
			key = "test-modal", -- 292
			open = modalOpen.value, -- 292
			title = "UIX Modal", -- 292
			message = "This modal uses a vector backdrop and a Panel body.", -- 292
			width = 300, -- 292
			height = 196, -- 292
			actions = {{id = "loot", label = "Loot", variant = "primary"}, {id = "close", label = "Close", variant = "secondary"}}, -- 292
			onClose = function() -- 292
				modalOpen.value = false -- 304
				pushLog("Backdrop Close") -- 305
			end, -- 303
			onAction = function(id) -- 303
				if id == "loot" then -- 303
					gold.value = gold.value + 120 -- 309
					gems.value = gems.value + 1 -- 310
					pushLog("Modal Loot") -- 311
				end -- 311
				modalOpen.value = false -- 313
			end -- 307
		}, -- 307
		React.createElement( -- 307
			Toggle, -- 316
			{ -- 316
				checked = tooltipVisible.value, -- 316
				label = "Show Tooltip", -- 316
				onChange = function(value) -- 316
					tooltipVisible.value = value -- 317
					pushLog(value and "Tooltip On" or "Tooltip Off") -- 318
				end -- 316
			} -- 316
		) -- 316
	) -- 316
end -- 290
local root = createRoot(host) -- 324
root:render(function() return React.createElement(App, nil) end) -- 325
local modalRoot = createRoot(modalHost) -- 326
modalRoot:render(function() return React.createElement(ModalLayer, nil) end) -- 327
host:schedule(loop(function() -- 329
	sleep(0.25) -- 330
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 331
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25) -- 332
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25) -- 333
	if autoRegen.value then -- 333
		hp.value = math.min(1, hp.value + 0.005) -- 335
		mana.value = math.min(1, mana.value + 0.018) -- 336
	end -- 336
	return false -- 338
end)) -- 329
host:onCleanup(function() -- 341
	host:unschedule() -- 342
	root:unmount() -- 343
	modalRoot:unmount() -- 344
	modalHost:removeFromParent(true) -- 345
end) -- 341
return ____exports -- 341