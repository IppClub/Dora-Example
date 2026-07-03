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
local ____Badge = require("UIX.controls.Badge") -- 4
local Badge = ____Badge.Badge -- 4
local ____Button = require("UIX.controls.Button") -- 5
local Button = ____Button.Button -- 5
local ____Checkbox = require("UIX.controls.Checkbox") -- 6
local Checkbox = ____Checkbox.Checkbox -- 6
local ____Column = require("UIX.layout.Column") -- 7
local Column = ____Column.Column -- 7
local ____CooldownButton = require("UIX.game.CooldownButton") -- 8
local CooldownButton = ____CooldownButton.CooldownButton -- 8
local ____HealthBar = require("UIX.game.HealthBar") -- 9
local HealthBar = ____HealthBar.HealthBar -- 9
local ____InventoryGrid = require("UIX.game.InventoryGrid") -- 10
local InventoryGrid = ____InventoryGrid.InventoryGrid -- 10
local ____Panel = require("UIX.layout.Panel") -- 11
local Panel = ____Panel.Panel -- 11
local ____ProgressBar = require("UIX.controls.ProgressBar") -- 12
local ProgressBar = ____ProgressBar.ProgressBar -- 12
local ____RadioGroup = require("UIX.controls.RadioGroup") -- 13
local RadioGroup = ____RadioGroup.RadioGroup -- 13
local ____ResourceCounter = require("UIX.game.ResourceCounter") -- 14
local ResourceCounter = ____ResourceCounter.ResourceCounter -- 14
local ____Row = require("UIX.layout.Row") -- 15
local Row = ____Row.Row -- 15
local ____ScrollView = require("UIX.layout.ScrollView") -- 16
local ScrollView = ____ScrollView.ScrollView -- 16
local ____Select = require("UIX.controls.Select") -- 18
local Select = ____Select.Select -- 18
local ____Slider = require("UIX.controls.Slider") -- 19
local Slider = ____Slider.Slider -- 19
local ____Stepper = require("UIX.controls.Stepper") -- 20
local Stepper = ____Stepper.Stepper -- 20
local ____Tabs = require("UIX.controls.Tabs") -- 21
local Tabs = ____Tabs.Tabs -- 21
local ____TextInput = require("UIX.controls.TextInput") -- 22
local TextInput = ____TextInput.TextInput -- 22
local ____Text = require("UIX.foundation.Text") -- 23
local Text = ____Text.Text -- 23
local ____Modal = require("UIX.overlay.Modal") -- 24
local Modal = ____Modal.Modal -- 24
local ____ToastStack = require("UIX.overlay.ToastStack") -- 25
local ToastStack = ____ToastStack.ToastStack -- 25
local ____Tooltip = require("UIX.overlay.Tooltip") -- 26
local Tooltip = ____Tooltip.Tooltip -- 26
local ____Toggle = require("UIX.controls.Toggle") -- 27
local Toggle = ____Toggle.Toggle -- 27
local host = DNode() -- 29
Director.ui:addChild(host) -- 30
local modalHost = DNode() -- 31
Director.ui:addChild(modalHost, 10000) -- 32
Director.clearColor = Color(4279113510) -- 33
local hp = signal(0.74) -- 35
local mana = signal(0.52) -- 36
local gold = signal(1460) -- 37
local gems = signal(18) -- 38
local autoRegen = signal(true) -- 39
local compact = signal(false) -- 40
local lootHints = signal(true) -- 41
local expertMode = signal(false) -- 42
local targetMode = signal("assist") -- 43
local partySize = signal(3) -- 44
local difficulty = signal(0.45) -- 45
local activeTab = signal("combat") -- 46
local selectedItem = signal("potion") -- 47
local logText = signal("Ready") -- 48
local clicks = signal(0) -- 49
local modalOpen = signal(false) -- 50
local tooltipVisible = signal(true) -- 51
local difficultyPreset = signal("normal") -- 52
local difficultySelectOpen = signal(false) -- 53
local playerName = signal("Dora") -- 54
local fireCooldown = signal(0) -- 55
local shieldCooldown = signal(0) -- 56
local blinkCooldown = signal(0) -- 57
local settingsOpen = signal(true) -- 58
local function pushLog(text) -- 60
	clicks.value = clicks.value + 1 -- 61
	logText.value = (text .. " #") .. tostring(clicks.value) -- 62
end -- 60
local function castFire() -- 65
	fireCooldown.value = 5 -- 66
	mana.value = math.max(0, mana.value - 0.14) -- 67
	pushLog("Fire") -- 68
end -- 65
local function castShield() -- 71
	shieldCooldown.value = 8 -- 72
	hp.value = math.min(1, hp.value + 0.12) -- 73
	pushLog("Shield") -- 74
end -- 71
local function castBlink() -- 77
	blinkCooldown.value = 3 -- 78
	gems.value = math.max(0, gems.value - 1) -- 79
	pushLog("Blink") -- 80
end -- 77
local function CombatPage() -- 83
	return React.createElement( -- 84
		Column, -- 85
		{key = "combat-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 126}}, -- 85
		React.createElement( -- 85
			Row, -- 86
			{gap = 10, style = {height = 72, alignItems = "center"}}, -- 86
			React.createElement(CooldownButton, {icon = "warning", cooldown = fireCooldown.value, maxCooldown = 5, onCast = castFire}), -- 86
			React.createElement(CooldownButton, {icon = "heart", cooldown = shieldCooldown.value, maxCooldown = 8, onCast = castShield}), -- 86
			React.createElement(CooldownButton, { -- 86
				icon = "mana", -- 86
				cooldown = blinkCooldown.value, -- 86
				maxCooldown = 3, -- 86
				disabled = gems.value <= 0, -- 86
				onCast = castBlink -- 86
			}) -- 86
		), -- 86
		React.createElement( -- 86
			Row, -- 91
			{gap = 10, style = {height = 42}}, -- 91
			React.createElement( -- 91
				Button, -- 92
				{ -- 92
					variant = "danger", -- 92
					icon = "warning", -- 92
					style = {width = 110}, -- 92
					onClick = function() -- 92
						hp.value = math.max(0, hp.value - 0.12 - difficulty.value * 0.12) -- 93
						pushLog("Damage") -- 94
					end -- 92
				}, -- 92
				"Damage" -- 92
			), -- 92
			React.createElement( -- 92
				Button, -- 98
				{ -- 98
					variant = "secondary", -- 98
					icon = "heart", -- 98
					style = {width = 96}, -- 98
					onClick = function() -- 98
						hp.value = math.min(1, hp.value + 0.18) -- 99
						pushLog("Heal") -- 100
					end -- 98
				}, -- 98
				"Heal" -- 98
			) -- 98
		) -- 98
	) -- 98
end -- 83
local function InventoryPage() -- 109
	local items = { -- 110
		{id = "potion", icon = "heart", quality = "common", count = 3}, -- 111
		{id = "crystal", icon = "mana", quality = "rare", count = gems.value}, -- 112
		{id = "bomb", icon = "warning", quality = "epic", count = 2}, -- 113
		{ -- 114
			id = "coin", -- 114
			icon = "coin", -- 114
			quality = "legendary", -- 114
			count = math.floor(gold.value / 100) -- 114
		}, -- 114
		{id = "lock", icon = "lock", quality = "common", disabled = true}, -- 115
		{id = "shield", icon = "check", quality = "rare", count = 1}, -- 116
		{id = "blink", icon = "mana", quality = "epic", count = gems.value}, -- 117
		{id = "kit", icon = "heart", quality = "common", count = 5}, -- 118
		{id = "map", icon = "gear", quality = "legendary", count = 1}, -- 119
		{id = "rune", icon = "warning", quality = "rare", count = 4}, -- 120
		{id = "empty", icon = "close", quality = "common", disabled = true} -- 121
	} -- 121
	return React.createElement( -- 123
		Column, -- 124
		{key = "inventory-page", align = "flex-start", justify = "flex-start", style = {gap = 10, width = "100%", height = 264}}, -- 124
		React.createElement( -- 124
			InventoryGrid, -- 125
			{ -- 125
				key = "bag-grid", -- 125
				items = items, -- 125
				columns = 4, -- 125
				rows = 3, -- 125
				slotSize = 48, -- 125
				gap = 8, -- 125
				selectedId = selectedItem.value, -- 125
				slotSwallowTouches = false, -- 125
				onSelect = function(id) -- 125
					selectedItem.value = id -- 135
					pushLog("Item " .. id) -- 136
				end -- 134
			} -- 134
		), -- 134
		React.createElement( -- 134
			Row, -- 139
			{key = "bag-resources", gap = 12, style = {height = 42, alignItems = "center"}}, -- 139
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 139
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value, variant = "default"}) -- 139
		), -- 139
		React.createElement( -- 139
			Row, -- 143
			{key = "bag-actions", gap = 10, style = {height = 42}}, -- 143
			React.createElement( -- 143
				Button, -- 144
				{ -- 144
					variant = "secondary", -- 144
					icon = "coin", -- 144
					swallowTouches = false, -- 144
					style = {width = 120}, -- 144
					onClick = function() -- 144
						gold.value = gold.value + 75 -- 145
						pushLog("Loot") -- 146
					end -- 144
				}, -- 144
				"Loot" -- 144
			), -- 144
			React.createElement( -- 144
				Button, -- 150
				{ -- 150
					variant = "ghost", -- 150
					icon = "check", -- 150
					disabled = gold.value < 200, -- 150
					swallowTouches = false, -- 150
					style = {width = 120}, -- 150
					onClick = function() -- 150
						gold.value = gold.value - 200 -- 151
						gems.value = gems.value + 1 -- 152
						pushLog("Trade") -- 153
					end -- 150
				}, -- 150
				"Trade" -- 150
			) -- 150
		) -- 150
	) -- 150
end -- 109
local function SettingsPage() -- 162
	local pageHeight = difficultySelectOpen.value and 686 or 518 -- 163
	return React.createElement( -- 164
		Column, -- 165
		{key = "settings-page", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%", height = pageHeight}}, -- 165
		React.createElement( -- 165
			Toggle, -- 166
			{ -- 166
				checked = autoRegen.value, -- 166
				label = "Auto Regen", -- 166
				onChange = function(value) -- 166
					autoRegen.value = value -- 167
					pushLog(value and "Regen On" or "Regen Off") -- 168
				end -- 166
			} -- 166
		), -- 166
		React.createElement( -- 166
			Toggle, -- 170
			{ -- 170
				checked = compact.value, -- 170
				label = "Compact HUD", -- 170
				onChange = function(value) -- 170
					compact.value = value -- 171
					pushLog(value and "Compact" or "Expanded") -- 172
				end -- 170
			} -- 170
		), -- 170
		React.createElement( -- 170
			Checkbox, -- 174
			{ -- 174
				checked = lootHints.value, -- 174
				label = "Loot Hints", -- 174
				onChange = function(value) -- 174
					lootHints.value = value -- 175
					pushLog(value and "Hints On" or "Hints Off") -- 176
				end -- 174
			} -- 174
		), -- 174
		React.createElement( -- 174
			Checkbox, -- 178
			{ -- 178
				checked = expertMode.value, -- 178
				indeterminate = not expertMode.value and difficultyPreset.value == "custom", -- 178
				label = "Expert Rules", -- 178
				onChange = function(value) -- 178
					expertMode.value = value -- 179
					pushLog(value and "Expert On" or "Expert Off") -- 180
				end -- 178
			} -- 178
		), -- 178
		React.createElement( -- 178
			RadioGroup, -- 182
			{ -- 182
				key = "target-mode-radio", -- 182
				value = targetMode.value, -- 182
				direction = "row", -- 182
				itemWidth = 108, -- 182
				items = {{id = "assist", label = "Assist", icon = "heart"}, {id = "manual", label = "Manual", icon = "warning"}}, -- 182
				onValueChange = function(value) -- 182
					targetMode.value = value -- 192
					pushLog("Mode " .. value) -- 193
				end -- 191
			} -- 191
		), -- 191
		React.createElement( -- 191
			Stepper, -- 196
			{ -- 196
				key = "party-size-stepper", -- 196
				value = partySize.value, -- 196
				min = 1, -- 196
				max = 6, -- 196
				step = 1, -- 196
				prefixIcon = "heart", -- 196
				suffixLabel = "party", -- 196
				valueWidth = 112, -- 196
				onValueChange = function(value) -- 196
					partySize.value = value -- 206
					pushLog("Party " .. tostring(value)) -- 207
				end -- 205
			} -- 205
		), -- 205
		React.createElement( -- 205
			Row, -- 210
			{key = "settings-badges", gap = 6, style = {height = 28, alignItems = "center"}}, -- 210
			React.createElement(Badge, {tone = "success", icon = "check"}, "Ready"), -- 210
			React.createElement(Badge, {tone = "warm", dot = true}, "Rare"), -- 210
			React.createElement(Badge, {tone = "mana", dot = true}, "Mana") -- 210
		), -- 210
		React.createElement( -- 210
			Select, -- 215
			{ -- 215
				key = "difficulty-select", -- 215
				value = difficultyPreset.value, -- 215
				items = {{id = "easy", label = "Easy", icon = "heart"}, {id = "normal", label = "Normal", icon = "check"}, {id = "hard", label = "Hard", icon = "warning"}, {id = "custom", label = "Custom", icon = "gear"}}, -- 215
				open = difficultySelectOpen.value, -- 215
				onOpenChange = function(value) -- 215
					difficultySelectOpen.value = value -- 226
				end, -- 225
				onValueChange = function(value) -- 225
					difficultyPreset.value = value -- 229
					if value == "easy" then -- 229
						difficulty.value = 0.2 -- 230
					elseif value == "hard" then -- 230
						difficulty.value = 0.8 -- 231
					else -- 231
						difficulty.value = 0.45 -- 232
					end -- 232
					pushLog("Difficulty " .. value) -- 233
				end, -- 228
				style = {width = 180} -- 228
			} -- 228
		), -- 228
		React.createElement( -- 228
			Slider, -- 237
			{ -- 237
				value = difficulty.value, -- 237
				min = 0, -- 237
				max = 1, -- 237
				step = 0.05, -- 237
				showValue = true, -- 237
				onValueChange = function(value) -- 237
					difficulty.value = value -- 238
					difficultyPreset.value = "custom" -- 239
					pushLog("Difficulty") -- 240
				end -- 237
			} -- 237
		), -- 237
		React.createElement( -- 237
			TextInput, -- 242
			{ -- 242
				key = "player-name-input", -- 242
				value = playerName.value, -- 242
				placeholder = "Player name", -- 242
				prefixIcon = "gear", -- 242
				maxLength = 18, -- 242
				style = {width = 220}, -- 242
				onValueChange = function(value) -- 242
					playerName.value = value -- 250
				end, -- 249
				onSubmit = function(value) return pushLog(value == "" and "Name Empty" or "Name " .. value) end -- 249
			} -- 249
		) -- 249
	) -- 249
end -- 162
local function ActivePage() -- 258
	repeat -- 258
		local ____switch29 = activeTab.value -- 258
		local ____cond29 = ____switch29 == "inventory" -- 258
		if ____cond29 then -- 258
			return React.createElement(InventoryPage, nil) -- 260
		end -- 260
		____cond29 = ____cond29 or ____switch29 == "settings" -- 260
		if ____cond29 then -- 260
			return React.createElement(SettingsPage, nil) -- 261
		end -- 261
		do -- 261
			return React.createElement(CombatPage, nil) -- 262
		end -- 262
	until true -- 262
end -- 258
local function App() -- 266
	local panelWidth = compact.value and 316 or 420 -- 267
	local panelTop = 92 -- 268
	local minPanelHeight = 280 -- 269
	local tooltipReserveHeight = 88 -- 270
	local panelToTooltipGap = 16 -- 271
	local panelHeight = useSignal(math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap)) -- 272
	local pageScrollHeight = math.max(154, panelHeight.value - 126) -- 273
	local inventoryContentHeight = 300 -- 274
	local settingsContentHeight = difficultySelectOpen.value and 686 or 518 -- 275
	local activeContentHeight = activeTab.value == "inventory" and inventoryContentHeight or settingsContentHeight -- 276
	local shouldScrollPage = activeTab.value == "inventory" or activeTab.value == "settings" -- 277
	local onLayout = useCallback( -- 278
		function(w, h) -- 278
			panelHeight.value = math.max(minPanelHeight, DoraApp.visualSize.height - panelTop - tooltipReserveHeight - 50 - panelToTooltipGap) -- 279
		end, -- 278
		{ -- 280
			minPanelHeight, -- 280
			panelHeight.value, -- 280
			panelToTooltipGap, -- 280
			panelTop, -- 280
			tooltipReserveHeight -- 280
		} -- 280
	) -- 280
	local ____React_createElement_9 = React.createElement -- 280
	local ____array_8 = __TS__SparseArrayNew( -- 280
		"align-node", -- 280
		{windowRoot = true, style = {padding = 18, flexDirection = "column"}, onLayout = onLayout}, -- 280
		React.createElement( -- 280
			Row, -- 283
			{key = "top-hud", gap = 14, style = {width = "100%", height = 58, alignItems = "center"}}, -- 283
			React.createElement( -- 283
				Column, -- 284
				{style = {width = compact.value and 220 or 320, gap = 7}}, -- 284
				React.createElement(HealthBar, {value = hp.value, max = 1, showValue = true, style = {width = "100%", height = 22}}), -- 284
				React.createElement(ProgressBar, { -- 284
					value = mana.value, -- 284
					max = 1, -- 284
					variant = "mana", -- 284
					showValue = true, -- 284
					style = {width = "100%", height = 14} -- 284
				}) -- 284
			), -- 284
			React.createElement(ResourceCounter, {icon = "coin", value = gold.value, variant = "warm"}), -- 284
			React.createElement(ResourceCounter, {icon = "mana", value = gems.value}), -- 284
			React.createElement( -- 284
				Button, -- 290
				{ -- 290
					variant = settingsOpen.value and "primary" or "secondary", -- 290
					icon = "gear", -- 290
					style = {width = 128}, -- 290
					onClick = function() -- 290
						settingsOpen.value = not settingsOpen.value -- 291
						pushLog(settingsOpen.value and "Panel Open" or "Panel Close") -- 292
					end -- 290
				}, -- 290
				"Panel" -- 290
			), -- 290
			React.createElement( -- 290
				Button, -- 296
				{ -- 296
					variant = "secondary", -- 296
					icon = "warning", -- 296
					style = {width = 128}, -- 296
					onClick = function() -- 296
						modalOpen.value = true -- 297
						pushLog("Modal") -- 298
					end -- 296
				}, -- 296
				"Modal" -- 296
			) -- 296
		) -- 296
	) -- 296
	local ____settingsOpen_value_6 -- 303
	if settingsOpen.value then -- 303
		local ____React_createElement_5 = React.createElement -- 303
		local ____Panel_3 = Panel -- 304
		local ____temp_4 = { -- 304
			key = "user-test-panel", -- 304
			title = "UIX Test", -- 304
			variant = "glass", -- 304
			padding = 14, -- 304
			headerHeight = 34, -- 304
			style = { -- 304
				position = "absolute", -- 310
				left = 18, -- 310
				top = panelTop, -- 310
				width = panelWidth, -- 310
				height = panelHeight.value -- 310
			} -- 310
		} -- 310
		local ____React_createElement_2 = React.createElement -- 310
		local ____array_1 = __TS__SparseArrayNew( -- 310
			Column, -- 312
			{key = "panel-body", align = "flex-start", justify = "flex-start", style = {gap = 12, width = "100%"}}, -- 312
			React.createElement( -- 312
				Tabs, -- 313
				{ -- 313
					key = "main-tabs", -- 313
					value = activeTab.value, -- 313
					items = {{id = "combat", label = "Combat"}, {id = "inventory", label = "Bag"}, {id = "settings", label = "Tune"}}, -- 313
					onValueChange = function(value) -- 313
						activeTab.value = value -- 322
						pushLog(value) -- 323
					end -- 321
				} -- 321
			) -- 321
		) -- 321
		local ____shouldScrollPage_0 -- 326
		if shouldScrollPage then -- 326
			____shouldScrollPage_0 = React.createElement( -- 326
				ScrollView, -- 327
				{ -- 327
					key = "page-scroll-" .. activeTab.value, -- 327
					width = panelWidth - 28, -- 327
					height = pageScrollHeight, -- 327
					contentHeight = math.max(pageScrollHeight, activeContentHeight), -- 327
					wheelSpeed = 18 -- 327
				}, -- 327
				React.createElement(ActivePage, nil) -- 327
			) -- 327
		else -- 327
			____shouldScrollPage_0 = React.createElement(ActivePage, nil) -- 327
		end -- 327
		__TS__SparseArrayPush(____array_1, ____shouldScrollPage_0) -- 327
		____settingsOpen_value_6 = ____React_createElement_5( -- 327
			____Panel_3, -- 304
			____temp_4, -- 304
			____React_createElement_2(__TS__SparseArraySpread(____array_1)) -- 304
		) -- 304
	else -- 304
		____settingsOpen_value_6 = nil -- 339
	end -- 339
	__TS__SparseArrayPush( -- 339
		____array_8, -- 339
		____settingsOpen_value_6, -- 339
		React.createElement( -- 339
			Panel, -- 340
			{ -- 340
				key = "status-panel", -- 340
				title = "Status", -- 340
				variant = "solid", -- 340
				padding = 12, -- 340
				headerHeight = 30, -- 340
				style = { -- 340
					position = "absolute", -- 346
					right = 18, -- 346
					bottom = 18, -- 346
					width = 300, -- 346
					height = 132 -- 346
				} -- 346
			}, -- 346
			React.createElement( -- 346
				Column, -- 348
				{style = {gap = 8, width = "100%"}}, -- 348
				React.createElement(Text, {text = logText.value, fontSize = 18, style = {width = "100%", height = 28}}), -- 348
				React.createElement( -- 348
					Row, -- 350
					{gap = 8, style = {height = 42}}, -- 350
					React.createElement( -- 350
						Button, -- 351
						{ -- 351
							variant = "ghost", -- 351
							icon = "close", -- 351
							style = {width = 92}, -- 351
							onClick = function() -- 351
								hp.value = 0.74 -- 352
								mana.value = 0.52 -- 353
								gold.value = 1460 -- 354
								gems.value = 18 -- 355
								fireCooldown.value = 0 -- 356
								shieldCooldown.value = 0 -- 357
								blinkCooldown.value = 0 -- 358
								pushLog("Reset") -- 359
							end -- 351
						}, -- 351
						"Reset" -- 351
					), -- 351
					React.createElement( -- 351
						Button, -- 363
						{ -- 363
							variant = "secondary", -- 363
							icon = "check", -- 363
							style = {width = 108}, -- 363
							onClick = function() -- 363
								gold.value = gold.value + 10 -- 364
								mana.value = math.min(1, mana.value + 0.08) -- 365
								pushLog("Tick") -- 366
							end -- 363
						}, -- 363
						"Tick" -- 363
					) -- 363
				) -- 363
			) -- 363
		) -- 363
	) -- 363
	local ____tooltipVisible_value_7 -- 373
	if tooltipVisible.value then -- 373
		____tooltipVisible_value_7 = React.createElement(Tooltip, {key = "hint-tooltip", title = "UIX", text = "Use tabs, toggles, slider, modal and cooldown buttons for testing.", style = {position = "absolute", left = 18, bottom = 18}}) -- 373
	else -- 373
		____tooltipVisible_value_7 = nil -- 379
	end -- 379
	__TS__SparseArrayPush( -- 379
		____array_8, -- 379
		____tooltipVisible_value_7, -- 379
		React.createElement( -- 379
			ToastStack, -- 380
			{ -- 380
				key = "toast-stack", -- 380
				items = { -- 380
					{id = "last", title = "Last Action", message = logText.value}, -- 383
					{ -- 384
						id = "hp", -- 384
						message = ((("HP " .. tostring(math.floor(hp.value * 100))) .. "%  Mana ") .. tostring(math.floor(mana.value * 100))) .. "%" -- 384
					} -- 384
				}, -- 384
				style = {right = 18, top = 92} -- 384
			} -- 384
		) -- 384
	) -- 384
	return ____React_createElement_9(__TS__SparseArraySpread(____array_8)) -- 281
end -- 266
local function ModalLayer() -- 392
	return React.createElement( -- 393
		Modal, -- 394
		{ -- 394
			key = "test-modal", -- 394
			open = modalOpen.value, -- 394
			title = "UIX Modal", -- 394
			message = "This modal uses a vector backdrop and a Panel body.", -- 394
			width = 300, -- 394
			height = 196, -- 394
			actions = {{id = "loot", label = "Loot", variant = "primary"}, {id = "close", label = "Close", variant = "secondary"}}, -- 394
			onClose = function() -- 394
				modalOpen.value = false -- 406
				pushLog("Backdrop Close") -- 407
			end, -- 405
			onAction = function(id) -- 405
				if id == "loot" then -- 405
					gold.value = gold.value + 120 -- 411
					gems.value = gems.value + 1 -- 412
					pushLog("Modal Loot") -- 413
				end -- 413
				modalOpen.value = false -- 415
			end -- 409
		}, -- 409
		React.createElement( -- 409
			Toggle, -- 418
			{ -- 418
				checked = tooltipVisible.value, -- 418
				label = "Show Tooltip", -- 418
				onChange = function(value) -- 418
					tooltipVisible.value = value -- 419
					pushLog(value and "Tooltip On" or "Tooltip Off") -- 420
				end -- 418
			} -- 418
		) -- 418
	) -- 418
end -- 392
local root = createRoot(host) -- 426
root:render(function() return React.createElement(App, nil) end) -- 427
local modalRoot = createRoot(modalHost) -- 428
modalRoot:render(function() return React.createElement(ModalLayer, nil) end) -- 429
host:schedule(loop(function() -- 431
	sleep(0.25) -- 432
	fireCooldown.value = math.max(0, fireCooldown.value - 0.25) -- 433
	shieldCooldown.value = math.max(0, shieldCooldown.value - 0.25) -- 434
	blinkCooldown.value = math.max(0, blinkCooldown.value - 0.25) -- 435
	if autoRegen.value then -- 435
		hp.value = math.min(1, hp.value + 0.005) -- 437
		mana.value = math.min(1, mana.value + 0.018) -- 438
	end -- 438
	return false -- 440
end)) -- 431
host:onCleanup(function() -- 443
	host:unschedule() -- 444
	root:unmount() -- 445
	modalRoot:unmount() -- 446
	modalHost:removeFromParent(true) -- 447
end) -- 443
return ____exports -- 443