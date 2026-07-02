-- [tsx]: UserTestDemo.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local DoraApp = ____Dora.App -- 2
local Color = ____Dora.Color -- 2
local Director = ____Dora.Director -- 2
local DNode = ____Dora.Node -- 2
local loop = ____Dora.loop -- 2
local sleep = ____Dora.sleep -- 2
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local signal = ____DoraX.signal -- 3
local useSignal = ____DoraX.useSignal -- 3
local useCallback = ____DoraX.useCallback -- 3
local ____Button = require("UIX.controls.Button") -- 4
local Button = ____Button.Button -- 4
local ____Checkbox = require("UIX.controls.Checkbox") -- 5
local Checkbox = ____Checkbox.Checkbox -- 5
local ____Column = require("UIX.layout.Column") -- 6
local Column = ____Column.Column -- 6
local ____CooldownButton = require("UIX.game.CooldownButton") -- 7
local CooldownButton = ____CooldownButton.CooldownButton -- 7
local ____HealthBar = require("UIX.game.HealthBar") -- 8
local HealthBar = ____HealthBar.HealthBar -- 8
local ____InventoryGrid = require("UIX.game.InventoryGrid") -- 9
local InventoryGrid = ____InventoryGrid.InventoryGrid -- 9
local ____Panel = require("UIX.layout.Panel") -- 10
local Panel = ____Panel.Panel -- 10
local ____ProgressBar = require("UIX.controls.ProgressBar") -- 11
local ProgressBar = ____ProgressBar.ProgressBar -- 11
local ____RadioGroup = require("UIX.controls.RadioGroup") -- 12
local RadioGroup = ____RadioGroup.RadioGroup -- 12
local ____ResourceCounter = require("UIX.game.ResourceCounter") -- 13
local ResourceCounter = ____ResourceCounter.ResourceCounter -- 13
local ____Row = require("UIX.layout.Row") -- 14
local Row = ____Row.Row -- 14
local ____ScrollView = require("UIX.layout.ScrollView") -- 15
local ScrollView = ____ScrollView.ScrollView -- 15
local ____Select = require("UIX.controls.Select") -- 17
local Select = ____Select.Select -- 17
local ____Slider = require("UIX.controls.Slider") -- 18
local Slider = ____Slider.Slider -- 18
local ____Tabs = require("UIX.controls.Tabs") -- 19
local Tabs = ____Tabs.Tabs -- 19
local ____TextInput = require("UIX.controls.TextInput") -- 20
local TextInput = ____TextInput.TextInput -- 20
local ____Text = require("UIX.foundation.Text") -- 21
local Text = ____Text.Text -- 21
local ____Modal = require("UIX.overlay.Modal") -- 22
local Modal = ____Modal.Modal -- 22
local ____ToastStack = require("UIX.overlay.ToastStack") -- 23
local ToastStack = ____ToastStack.ToastStack -- 23
local ____Tooltip = require("UIX.overlay.Tooltip") -- 24
local Tooltip = ____Tooltip.Tooltip -- 24
local ____Toggle = require("UIX.controls.Toggle") -- 25
local Toggle = ____Toggle.Toggle -- 25
local host = DNode() -- 27
Director.ui:addChild(host) -- 28
local modalHost = DNode() -- 29
Director.ui:addChild(modalHost, 10000) -- 30
Director.clearColor = Color(4279113510) -- 31
local hp = signal(0.74) -- 33
local mana = signal(0.52) -- 34
local gold = signal(1460) -- 35
local gems = signal(18) -- 36
local autoRegen = signal(true) -- 37
local compact = signal(false) -- 38
local lootHints = signal(true) -- 39
local expertMode = signal(false) -- 40
local targetMode = signal("assist") -- 41
local difficulty = signal(0.45) -- 42
local activeTab = signal("combat") -- 43
local selectedItem = signal("potion") -- 44
local logText = signal("Ready") -- 45
local clicks = signal(0) -- 46
local modalOpen = signal(false) -- 47
local tooltipVisible = signal(true) -- 48
local difficultyPreset = signal("normal") -- 49
local difficultySelectOpen = signal(false) -- 50
local playerName = signal("Dora") -- 51
local fireCooldown = signal(0) -- 52
local shieldCooldown = signal(0) -- 53
local blinkCooldown = signal(0) -- 54
local settingsOpen = signal(true) -- 55
local function pushLog(text) -- 57
	clicks.value = clicks.value + 1 -- 58
	logText.value = (text .. " #") .. tostring(clicks.value) -- 59
end -- 57
local function castFire() -- 62
	fireCooldown.value = 5 -- 63
	mana.value = math.max(0, mana.value - 0.14) -- 64
	pushLog("Fire") -- 65
end -- 62
local function castShield() -- 68
	shieldCooldown.value = 8 -- 69
	hp.value = math.min(1, hp.value + 0.12) -- 70
	pushLog("Shield") -- 71
end -- 68
local function castBlink() -- 74
	blinkCooldown.value = 3 -- 75
	gems.value = math.max(0, gems.value - 1) -- 76
	pushLog("Blink") -- 77
end -- 74
local function CombatPage() -- 80
	return React.createElement( -- 81
		Column, -- 82
		{key = "combat-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 126}}, -- 82
		React.createElement( -- 82
			Row, -- 83
			{gap = 10, style = {height = 72, alignItems = "center"}}, -- 83
			React.createElement(CooldownButton, {icon = "warning", cooldown = fireCooldown.value, maxCooldown = 5, onCast = castFire}), -- 83
			React.createElement(CooldownButton, {icon = "heart", cooldown = shieldCooldown.value, maxCooldown = 8, onCast = castShield}), -- 83
			React.createElement(CooldownButton, { -- 83
				icon = "mana", -- 83
				cooldown = blinkCooldown.value, -- 83
				maxCooldown = 3, -- 83
				disabled = gems.value <= 0, -- 83
				onCast = castBlink -- 83
			}) -- 83
		), -- 83
		React.createElement( -- 83
			Row, -- 88
			{gap = 10, style = {height = 42}}, -- 88
			React.createElement( -- 88
				Button, -- 89
				{ -- 89
					variant = "danger", -- 89
					icon = "warning", -- 89
					style = {width = 110}, -- 89
					onClick = function() -- 89
						hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12) -- 90
						pushLog("Damage") -- 91
					end -- 89
				}, -- 89
				"Damage" -- 89
			), -- 89
			React.createElement( -- 89
				Button, -- 95
				{ -- 95
					variant = "secondary", -- 95
					icon = "heart", -- 95
					style = {width = 96}, -- 95
					onClick = function() -- 95
						hp.value = math.min(1, hp.value + 0.18) -- 96
						pushLog("Heal") -- 97
					end -- 95
				}, -- 95
				"Heal" -- 95
			) -- 95
		) -- 95
	) -- 95
end -- 80
local function InventoryPage() -- 106
	local items = { -- 107
		{id = "potion", icon = "heart", quality = "common", count = 3}, -- 108
		{id = "crystal", icon = "mana", quality = "rare", count = gems.value}, -- 109
		{id = "bomb", icon = "warning", quality = "epic", count = 2}, -- 110
		{ -- 111
			id = "coin", -- 111
			icon = "coin", -- 111
			quality = "legendary", -- 111
			count = math.floor(gold.value / 100) -- 111
		}, -- 111
		{id = "lock", icon = "lock", quality = "common", disabled = true}, -- 112
		{id = "shield", icon = "check", quality = "rare", count = 1}, -- 113
		{id = "blink", icon = "mana", quality = "epic", count = gems.value}, -- 114
		{id = "kit", icon = "heart", quality = "common", count = 5}, -- 115
		{id = "map", icon = "gear", quality = "legendary", count = 1}, -- 116
		{id = "rune", icon = "warning", quality = "rare", count = 4}, -- 117
		{id = "empty", icon = "close", quality = "common", disabled = true} -- 118
	} -- 118
	return React.createElement( -- 120
		Column, -- 121
		{key = "inventory-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 264}}, -- 121
		React.createElement( -- 121
			InventoryGrid, -- 122
			{ -- 122
				key = "bag-grid", -- 122
				items = items, -- 122
				columns = 4, -- 122
				rows = 3, -- 122
				slotSize = 48, -- 122
				gap = 8, -- 122
				selectedId = selectedItem.value, -- 122
				slotSwallowTouches = false, -- 122
				onSelect = function(id) -- 122
					selectedItem.value = id -- 132
					pushLog("Item " .. id) -- 133
				end -- 131
			} -- 131
		), -- 131
		React.createElement( -- 131
			Row, -- 136
			{key = "bag-resources", gap = 12, style = {height = 42, alignItems = "center"}}, -- 136
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 136
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value, variant = "default"}) -- 136
		), -- 136
		React.createElement( -- 136
			Row, -- 140
			{key = "bag-actions", gap = 10, style = {height = 42}}, -- 140
			React.createElement( -- 140
				Button, -- 141
				{ -- 141
					variant = "secondary", -- 141
					icon = "coin", -- 141
					swallowTouches = false, -- 141
					style = {width = 120}, -- 141
					onClick = function() -- 141
						gold.value = gold.value + 75 -- 142
						pushLog("Loot") -- 143
					end -- 141
				}, -- 141
				"Loot" -- 141
			), -- 141
			React.createElement( -- 141
				Button, -- 147
				{ -- 147
					variant = "ghost", -- 147
					icon = "check", -- 147
					disabled = gold.value < 200, -- 147
					swallowTouches = false, -- 147
					style = {width = 120}, -- 147
					onClick = function() -- 147
						gold.value = gold.value - 200 -- 148
						gems.value = gems.value + 1 -- 149
						pushLog("Trade") -- 150
					end -- 147
				}, -- 147
				"Trade" -- 147
			) -- 147
		) -- 147
	) -- 147
end -- 106
local function SettingsPage() -- 159
	local pageHeight = difficultySelectOpen.value and 600 or 432 -- 160
	return React.createElement( -- 161
		Column, -- 162
		{key = "settings-page", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%", height = pageHeight}}, -- 162
		React.createElement( -- 162
			Toggle, -- 163
			{ -- 163
				checked = autoRegen.value, -- 163
				label = "Auto Regen", -- 163
				onChange = function(value) -- 163
					autoRegen.value = value -- 164
					pushLog(value and "Regen On" or "Regen Off") -- 165
				end -- 163
			} -- 163
		), -- 163
		React.createElement( -- 163
			Toggle, -- 167
			{ -- 167
				checked = compact.value, -- 167
				label = "Compact HUD", -- 167
				onChange = function(value) -- 167
					compact.value = value -- 168
					pushLog(value and "Compact" or "Expanded") -- 169
				end -- 167
			} -- 167
		), -- 167
		React.createElement( -- 167
			Checkbox, -- 171
			{ -- 171
				checked = lootHints.value, -- 171
				label = "Loot Hints", -- 171
				onChange = function(value) -- 171
					lootHints.value = value -- 172
					pushLog(value and "Hints On" or "Hints Off") -- 173
				end -- 171
			} -- 171
		), -- 171
		React.createElement( -- 171
			Checkbox, -- 175
			{ -- 175
				checked = expertMode.value, -- 175
				indeterminate = not expertMode.value and difficultyPreset.value == "custom", -- 175
				label = "Expert Rules", -- 175
				onChange = function(value) -- 175
					expertMode.value = value -- 176
					pushLog(value and "Expert On" or "Expert Off") -- 177
				end -- 175
			} -- 175
		), -- 175
		React.createElement( -- 175
			RadioGroup, -- 179
			{ -- 179
				key = "target-mode-radio", -- 179
				value = targetMode.value, -- 179
				direction = "row", -- 179
				itemWidth = 108, -- 179
				items = {{id = "assist", label = "Assist", icon = "heart"}, {id = "manual", label = "Manual", icon = "warning"}}, -- 179
				onValueChange = function(value) -- 179
					targetMode.value = value -- 189
					pushLog("Mode " .. value) -- 190
				end -- 188
			} -- 188
		), -- 188
		React.createElement( -- 188
			Select, -- 193
			{ -- 193
				key = "difficulty-select", -- 193
				value = difficultyPreset.value, -- 193
				items = {{id = "easy", label = "Easy", icon = "heart"}, {id = "normal", label = "Normal", icon = "check"}, {id = "hard", label = "Hard", icon = "warning"}, {id = "custom", label = "Custom", icon = "gear"}}, -- 193
				open = difficultySelectOpen.value, -- 193
				onOpenChange = function(value) -- 193
					difficultySelectOpen.value = value -- 204
				end, -- 203
				onValueChange = function(value) -- 203
					difficultyPreset.value = value -- 207
					if value == "easy" then -- 207
						difficulty.value = 0.2 -- 208
					elseif value == "hard" then -- 208
						difficulty.value = 0.8 -- 209
					else -- 209
						difficulty.value = 0.45 -- 210
					end -- 210
					pushLog("Difficulty " .. value) -- 211
				end, -- 206
				style = {width = 180} -- 206
			} -- 206
		), -- 206
		React.createElement( -- 206
			Slider, -- 215
			{ -- 215
				value = difficulty.value, -- 215
				min = 0, -- 215
				max = 1, -- 215
				step = 0.05, -- 215
				showValue = true, -- 215
				onValueChange = function(value) -- 215
					difficulty.value = value -- 216
					difficultyPreset.value = "custom" -- 217
					pushLog("Difficulty") -- 218
				end -- 215
			} -- 215
		), -- 215
		React.createElement( -- 215
			TextInput, -- 220
			{ -- 220
				key = "player-name-input", -- 220
				value = playerName.value, -- 220
				placeholder = "Player name", -- 220
				prefixIcon = "gear", -- 220
				maxLength = 18, -- 220
				style = {width = 220}, -- 220
				onValueChange = function(value) -- 220
					playerName.value = value -- 228
				end, -- 227
				onSubmit = function(value) return pushLog(value == "" and "Name Empty" or "Name " .. value) end -- 227
			} -- 227
		) -- 227
	) -- 227
end -- 159
local function ActivePage() -- 236
	repeat -- 236
		local ____switch28 = activeTab.value -- 236
		local ____cond28 = ____switch28 == "inventory" -- 236
		if ____cond28 then -- 236
			return React.createElement(InventoryPage, nil) -- 238
		end -- 238
		____cond28 = ____cond28 or ____switch28 == "settings" -- 238
		if ____cond28 then -- 238
			return React.createElement(SettingsPage, nil) -- 239
		end -- 239
		do -- 239
			return React.createElement(CombatPage, nil) -- 240
		end -- 240
	until true -- 240
end -- 236
local function App() -- 244
	local panelWidth = compact.value and 316 or 420 -- 245
	local panelTop = 92 -- 246
	local minPanelHeight = 280 -- 247
	local tooltipReserveHeight = 88 -- 248
	local panelToTooltipGap = 16 -- 249
	local panelHeight = useSignal(math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap)) -- 250
	local pageScrollHeight = math.max(154, panelHeight.value - 126) -- 251
	local inventoryContentHeight = 300 -- 252
	local settingsContentHeight = difficultySelectOpen.value and 600 or 432 -- 253
	local activeContentHeight = activeTab.value == "inventory" and inventoryContentHeight or settingsContentHeight -- 254
	local shouldScrollPage = activeTab.value == "inventory" or activeTab.value == "settings" -- 255
	local onLayout = useCallback( -- 256
		function(w, h) -- 256
			panelHeight.value = math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap) -- 257
		end, -- 256
		{ -- 258
			minPanelHeight, -- 258
			panelHeight.value, -- 258
			panelToTooltipGap, -- 258
			panelTop, -- 258
			tooltipReserveHeight -- 258
		} -- 258
	) -- 258
	local ____React_createElement_9 = React.createElement -- 258
	local ____array_8 = __TS__SparseArrayNew( -- 258
		"align-node", -- 258
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}, onLayout = onLayout}, -- 258
		React.createElement( -- 258
			Row, -- 261
			{key = "top-hud", gap = 14, style = {width = "100%", height = 58, alignItems = "center"}}, -- 261
			React.createElement( -- 261
				Column, -- 262
				{style = {width = compact.value and 220 or 320, gap = 7}}, -- 262
				React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = "100%", height = 22}}), -- 262
				React.createElement(ProgressBar, { -- 262
					value = mana.value, -- 262
					max = 1, -- 262
					variant = "mana", -- 262
					showValue = true, -- 262
					style = {width = "100%", height = 14} -- 262
				}) -- 262
			), -- 262
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 262
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value}), -- 262
			React.createElement( -- 262
				Button, -- 268
				{ -- 268
					variant = settingsOpen.value and "primary" or "secondary", -- 268
					icon = "gear", -- 268
					style = {width = 128}, -- 268
					onClick = function() -- 268
						settingsOpen.value = not settingsOpen.value -- 269
						pushLog(settingsOpen.value and "Panel Open" or "Panel Close") -- 270
					end -- 268
				}, -- 268
				"Panel" -- 268
			), -- 268
			React.createElement( -- 268
				Button, -- 274
				{ -- 274
					variant = "secondary", -- 274
					icon = "warning", -- 274
					style = {width = 128}, -- 274
					onClick = function() -- 274
						modalOpen.value = true -- 275
						pushLog("Modal") -- 276
					end -- 274
				}, -- 274
				"Modal" -- 274
			) -- 274
		) -- 274
	) -- 274
	local ____settingsOpen_value_6 -- 281
	if settingsOpen.value then -- 281
		local ____React_createElement_5 = React.createElement -- 281
		local ____Panel_3 = Panel -- 282
		local ____temp_4 = { -- 282
			key = "user-test-panel", -- 282
			title = "UIX Test", -- 282
			variant = "glass", -- 282
			padding = 14, -- 282
			headerHeight = 34, -- 282
			style = { -- 282
				position = "absolute", -- 288
				left = 18, -- 288
				top = panelTop, -- 288
				width = panelWidth, -- 288
				height = panelHeight.value -- 288
			} -- 288
		} -- 288
		local ____React_createElement_2 = React.createElement -- 288
		local ____array_1 = __TS__SparseArrayNew( -- 288
			Column, -- 290
			{key = "panel-body", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%"}}, -- 290
			React.createElement( -- 290
				Tabs, -- 291
				{ -- 291
					key = "main-tabs", -- 291
					value = activeTab.value, -- 291
					items = {{id = "combat", label = "Combat"}, {id = "inventory", label = "Bag"}, {id = "settings", label = "Tune"}}, -- 291
					onValueChange = function(value) -- 291
						activeTab.value = value -- 300
						pushLog(value) -- 301
					end -- 299
				} -- 299
			) -- 299
		) -- 299
		local ____shouldScrollPage_0 -- 304
		if shouldScrollPage then -- 304
			____shouldScrollPage_0 = React.createElement( -- 304
				ScrollView, -- 305
				{ -- 305
					key = "page-scroll-" .. activeTab.value, -- 305
					width = panelWidth - 28, -- 305
					height = pageScrollHeight, -- 305
					contentHeight = math.max(pageScrollHeight, activeContentHeight), -- 305
					wheelSpeed = 18 -- 305
				}, -- 305
				React.createElement(ActivePage, nil) -- 305
			) -- 305
		else -- 305
			____shouldScrollPage_0 = React.createElement(ActivePage, nil) -- 305
		end -- 305
		__TS__SparseArrayPush(____array_1, ____shouldScrollPage_0) -- 305
		____settingsOpen_value_6 = ____React_createElement_5( -- 305
			____Panel_3, -- 282
			____temp_4, -- 282
			____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 282
		) -- 282
	else -- 282
		____settingsOpen_value_6 = nil -- 317
	end -- 317
	__TS__SparseArrayPush( -- 317
		____array_8, -- 317
		____settingsOpen_value_6, -- 317
		React.createElement( -- 317
			Panel, -- 318
			{ -- 318
				key = "status-panel", -- 318
				title = "Status", -- 318
				variant = "solid", -- 318
				padding = 12, -- 318
				headerHeight = 30, -- 318
				style = { -- 318
					position = "absolute", -- 324
					right = 18, -- 324
					bottom = 18, -- 324
					width = 300, -- 324
					height = 132 -- 324
				} -- 324
			}, -- 324
			React.createElement( -- 324
				Column, -- 326
				{style = {gap = 8, width = "100%"}}, -- 326
				React.createElement(Text, {text = logText.value, fontSize = 18, style = {width = "100%", height = 28}}), -- 326
				React.createElement( -- 326
					Row, -- 328
					{gap = 8, style = {height = 42}}, -- 328
					React.createElement( -- 328
						Button, -- 329
						{ -- 329
							variant = "ghost", -- 329
							icon = "close", -- 329
							style = {width = 92}, -- 329
							onClick = function() -- 329
								hp.value = 0.74 -- 330
								mana.value = 0.52 -- 331
								gold.value = 1460 -- 332
								gems.value = 18 -- 333
								fireCooldown.value = 0 -- 334
								shieldCooldown.value = 0 -- 335
								blinkCooldown.value = 0 -- 336
								pushLog("Reset") -- 337
							end -- 329
						}, -- 329
						"Reset" -- 329
					), -- 329
					React.createElement( -- 329
						Button, -- 341
						{ -- 341
							variant = "secondary", -- 341
							icon = "check", -- 341
							style = {width = 108}, -- 341
							onClick = function() -- 341
								gold.value = gold.value + 10 -- 342
								mana.value = math.min(1, mana.value + 0.08) -- 343
								pushLog("Tick") -- 344
							end -- 341
						}, -- 341
						"Tick" -- 341
					) -- 341
				) -- 341
			) -- 341
		) -- 341
	) -- 341
	local ____tooltipVisible_value_7 -- 351
	if tooltipVisible.value then -- 351
		____tooltipVisible_value_7 = React.createElement(Tooltip, {key = "hint-tooltip", title = "UIX", text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", style = {position = "absolute", left = 18, bottom = 18}}) -- 351
	else -- 351
		____tooltipVisible_value_7 = nil -- 357
	end -- 357
	__TS__SparseArrayPush( -- 357
		____array_8, -- 357
		____tooltipVisible_value_7, -- 357
		React.createElement( -- 357
			ToastStack, -- 358
			{ -- 358
				key = "toast-stack", -- 358
				items = { -- 358
					{id = "last", title = "Last Action", message = logText.value}, -- 361
					{ -- 362
						id = "hp", -- 362
						message = ((("HP " .. tostring(math.floor(hp.value * 100))) .. "%  Mana ") .. tostring(math.floor(mana.value * 100))) .. "%" -- 362
					} -- 362
				}, -- 362
				style = {right = 18, top = 92} -- 362
			} -- 362
		) -- 362
	) -- 362
	return ____React_createElement_9(__TS__SparseArraySpread(____array_8)) -- 259
end -- 244
local function ModalLayer() -- 370
	return React.createElement( -- 371
		Modal, -- 372
		{ -- 372
			key = "test-modal", -- 372
			open = modalOpen.value, -- 372
			title = "UIX Modal", -- 372
			message = "This modal uses a vector backdrop and a Panel body.", -- 372
			width = 300, -- 372
			height = 196, -- 372
			actions = {{id = "loot", label = "Loot", variant = "primary"}, {id = "close", label = "Close", variant = "secondary"}}, -- 372
			onClose = function() -- 372
				modalOpen.value = false -- 384
				pushLog("Backdrop Close") -- 385
			end, -- 383
			onAction = function(id) -- 383
				if id == "loot" then -- 383
					gold.value = gold.value + 120 -- 389
					gems.value = gems.value + 1 -- 390
					pushLog("Modal Loot") -- 391
				end -- 391
				modalOpen.value = false -- 393
			end -- 387
		}, -- 387
		React.createElement( -- 387
			Toggle, -- 396
			{ -- 396
				checked = tooltipVisible.value, -- 396
				label = "Show Tooltip", -- 396
				onChange = function(value) -- 396
					tooltipVisible.value = value -- 397
					pushLog(value and "Tooltip On" or "Tooltip Off") -- 398
				end -- 396
			} -- 396
		) -- 396
	) -- 396
end -- 370
local root = createRoot(host) -- 404
root:render(function() return React.createElement(App, nil) end) -- 405
local modalRoot = createRoot(modalHost) -- 406
modalRoot:render(function() return React.createElement(ModalLayer, nil) end) -- 407
host:schedule(loop(function() -- 409
	sleep(0.25) -- 410
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 411
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25) -- 412
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25) -- 413
	if autoRegen.value then -- 413
		hp.value = math.min(1, hp.value + 0.005) -- 415
		mana.value = math.min(1, mana.value + 0.018) -- 416
	end -- 416
	return false -- 418
end)) -- 409
host:onCleanup(function() -- 421
	host:unschedule() -- 422
	root:unmount() -- 423
	modalRoot:unmount() -- 424
	modalHost:removeFromParent(true) -- 425
end) -- 421
return ____exports -- 421