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
local ____Spacer = require("UIX.layout.Spacer") -- 14
local Spacer = ____Spacer.Spacer -- 14
local ____Select = require("UIX.controls.Select") -- 15
local Select = ____Select.Select -- 15
local ____Slider = require("UIX.controls.Slider") -- 16
local Slider = ____Slider.Slider -- 16
local ____Tabs = require("UIX.controls.Tabs") -- 17
local Tabs = ____Tabs.Tabs -- 17
local ____Text = require("UIX.foundation.Text") -- 18
local Text = ____Text.Text -- 18
local ____Modal = require("UIX.overlay.Modal") -- 19
local Modal = ____Modal.Modal -- 19
local ____ToastStack = require("UIX.overlay.ToastStack") -- 20
local ToastStack = ____ToastStack.ToastStack -- 20
local ____Tooltip = require("UIX.overlay.Tooltip") -- 21
local Tooltip = ____Tooltip.Tooltip -- 21
local ____Toggle = require("UIX.controls.Toggle") -- 22
local Toggle = ____Toggle.Toggle -- 22
local host = DNode() -- 24
Director.ui:addChild(host) -- 25
local modalHost = DNode() -- 26
Director.ui:addChild(modalHost, 10000) -- 27
Director.clearColor = Color(4279113510) -- 28
local hp = signal(0.74) -- 30
local mana = signal(0.52) -- 31
local gold = signal(1460) -- 32
local gems = signal(18) -- 33
local autoRegen = signal(true) -- 34
local compact = signal(false) -- 35
local difficulty = signal(0.45) -- 36
local activeTab = signal("combat") -- 37
local selectedItem = signal("potion") -- 38
local logText = signal("Ready") -- 39
local clicks = signal(0) -- 40
local modalOpen = signal(false) -- 41
local tooltipVisible = signal(true) -- 42
local difficultyPreset = signal("normal") -- 43
local difficultySelectOpen = signal(false) -- 44
local fireCooldown = signal(0) -- 45
local shieldCooldown = signal(0) -- 46
local blinkCooldown = signal(0) -- 47
local settingsOpen = signal(true) -- 48
local function pushLog(text) -- 50
	clicks.value = clicks.value + 1 -- 51
	logText.value = (text .. " #") .. tostring(clicks.value) -- 52
end -- 50
local function castFire() -- 55
	fireCooldown.value = 5 -- 56
	mana.value = math.max(0, mana.value - 0.14) -- 57
	pushLog("Fire") -- 58
end -- 55
local function castShield() -- 61
	shieldCooldown.value = 8 -- 62
	hp.value = math.min(1, hp.value + 0.12) -- 63
	pushLog("Shield") -- 64
end -- 61
local function castBlink() -- 67
	blinkCooldown.value = 3 -- 68
	gems.value = math.max(0, gems.value - 1) -- 69
	pushLog("Blink") -- 70
end -- 67
local function CombatPage() -- 73
	return React.createElement( -- 74
		Column, -- 75
		{key = "combat-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 126}}, -- 75
		React.createElement( -- 75
			Row, -- 76
			{gap = 10, style = {height = 72, alignItems = "center"}}, -- 76
			React.createElement(CooldownButton, {icon = "warning", cooldown = fireCooldown.value, maxCooldown = 5, onCast = castFire}), -- 76
			React.createElement(CooldownButton, {icon = "heart", cooldown = shieldCooldown.value, maxCooldown = 8, onCast = castShield}), -- 76
			React.createElement(CooldownButton, { -- 76
				icon = "mana", -- 76
				cooldown = blinkCooldown.value, -- 76
				maxCooldown = 3, -- 76
				disabled = gems.value <= 0, -- 76
				onCast = castBlink -- 76
			}) -- 76
		), -- 76
		React.createElement( -- 76
			Row, -- 81
			{gap = 10, style = {height = 42}}, -- 81
			React.createElement( -- 81
				Button, -- 82
				{ -- 82
					variant = "danger", -- 82
					icon = "warning", -- 82
					style = {width = 110}, -- 82
					onClick = function() -- 82
						hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12) -- 83
						pushLog("Damage") -- 84
					end -- 82
				}, -- 82
				"Damage" -- 82
			), -- 82
			React.createElement( -- 82
				Button, -- 88
				{ -- 88
					variant = "secondary", -- 88
					icon = "heart", -- 88
					style = {width = 96}, -- 88
					onClick = function() -- 88
						hp.value = math.min(1, hp.value + 0.18) -- 89
						pushLog("Heal") -- 90
					end -- 88
				}, -- 88
				"Heal" -- 88
			) -- 88
		) -- 88
	) -- 88
end -- 73
local function InventoryPage() -- 99
	local items = { -- 100
		{id = "potion", icon = "heart", quality = "common", count = 3}, -- 101
		{id = "crystal", icon = "mana", quality = "rare", count = gems.value}, -- 102
		{id = "bomb", icon = "warning", quality = "epic", count = 2}, -- 103
		{ -- 104
			id = "coin", -- 104
			icon = "coin", -- 104
			quality = "legendary", -- 104
			count = math.floor(gold.value / 100) -- 104
		}, -- 104
		{id = "lock", icon = "lock", quality = "common", disabled = true}, -- 105
		{id = "shield", icon = "check", quality = "rare", count = 1}, -- 106
		{id = "blink", icon = "mana", quality = "epic", count = gems.value}, -- 107
		{id = "kit", icon = "heart", quality = "common", count = 5}, -- 108
		{id = "map", icon = "gear", quality = "legendary", count = 1}, -- 109
		{id = "rune", icon = "warning", quality = "rare", count = 4}, -- 110
		{id = "empty", icon = "close", quality = "common", disabled = true} -- 111
	} -- 111
	return React.createElement( -- 113
		Column, -- 114
		{key = "inventory-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 264}}, -- 114
		React.createElement( -- 114
			InventoryGrid, -- 115
			{ -- 115
				key = "bag-grid", -- 115
				items = items, -- 115
				columns = 4, -- 115
				rows = 3, -- 115
				slotSize = 48, -- 115
				gap = 8, -- 115
				selectedId = selectedItem.value, -- 115
				slotSwallowTouches = false, -- 115
				onSelect = function(id) -- 115
					selectedItem.value = id -- 125
					pushLog("Item " .. id) -- 126
				end -- 124
			} -- 124
		), -- 124
		React.createElement( -- 124
			Row, -- 129
			{key = "bag-resources", gap = 12, style = {height = 42, alignItems = "center"}}, -- 129
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 129
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value, variant = "default"}) -- 129
		), -- 129
		React.createElement( -- 129
			Row, -- 133
			{key = "bag-actions", gap = 10, style = {height = 42}}, -- 133
			React.createElement( -- 133
				Button, -- 134
				{ -- 134
					variant = "secondary", -- 134
					icon = "coin", -- 134
					swallowTouches = false, -- 134
					style = {width = 120}, -- 134
					onClick = function() -- 134
						gold.value = gold.value + 75 -- 135
						pushLog("Loot") -- 136
					end -- 134
				}, -- 134
				"Loot" -- 134
			), -- 134
			React.createElement( -- 134
				Button, -- 140
				{ -- 140
					variant = "ghost", -- 140
					icon = "check", -- 140
					disabled = gold.value < 200, -- 140
					swallowTouches = false, -- 140
					style = {width = 120}, -- 140
					onClick = function() -- 140
						gold.value = gold.value - 200 -- 141
						gems.value = gems.value + 1 -- 142
						pushLog("Trade") -- 143
					end -- 140
				}, -- 140
				"Trade" -- 140
			) -- 140
		) -- 140
	) -- 140
end -- 99
local function SettingsPage() -- 152
	local pageHeight = difficultySelectOpen.value and 420 or 252 -- 153
	return React.createElement( -- 154
		Column, -- 155
		{key = "settings-page", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%", height = pageHeight}}, -- 155
		React.createElement( -- 155
			Toggle, -- 156
			{ -- 156
				checked = autoRegen.value, -- 156
				label = "Auto Regen", -- 156
				onChange = function(value) -- 156
					autoRegen.value = value -- 157
					pushLog(value and "Regen On" or "Regen Off") -- 158
				end -- 156
			} -- 156
		), -- 156
		React.createElement( -- 156
			Toggle, -- 160
			{ -- 160
				checked = compact.value, -- 160
				label = "Compact HUD", -- 160
				onChange = function(value) -- 160
					compact.value = value -- 161
					pushLog(value and "Compact" or "Expanded") -- 162
				end -- 160
			} -- 160
		), -- 160
		React.createElement( -- 160
			Select, -- 164
			{ -- 164
				key = "difficulty-select", -- 164
				value = difficultyPreset.value, -- 164
				items = {{id = "easy", label = "Easy", icon = "heart"}, {id = "normal", label = "Normal", icon = "check"}, {id = "hard", label = "Hard", icon = "warning"}, {id = "custom", label = "Custom", icon = "gear"}}, -- 164
				open = difficultySelectOpen.value, -- 164
				onOpenChange = function(value) -- 164
					difficultySelectOpen.value = value -- 175
				end, -- 174
				onValueChange = function(value) -- 174
					difficultyPreset.value = value -- 178
					if value == "easy" then -- 178
						difficulty.value = 0.2 -- 179
					elseif value == "hard" then -- 179
						difficulty.value = 0.8 -- 180
					else -- 180
						difficulty.value = 0.45 -- 181
					end -- 181
					pushLog("Difficulty " .. value) -- 182
				end, -- 177
				style = {width = 180} -- 177
			} -- 177
		), -- 177
		React.createElement( -- 177
			Slider, -- 186
			{ -- 186
				value = difficulty.value, -- 186
				min = 0, -- 186
				max = 1, -- 186
				step = 0.05, -- 186
				showValue = true, -- 186
				onValueChange = function(value) -- 186
					difficulty.value = value -- 187
					difficultyPreset.value = "custom" -- 188
					pushLog("Difficulty") -- 189
				end -- 186
			} -- 186
		), -- 186
		React.createElement(Spacer, {height = 16}) -- 186
	) -- 186
end -- 152
local function ActivePage() -- 196
	repeat -- 196
		local ____switch23 = activeTab.value -- 196
		local ____cond23 = ____switch23 == "inventory" -- 196
		if ____cond23 then -- 196
			return React.createElement(InventoryPage, nil) -- 198
		end -- 198
		____cond23 = ____cond23 or ____switch23 == "settings" -- 198
		if ____cond23 then -- 198
			return React.createElement(SettingsPage, nil) -- 199
		end -- 199
		do -- 199
			return React.createElement(CombatPage, nil) -- 200
		end -- 200
	until true -- 200
end -- 196
local function App() -- 204
	local panelWidth = compact.value and 316 or 420 -- 205
	local pageScrollHeight = 154 -- 206
	local inventoryContentHeight = 300 -- 207
	local settingsContentHeight = difficultySelectOpen.value and 420 or 252 -- 208
	local activeContentHeight = activeTab.value == "inventory" and inventoryContentHeight or settingsContentHeight -- 209
	local shouldScrollPage = activeTab.value == "inventory" or activeTab.value == "settings" -- 210
	local ____React_createElement_9 = React.createElement -- 210
	local ____array_8 = __TS__SparseArrayNew( -- 210
		"align-node", -- 210
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}}, -- 210
		React.createElement( -- 210
			Row, -- 213
			{key = "top-hud", gap = 14, style = {width = "100%", height = 58, alignItems = "center"}}, -- 213
			React.createElement( -- 213
				Column, -- 214
				{style = {width = compact.value and 220 or 320, gap = 7}}, -- 214
				React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = "100%", height = 22}}), -- 214
				React.createElement(ProgressBar, { -- 214
					value = mana.value, -- 214
					max = 1, -- 214
					variant = "mana", -- 214
					showValue = true, -- 214
					style = {width = "100%", height = 14} -- 214
				}) -- 214
			), -- 214
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 214
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value}), -- 214
			React.createElement( -- 214
				Button, -- 220
				{ -- 220
					variant = settingsOpen.value and "primary" or "secondary", -- 220
					icon = "gear", -- 220
					style = {width = 128}, -- 220
					onClick = function() -- 220
						settingsOpen.value = not settingsOpen.value -- 221
						pushLog(settingsOpen.value and "Panel Open" or "Panel Close") -- 222
					end -- 220
				}, -- 220
				"Panel" -- 220
			), -- 220
			React.createElement( -- 220
				Button, -- 226
				{ -- 226
					variant = "secondary", -- 226
					icon = "warning", -- 226
					style = {width = 128}, -- 226
					onClick = function() -- 226
						modalOpen.value = true -- 227
						pushLog("Modal") -- 228
					end -- 226
				}, -- 226
				"Modal" -- 226
			) -- 226
		) -- 226
	) -- 226
	local ____settingsOpen_value_6 -- 233
	if settingsOpen.value then -- 233
		local ____React_createElement_5 = React.createElement -- 233
		local ____Panel_3 = Panel -- 234
		local ____temp_4 = { -- 234
			key = "user-test-panel", -- 234
			title = "UIX Test", -- 234
			variant = "glass", -- 234
			padding = 14, -- 234
			headerHeight = 34, -- 234
			style = { -- 234
				position = "absolute", -- 240
				left = 18, -- 240
				top = 92, -- 240
				width = panelWidth, -- 240
				height = 280 -- 240
			} -- 240
		} -- 240
		local ____React_createElement_2 = React.createElement -- 240
		local ____array_1 = __TS__SparseArrayNew( -- 240
			Column, -- 242
			{key = "panel-body", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%"}}, -- 242
			React.createElement( -- 242
				Tabs, -- 243
				{ -- 243
					key = "main-tabs", -- 243
					value = activeTab.value, -- 243
					items = {{id = "combat", label = "Combat"}, {id = "inventory", label = "Bag"}, {id = "settings", label = "Tune"}}, -- 243
					onValueChange = function(value) -- 243
						activeTab.value = value -- 252
						pushLog(value) -- 253
					end -- 251
				} -- 251
			) -- 251
		) -- 251
		local ____shouldScrollPage_0 -- 256
		if shouldScrollPage then -- 256
			____shouldScrollPage_0 = React.createElement( -- 256
				ScrollView, -- 257
				{ -- 257
					key = "page-scroll-" .. activeTab.value, -- 257
					width = panelWidth - 28, -- 257
					height = pageScrollHeight, -- 257
					contentHeight = math.max(pageScrollHeight, activeContentHeight), -- 257
					wheelSpeed = 18 -- 257
				}, -- 257
				React.createElement(ActivePage, nil) -- 257
			) -- 257
		else -- 257
			____shouldScrollPage_0 = React.createElement(ActivePage, nil) -- 257
		end -- 257
		__TS__SparseArrayPush(____array_1, ____shouldScrollPage_0) -- 257
		____settingsOpen_value_6 = ____React_createElement_5( -- 257
			____Panel_3, -- 234
			____temp_4, -- 234
			____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 234
		) -- 234
	else -- 234
		____settingsOpen_value_6 = nil -- 269
	end -- 269
	__TS__SparseArrayPush( -- 269
		____array_8, -- 269
		____settingsOpen_value_6, -- 269
		React.createElement( -- 269
			Panel, -- 270
			{ -- 270
				key = "status-panel", -- 270
				title = "Status", -- 270
				variant = "solid", -- 270
				padding = 12, -- 270
				headerHeight = 30, -- 270
				style = { -- 270
					position = "absolute", -- 276
					right = 18, -- 276
					bottom = 18, -- 276
					width = 300, -- 276
					height = 132 -- 276
				} -- 276
			}, -- 276
			React.createElement( -- 276
				Column, -- 278
				{style = {gap = 8, width = "100%"}}, -- 278
				React.createElement(Text, {text = logText.value, fontSize = 18, style = {width = "100%", height = 28}}), -- 278
				React.createElement( -- 278
					Row, -- 280
					{gap = 8, style = {height = 42}}, -- 280
					React.createElement( -- 280
						Button, -- 281
						{ -- 281
							variant = "ghost", -- 281
							icon = "close", -- 281
							style = {width = 92}, -- 281
							onClick = function() -- 281
								hp.value = 0.74 -- 282
								mana.value = 0.52 -- 283
								gold.value = 1460 -- 284
								gems.value = 18 -- 285
								fireCooldown.value = 0 -- 286
								shieldCooldown.value = 0 -- 287
								blinkCooldown.value = 0 -- 288
								pushLog("Reset") -- 289
							end -- 281
						}, -- 281
						"Reset" -- 281
					), -- 281
					React.createElement( -- 281
						Button, -- 293
						{ -- 293
							variant = "secondary", -- 293
							icon = "check", -- 293
							style = {width = 108}, -- 293
							onClick = function() -- 293
								gold.value = gold.value + 10 -- 294
								mana.value = math.min(1, mana.value + 0.08) -- 295
								pushLog("Tick") -- 296
							end -- 293
						}, -- 293
						"Tick" -- 293
					) -- 293
				) -- 293
			) -- 293
		) -- 293
	) -- 293
	local ____tooltipVisible_value_7 -- 303
	if tooltipVisible.value then -- 303
		____tooltipVisible_value_7 = React.createElement(Tooltip, {key = "hint-tooltip", title = "UIX", text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", style = {position = "absolute", left = 18, bottom = 18}}) -- 303
	else -- 303
		____tooltipVisible_value_7 = nil -- 309
	end -- 309
	__TS__SparseArrayPush( -- 309
		____array_8, -- 309
		____tooltipVisible_value_7, -- 309
		React.createElement( -- 309
			ToastStack, -- 310
			{ -- 310
				key = "toast-stack", -- 310
				items = { -- 310
					{id = "last", title = "Last Action", message = logText.value}, -- 313
					{ -- 314
						id = "hp", -- 314
						message = ((("HP " .. tostring(math.floor(hp.value * 100))) .. "%  Mana ") .. tostring(math.floor(mana.value * 100))) .. "%" -- 314
					} -- 314
				}, -- 314
				style = {right = 18, top = 92} -- 314
			} -- 314
		) -- 314
	) -- 314
	return ____React_createElement_9(__TS__SparseArraySpread(____array_8)) -- 211
end -- 204
local function ModalLayer() -- 322
	return React.createElement( -- 323
		Modal, -- 324
		{ -- 324
			key = "test-modal", -- 324
			open = modalOpen.value, -- 324
			title = "UIX Modal", -- 324
			message = "This modal uses a vector backdrop and a Panel body.", -- 324
			width = 300, -- 324
			height = 196, -- 324
			actions = {{id = "loot", label = "Loot", variant = "primary"}, {id = "close", label = "Close", variant = "secondary"}}, -- 324
			onClose = function() -- 324
				modalOpen.value = false -- 336
				pushLog("Backdrop Close") -- 337
			end, -- 335
			onAction = function(id) -- 335
				if id == "loot" then -- 335
					gold.value = gold.value + 120 -- 341
					gems.value = gems.value + 1 -- 342
					pushLog("Modal Loot") -- 343
				end -- 343
				modalOpen.value = false -- 345
			end -- 339
		}, -- 339
		React.createElement( -- 339
			Toggle, -- 348
			{ -- 348
				checked = tooltipVisible.value, -- 348
				label = "Show Tooltip", -- 348
				onChange = function(value) -- 348
					tooltipVisible.value = value -- 349
					pushLog(value and "Tooltip On" or "Tooltip Off") -- 350
				end -- 348
			} -- 348
		) -- 348
	) -- 348
end -- 322
local root = createRoot(host) -- 356
root:render(function() return React.createElement(App, nil) end) -- 357
local modalRoot = createRoot(modalHost) -- 358
modalRoot:render(function() return React.createElement(ModalLayer, nil) end) -- 359
host:schedule(loop(function() -- 361
	sleep(0.25) -- 362
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 363
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25) -- 364
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25) -- 365
	if autoRegen.value then -- 365
		hp.value = math.min(1, hp.value + 0.005) -- 367
		mana.value = math.min(1, mana.value + 0.018) -- 368
	end -- 368
	return false -- 370
end)) -- 361
host:onCleanup(function() -- 373
	host:unschedule() -- 374
	root:unmount() -- 375
	modalRoot:unmount() -- 376
	modalHost:removeFromParent(true) -- 377
end) -- 373
return ____exports -- 373