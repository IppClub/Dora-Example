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
local ____Stepper = require("UIX.controls.Stepper") -- 19
local Stepper = ____Stepper.Stepper -- 19
local ____Tabs = require("UIX.controls.Tabs") -- 20
local Tabs = ____Tabs.Tabs -- 20
local ____TextInput = require("UIX.controls.TextInput") -- 21
local TextInput = ____TextInput.TextInput -- 21
local ____Text = require("UIX.foundation.Text") -- 22
local Text = ____Text.Text -- 22
local ____Modal = require("UIX.overlay.Modal") -- 23
local Modal = ____Modal.Modal -- 23
local ____ToastStack = require("UIX.overlay.ToastStack") -- 24
local ToastStack = ____ToastStack.ToastStack -- 24
local ____Tooltip = require("UIX.overlay.Tooltip") -- 25
local Tooltip = ____Tooltip.Tooltip -- 25
local ____Toggle = require("UIX.controls.Toggle") -- 26
local Toggle = ____Toggle.Toggle -- 26
local host = DNode() -- 28
Director.ui:addChild(host) -- 29
local modalHost = DNode() -- 30
Director.ui:addChild(modalHost, 10000) -- 31
Director.clearColor = Color(4279113510) -- 32
local hp = signal(0.74) -- 34
local mana = signal(0.52) -- 35
local gold = signal(1460) -- 36
local gems = signal(18) -- 37
local autoRegen = signal(true) -- 38
local compact = signal(false) -- 39
local lootHints = signal(true) -- 40
local expertMode = signal(false) -- 41
local targetMode = signal("assist") -- 42
local partySize = signal(3) -- 43
local difficulty = signal(0.45) -- 44
local activeTab = signal("combat") -- 45
local selectedItem = signal("potion") -- 46
local logText = signal("Ready") -- 47
local clicks = signal(0) -- 48
local modalOpen = signal(false) -- 49
local tooltipVisible = signal(true) -- 50
local difficultyPreset = signal("normal") -- 51
local difficultySelectOpen = signal(false) -- 52
local playerName = signal("Dora") -- 53
local fireCooldown = signal(0) -- 54
local shieldCooldown = signal(0) -- 55
local blinkCooldown = signal(0) -- 56
local settingsOpen = signal(true) -- 57
local function pushLog(text) -- 59
	clicks.value = clicks.value + 1 -- 60
	logText.value = (text .. " #") .. tostring(clicks.value) -- 61
end -- 59
local function castFire() -- 64
	fireCooldown.value = 5 -- 65
	mana.value = math.max(0, mana.value - 0.14) -- 66
	pushLog("Fire") -- 67
end -- 64
local function castShield() -- 70
	shieldCooldown.value = 8 -- 71
	hp.value = math.min(1, hp.value + 0.12) -- 72
	pushLog("Shield") -- 73
end -- 70
local function castBlink() -- 76
	blinkCooldown.value = 3 -- 77
	gems.value = math.max(0, gems.value - 1) -- 78
	pushLog("Blink") -- 79
end -- 76
local function CombatPage() -- 82
	return React.createElement( -- 83
		Column, -- 84
		{key = "combat-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 126}}, -- 84
		React.createElement( -- 84
			Row, -- 85
			{gap = 10, style = {height = 72, alignItems = "center"}}, -- 85
			React.createElement(CooldownButton, {icon = "warning", cooldown = fireCooldown.value, maxCooldown = 5, onCast = castFire}), -- 85
			React.createElement(CooldownButton, {icon = "heart", cooldown = shieldCooldown.value, maxCooldown = 8, onCast = castShield}), -- 85
			React.createElement(CooldownButton, { -- 85
				icon = "mana", -- 85
				cooldown = blinkCooldown.value, -- 85
				maxCooldown = 3, -- 85
				disabled = gems.value <= 0, -- 85
				onCast = castBlink -- 85
			}) -- 85
		), -- 85
		React.createElement( -- 85
			Row, -- 90
			{gap = 10, style = {height = 42}}, -- 90
			React.createElement( -- 90
				Button, -- 91
				{ -- 91
					variant = "danger", -- 91
					icon = "warning", -- 91
					style = {width = 110}, -- 91
					onClick = function() -- 91
						hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12) -- 92
						pushLog("Damage") -- 93
					end -- 91
				}, -- 91
				"Damage" -- 91
			), -- 91
			React.createElement( -- 91
				Button, -- 97
				{ -- 97
					variant = "secondary", -- 97
					icon = "heart", -- 97
					style = {width = 96}, -- 97
					onClick = function() -- 97
						hp.value = math.min(1, hp.value + 0.18) -- 98
						pushLog("Heal") -- 99
					end -- 97
				}, -- 97
				"Heal" -- 97
			) -- 97
		) -- 97
	) -- 97
end -- 82
local function InventoryPage() -- 108
	local items = { -- 109
		{id = "potion", icon = "heart", quality = "common", count = 3}, -- 110
		{id = "crystal", icon = "mana", quality = "rare", count = gems.value}, -- 111
		{id = "bomb", icon = "warning", quality = "epic", count = 2}, -- 112
		{ -- 113
			id = "coin", -- 113
			icon = "coin", -- 113
			quality = "legendary", -- 113
			count = math.floor(gold.value / 100) -- 113
		}, -- 113
		{id = "lock", icon = "lock", quality = "common", disabled = true}, -- 114
		{id = "shield", icon = "check", quality = "rare", count = 1}, -- 115
		{id = "blink", icon = "mana", quality = "epic", count = gems.value}, -- 116
		{id = "kit", icon = "heart", quality = "common", count = 5}, -- 117
		{id = "map", icon = "gear", quality = "legendary", count = 1}, -- 118
		{id = "rune", icon = "warning", quality = "rare", count = 4}, -- 119
		{id = "empty", icon = "close", quality = "common", disabled = true} -- 120
	} -- 120
	return React.createElement( -- 122
		Column, -- 123
		{key = "inventory-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 264}}, -- 123
		React.createElement( -- 123
			InventoryGrid, -- 124
			{ -- 124
				key = "bag-grid", -- 124
				items = items, -- 124
				columns = 4, -- 124
				rows = 3, -- 124
				slotSize = 48, -- 124
				gap = 8, -- 124
				selectedId = selectedItem.value, -- 124
				slotSwallowTouches = false, -- 124
				onSelect = function(id) -- 124
					selectedItem.value = id -- 134
					pushLog("Item " .. id) -- 135
				end -- 133
			} -- 133
		), -- 133
		React.createElement( -- 133
			Row, -- 138
			{key = "bag-resources", gap = 12, style = {height = 42, alignItems = "center"}}, -- 138
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 138
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value, variant = "default"}) -- 138
		), -- 138
		React.createElement( -- 138
			Row, -- 142
			{key = "bag-actions", gap = 10, style = {height = 42}}, -- 142
			React.createElement( -- 142
				Button, -- 143
				{ -- 143
					variant = "secondary", -- 143
					icon = "coin", -- 143
					swallowTouches = false, -- 143
					style = {width = 120}, -- 143
					onClick = function() -- 143
						gold.value = gold.value + 75 -- 144
						pushLog("Loot") -- 145
					end -- 143
				}, -- 143
				"Loot" -- 143
			), -- 143
			React.createElement( -- 143
				Button, -- 149
				{ -- 149
					variant = "ghost", -- 149
					icon = "check", -- 149
					disabled = gold.value < 200, -- 149
					swallowTouches = false, -- 149
					style = {width = 120}, -- 149
					onClick = function() -- 149
						gold.value = gold.value - 200 -- 150
						gems.value = gems.value + 1 -- 151
						pushLog("Trade") -- 152
					end -- 149
				}, -- 149
				"Trade" -- 149
			) -- 149
		) -- 149
	) -- 149
end -- 108
local function SettingsPage() -- 161
	local pageHeight = difficultySelectOpen.value and 650 or 482 -- 162
	return React.createElement( -- 163
		Column, -- 164
		{key = "settings-page", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%", height = pageHeight}}, -- 164
		React.createElement( -- 164
			Toggle, -- 165
			{ -- 165
				checked = autoRegen.value, -- 165
				label = "Auto Regen", -- 165
				onChange = function(value) -- 165
					autoRegen.value = value -- 166
					pushLog(value and "Regen On" or "Regen Off") -- 167
				end -- 165
			} -- 165
		), -- 165
		React.createElement( -- 165
			Toggle, -- 169
			{ -- 169
				checked = compact.value, -- 169
				label = "Compact HUD", -- 169
				onChange = function(value) -- 169
					compact.value = value -- 170
					pushLog(value and "Compact" or "Expanded") -- 171
				end -- 169
			} -- 169
		), -- 169
		React.createElement( -- 169
			Checkbox, -- 173
			{ -- 173
				checked = lootHints.value, -- 173
				label = "Loot Hints", -- 173
				onChange = function(value) -- 173
					lootHints.value = value -- 174
					pushLog(value and "Hints On" or "Hints Off") -- 175
				end -- 173
			} -- 173
		), -- 173
		React.createElement( -- 173
			Checkbox, -- 177
			{ -- 177
				checked = expertMode.value, -- 177
				indeterminate = not expertMode.value and difficultyPreset.value == "custom", -- 177
				label = "Expert Rules", -- 177
				onChange = function(value) -- 177
					expertMode.value = value -- 178
					pushLog(value and "Expert On" or "Expert Off") -- 179
				end -- 177
			} -- 177
		), -- 177
		React.createElement( -- 177
			RadioGroup, -- 181
			{ -- 181
				key = "target-mode-radio", -- 181
				value = targetMode.value, -- 181
				direction = "row", -- 181
				itemWidth = 108, -- 181
				items = {{id = "assist", label = "Assist", icon = "heart"}, {id = "manual", label = "Manual", icon = "warning"}}, -- 181
				onValueChange = function(value) -- 181
					targetMode.value = value -- 191
					pushLog("Mode " .. value) -- 192
				end -- 190
			} -- 190
		), -- 190
		React.createElement( -- 190
			Stepper, -- 195
			{ -- 195
				key = "party-size-stepper", -- 195
				value = partySize.value, -- 195
				min = 1, -- 195
				max = 6, -- 195
				step = 1, -- 195
				prefixIcon = "heart", -- 195
				suffixLabel = "party", -- 195
				valueWidth = 112, -- 195
				onValueChange = function(value) -- 195
					partySize.value = value -- 205
					pushLog("Party " .. tostring(value)) -- 206
				end -- 204
			} -- 204
		), -- 204
		React.createElement( -- 204
			Select, -- 209
			{ -- 209
				key = "difficulty-select", -- 209
				value = difficultyPreset.value, -- 209
				items = {{id = "easy", label = "Easy", icon = "heart"}, {id = "normal", label = "Normal", icon = "check"}, {id = "hard", label = "Hard", icon = "warning"}, {id = "custom", label = "Custom", icon = "gear"}}, -- 209
				open = difficultySelectOpen.value, -- 209
				onOpenChange = function(value) -- 209
					difficultySelectOpen.value = value -- 220
				end, -- 219
				onValueChange = function(value) -- 219
					difficultyPreset.value = value -- 223
					if value == "easy" then -- 223
						difficulty.value = 0.2 -- 224
					elseif value == "hard" then -- 224
						difficulty.value = 0.8 -- 225
					else -- 225
						difficulty.value = 0.45 -- 226
					end -- 226
					pushLog("Difficulty " .. value) -- 227
				end, -- 222
				style = {width = 180} -- 222
			} -- 222
		), -- 222
		React.createElement( -- 222
			Slider, -- 231
			{ -- 231
				value = difficulty.value, -- 231
				min = 0, -- 231
				max = 1, -- 231
				step = 0.05, -- 231
				showValue = true, -- 231
				onValueChange = function(value) -- 231
					difficulty.value = value -- 232
					difficultyPreset.value = "custom" -- 233
					pushLog("Difficulty") -- 234
				end -- 231
			} -- 231
		), -- 231
		React.createElement( -- 231
			TextInput, -- 236
			{ -- 236
				key = "player-name-input", -- 236
				value = playerName.value, -- 236
				placeholder = "Player name", -- 236
				prefixIcon = "gear", -- 236
				maxLength = 18, -- 236
				style = {width = 220}, -- 236
				onValueChange = function(value) -- 236
					playerName.value = value -- 244
				end, -- 243
				onSubmit = function(value) return pushLog(value == "" and "Name Empty" or "Name " .. value) end -- 243
			} -- 243
		) -- 243
	) -- 243
end -- 161
local function ActivePage() -- 252
	repeat -- 252
		local ____switch29 = activeTab.value -- 252
		local ____cond29 = ____switch29 == "inventory" -- 252
		if ____cond29 then -- 252
			return React.createElement(InventoryPage, nil) -- 254
		end -- 254
		____cond29 = ____cond29 or ____switch29 == "settings" -- 254
		if ____cond29 then -- 254
			return React.createElement(SettingsPage, nil) -- 255
		end -- 255
		do -- 255
			return React.createElement(CombatPage, nil) -- 256
		end -- 256
	until true -- 256
end -- 252
local function App() -- 260
	local panelWidth = compact.value and 316 or 420 -- 261
	local panelTop = 92 -- 262
	local minPanelHeight = 280 -- 263
	local tooltipReserveHeight = 88 -- 264
	local panelToTooltipGap = 16 -- 265
	local panelHeight = useSignal(math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap)) -- 266
	local pageScrollHeight = math.max(154, panelHeight.value - 126) -- 267
	local inventoryContentHeight = 300 -- 268
	local settingsContentHeight = difficultySelectOpen.value and 650 or 482 -- 269
	local activeContentHeight = activeTab.value == "inventory" and inventoryContentHeight or settingsContentHeight -- 270
	local shouldScrollPage = activeTab.value == "inventory" or activeTab.value == "settings" -- 271
	local onLayout = useCallback( -- 272
		function(w, h) -- 272
			panelHeight.value = math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap) -- 273
		end, -- 272
		{ -- 274
			minPanelHeight, -- 274
			panelHeight.value, -- 274
			panelToTooltipGap, -- 274
			panelTop, -- 274
			tooltipReserveHeight -- 274
		} -- 274
	) -- 274
	local ____React_createElement_9 = React.createElement -- 274
	local ____array_8 = __TS__SparseArrayNew( -- 274
		"align-node", -- 274
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}, onLayout = onLayout}, -- 274
		React.createElement( -- 274
			Row, -- 277
			{key = "top-hud", gap = 14, style = {width = "100%", height = 58, alignItems = "center"}}, -- 277
			React.createElement( -- 277
				Column, -- 278
				{style = {width = compact.value and 220 or 320, gap = 7}}, -- 278
				React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = "100%", height = 22}}), -- 278
				React.createElement(ProgressBar, { -- 278
					value = mana.value, -- 278
					max = 1, -- 278
					variant = "mana", -- 278
					showValue = true, -- 278
					style = {width = "100%", height = 14} -- 278
				}) -- 278
			), -- 278
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 278
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value}), -- 278
			React.createElement( -- 278
				Button, -- 284
				{ -- 284
					variant = settingsOpen.value and "primary" or "secondary", -- 284
					icon = "gear", -- 284
					style = {width = 128}, -- 284
					onClick = function() -- 284
						settingsOpen.value = not settingsOpen.value -- 285
						pushLog(settingsOpen.value and "Panel Open" or "Panel Close") -- 286
					end -- 284
				}, -- 284
				"Panel" -- 284
			), -- 284
			React.createElement( -- 284
				Button, -- 290
				{ -- 290
					variant = "secondary", -- 290
					icon = "warning", -- 290
					style = {width = 128}, -- 290
					onClick = function() -- 290
						modalOpen.value = true -- 291
						pushLog("Modal") -- 292
					end -- 290
				}, -- 290
				"Modal" -- 290
			) -- 290
		) -- 290
	) -- 290
	local ____settingsOpen_value_6 -- 297
	if settingsOpen.value then -- 297
		local ____React_createElement_5 = React.createElement -- 297
		local ____Panel_3 = Panel -- 298
		local ____temp_4 = { -- 298
			key = "user-test-panel", -- 298
			title = "UIX Test", -- 298
			variant = "glass", -- 298
			padding = 14, -- 298
			headerHeight = 34, -- 298
			style = { -- 298
				position = "absolute", -- 304
				left = 18, -- 304
				top = panelTop, -- 304
				width = panelWidth, -- 304
				height = panelHeight.value -- 304
			} -- 304
		} -- 304
		local ____React_createElement_2 = React.createElement -- 304
		local ____array_1 = __TS__SparseArrayNew( -- 304
			Column, -- 306
			{key = "panel-body", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%"}}, -- 306
			React.createElement( -- 306
				Tabs, -- 307
				{ -- 307
					key = "main-tabs", -- 307
					value = activeTab.value, -- 307
					items = {{id = "combat", label = "Combat"}, {id = "inventory", label = "Bag"}, {id = "settings", label = "Tune"}}, -- 307
					onValueChange = function(value) -- 307
						activeTab.value = value -- 316
						pushLog(value) -- 317
					end -- 315
				} -- 315
			) -- 315
		) -- 315
		local ____shouldScrollPage_0 -- 320
		if shouldScrollPage then -- 320
			____shouldScrollPage_0 = React.createElement( -- 320
				ScrollView, -- 321
				{ -- 321
					key = "page-scroll-" .. activeTab.value, -- 321
					width = panelWidth - 28, -- 321
					height = pageScrollHeight, -- 321
					contentHeight = math.max(pageScrollHeight, activeContentHeight), -- 321
					wheelSpeed = 18 -- 321
				}, -- 321
				React.createElement(ActivePage, nil) -- 321
			) -- 321
		else -- 321
			____shouldScrollPage_0 = React.createElement(ActivePage, nil) -- 321
		end -- 321
		__TS__SparseArrayPush(____array_1, ____shouldScrollPage_0) -- 321
		____settingsOpen_value_6 = ____React_createElement_5( -- 321
			____Panel_3, -- 298
			____temp_4, -- 298
			____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 298
		) -- 298
	else -- 298
		____settingsOpen_value_6 = nil -- 333
	end -- 333
	__TS__SparseArrayPush( -- 333
		____array_8, -- 333
		____settingsOpen_value_6, -- 333
		React.createElement( -- 333
			Panel, -- 334
			{ -- 334
				key = "status-panel", -- 334
				title = "Status", -- 334
				variant = "solid", -- 334
				padding = 12, -- 334
				headerHeight = 30, -- 334
				style = { -- 334
					position = "absolute", -- 340
					right = 18, -- 340
					bottom = 18, -- 340
					width = 300, -- 340
					height = 132 -- 340
				} -- 340
			}, -- 340
			React.createElement( -- 340
				Column, -- 342
				{style = {gap = 8, width = "100%"}}, -- 342
				React.createElement(Text, {text = logText.value, fontSize = 18, style = {width = "100%", height = 28}}), -- 342
				React.createElement( -- 342
					Row, -- 344
					{gap = 8, style = {height = 42}}, -- 344
					React.createElement( -- 344
						Button, -- 345
						{ -- 345
							variant = "ghost", -- 345
							icon = "close", -- 345
							style = {width = 92}, -- 345
							onClick = function() -- 345
								hp.value = 0.74 -- 346
								mana.value = 0.52 -- 347
								gold.value = 1460 -- 348
								gems.value = 18 -- 349
								fireCooldown.value = 0 -- 350
								shieldCooldown.value = 0 -- 351
								blinkCooldown.value = 0 -- 352
								pushLog("Reset") -- 353
							end -- 345
						}, -- 345
						"Reset" -- 345
					), -- 345
					React.createElement( -- 345
						Button, -- 357
						{ -- 357
							variant = "secondary", -- 357
							icon = "check", -- 357
							style = {width = 108}, -- 357
							onClick = function() -- 357
								gold.value = gold.value + 10 -- 358
								mana.value = math.min(1, mana.value + 0.08) -- 359
								pushLog("Tick") -- 360
							end -- 357
						}, -- 357
						"Tick" -- 357
					) -- 357
				) -- 357
			) -- 357
		) -- 357
	) -- 357
	local ____tooltipVisible_value_7 -- 367
	if tooltipVisible.value then -- 367
		____tooltipVisible_value_7 = React.createElement(Tooltip, {key = "hint-tooltip", title = "UIX", text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", style = {position = "absolute", left = 18, bottom = 18}}) -- 367
	else -- 367
		____tooltipVisible_value_7 = nil -- 373
	end -- 373
	__TS__SparseArrayPush( -- 373
		____array_8, -- 373
		____tooltipVisible_value_7, -- 373
		React.createElement( -- 373
			ToastStack, -- 374
			{ -- 374
				key = "toast-stack", -- 374
				items = { -- 374
					{id = "last", title = "Last Action", message = logText.value}, -- 377
					{ -- 378
						id = "hp", -- 378
						message = ((("HP " .. tostring(math.floor(hp.value * 100))) .. "%  Mana ") .. tostring(math.floor(mana.value * 100))) .. "%" -- 378
					} -- 378
				}, -- 378
				style = {right = 18, top = 92} -- 378
			} -- 378
		) -- 378
	) -- 378
	return ____React_createElement_9(__TS__SparseArraySpread(____array_8)) -- 275
end -- 260
local function ModalLayer() -- 386
	return React.createElement( -- 387
		Modal, -- 388
		{ -- 388
			key = "test-modal", -- 388
			open = modalOpen.value, -- 388
			title = "UIX Modal", -- 388
			message = "This modal uses a vector backdrop and a Panel body.", -- 388
			width = 300, -- 388
			height = 196, -- 388
			actions = {{id = "loot", label = "Loot", variant = "primary"}, {id = "close", label = "Close", variant = "secondary"}}, -- 388
			onClose = function() -- 388
				modalOpen.value = false -- 400
				pushLog("Backdrop Close") -- 401
			end, -- 399
			onAction = function(id) -- 399
				if id == "loot" then -- 399
					gold.value = gold.value + 120 -- 405
					gems.value = gems.value + 1 -- 406
					pushLog("Modal Loot") -- 407
				end -- 407
				modalOpen.value = false -- 409
			end -- 403
		}, -- 403
		React.createElement( -- 403
			Toggle, -- 412
			{ -- 412
				checked = tooltipVisible.value, -- 412
				label = "Show Tooltip", -- 412
				onChange = function(value) -- 412
					tooltipVisible.value = value -- 413
					pushLog(value and "Tooltip On" or "Tooltip Off") -- 414
				end -- 412
			} -- 412
		) -- 412
	) -- 412
end -- 386
local root = createRoot(host) -- 420
root:render(function() return React.createElement(App, nil) end) -- 421
local modalRoot = createRoot(modalHost) -- 422
modalRoot:render(function() return React.createElement(ModalLayer, nil) end) -- 423
host:schedule(loop(function() -- 425
	sleep(0.25) -- 426
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 427
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25) -- 428
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25) -- 429
	if autoRegen.value then -- 429
		hp.value = math.min(1, hp.value + 0.005) -- 431
		mana.value = math.min(1, mana.value + 0.018) -- 432
	end -- 432
	return false -- 434
end)) -- 425
host:onCleanup(function() -- 437
	host:unschedule() -- 438
	root:unmount() -- 439
	modalRoot:unmount() -- 440
	modalHost:removeFromParent(true) -- 441
end) -- 437
return ____exports -- 437