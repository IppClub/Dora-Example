-- [tsx]: ExcelTestTSX.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local toNode = ____DoraX.toNode -- 2
local ____Platformer = require("Platformer") -- 3
local Data = ____Platformer.Data -- 3
local PlatformWorld = ____Platformer.PlatformWorld -- 3
local Unit = ____Platformer.Unit -- 3
local UnitAction = ____Platformer.UnitAction -- 3
local ____Dora = require("Dora") -- 4
local App = ____Dora.App -- 4
local Color = ____Dora.Color -- 4
local Color3 = ____Dora.Color3 -- 4
local Dictionary = ____Dora.Dictionary -- 4
local Rect = ____Dora.Rect -- 4
local Size = ____Dora.Size -- 4
local Vec2 = ____Dora.Vec2 -- 4
local View = ____Dora.View -- 4
local loop = ____Dora.loop -- 4
local once = ____Dora.once -- 4
local sleep = ____Dora.sleep -- 4
local Array = ____Dora.Array -- 4
local Observer = ____Dora.Observer -- 4
local Sprite = ____Dora.Sprite -- 4
local Spawn = ____Dora.Spawn -- 4
local Ease = ____Dora.Ease -- 4
local Y = ____Dora.Y -- 4
local tolua = ____Dora.tolua -- 4
local Scale = ____Dora.Scale -- 4
local Opacity = ____Dora.Opacity -- 4
local Content = ____Dora.Content -- 4
local Group = ____Dora.Group -- 4
local Entity = ____Dora.Entity -- 4
local Director = ____Dora.Director -- 4
local Keyboard = ____Dora.Keyboard -- 4
local ____PlatformerX = require("PlatformerX") -- 5
local DecisionTree = ____PlatformerX.DecisionTree -- 5
local toAI = ____PlatformerX.toAI -- 5
local ____Utils = require("Utils") -- 280
local Struct = ____Utils.Struct -- 280
local CircleButtonCreate = require("UI.Control.Basic.CircleButton") -- 331
local ImGui = require("ImGui") -- 333
local TerrainLayer = 0 -- 7
local PlayerLayer = 1 -- 8
local ItemLayer = 2 -- 9
local PlayerGroup = Data.groupFirstPlayer -- 11
local ItemGroup = Data.groupFirstPlayer + 1 -- 12
local TerrainGroup = Data.groupTerrain -- 13
Data:setShouldContact(PlayerGroup, ItemGroup, true) -- 15
local themeColor = App.themeColor -- 17
local color = themeColor:toARGB() -- 18
local DesignWidth = 1500 -- 19
local world = PlatformWorld() -- 21
world.camera.boundary = Rect(-1250, -500, 2500, 1000) -- 22
world.camera.followRatio = Vec2(0.02, 0.02) -- 23
world.camera.zoom = View.size.width / DesignWidth -- 24
world:onAppChange(function(settingName) -- 25
	if settingName == "Size" then -- 25
		world.camera.zoom = View.size.width / DesignWidth -- 27
	end -- 27
end) -- 25
local function RectShape(props) -- 39
	local x = props.x or 0 -- 40
	local y = props.y or 0 -- 41
	local color = Color3(props.color) -- 42
	local fillColor = Color(color, 102):toARGB() -- 43
	local borderColor = Color(color, 255):toARGB() -- 44
	return React.createElement("rect-shape", { -- 45
		centerX = x, -- 45
		centerY = y, -- 45
		width = props.width, -- 45
		height = props.height, -- 45
		fillColor = fillColor, -- 45
		borderColor = borderColor, -- 45
		borderWidth = 1 -- 45
	}) -- 45
end -- 39
local terrain = toNode(React.createElement( -- 56
	"body", -- 56
	{type = "Static", world = world, order = TerrainLayer, group = TerrainGroup}, -- 56
	React.createElement("rect-fixture", { -- 56
		centerY = -500, -- 56
		width = 2500, -- 56
		height = 10, -- 56
		friction = 1, -- 56
		restitution = 0 -- 56
	}), -- 56
	React.createElement("rect-fixture", { -- 56
		centerY = 500, -- 56
		width = 2500, -- 56
		height = 10, -- 56
		friction = 1, -- 56
		restitution = 0 -- 56
	}), -- 56
	React.createElement("rect-fixture", { -- 56
		centerX = 1250, -- 56
		width = 10, -- 56
		height = 2500, -- 56
		friction = 1, -- 56
		restitution = 0 -- 56
	}), -- 56
	React.createElement("rect-fixture", { -- 56
		centerX = -1250, -- 56
		width = 10, -- 56
		height = 2500, -- 56
		friction = 1, -- 56
		restitution = 0 -- 56
	}), -- 56
	React.createElement( -- 56
		"draw-node", -- 56
		nil, -- 56
		React.createElement(RectShape, {y = -500, width = 2500, height = 10, color = color}), -- 56
		React.createElement(RectShape, {x = 1250, width = 10, height = 1000, color = color}), -- 56
		React.createElement(RectShape, {x = -1250, width = 10, height = 1000, color = color}) -- 56
	) -- 56
)) -- 56
if terrain ~= nil then -- 56
	terrain:addTo(world) -- 69
end -- 69
UnitAction:add( -- 71
	"idle", -- 71
	{ -- 71
		priority = 1, -- 72
		reaction = 2, -- 73
		recovery = 0.2, -- 74
		available = function(____self) return ____self.onSurface end, -- 75
		create = function(____self) -- 76
			local ____self_2 = ____self -- 77
			local playable = ____self_2.playable -- 77
			playable.speed = 1 -- 78
			playable:play("idle", true) -- 79
			local playIdleSpecial = loop(function() -- 80
				sleep(3) -- 81
				sleep(playable:play("idle1")) -- 82
				playable:play("idle", true) -- 83
				return false -- 84
			end) -- 80
			____self.data.playIdleSpecial = playIdleSpecial -- 86
			return function(owner) -- 87
				coroutine.resume(playIdleSpecial) -- 88
				return not owner.onSurface -- 89
			end -- 87
		end -- 76
	} -- 76
) -- 76
UnitAction:add( -- 94
	"move", -- 94
	{ -- 94
		priority = 1, -- 95
		reaction = 2, -- 96
		recovery = 0.2, -- 97
		available = function(____self) return ____self.onSurface end, -- 98
		create = function(____self) -- 99
			local ____self_3 = ____self -- 100
			local playable = ____self_3.playable -- 100
			playable.speed = 1 -- 101
			playable:play("fmove", true) -- 102
			return function(____self, action) -- 103
				local ____action_4 = action -- 104
				local elapsedTime = ____action_4.elapsedTime -- 104
				local recovery = action.recovery * 2 -- 105
				local move = ____self.unitDef.move -- 106
				local moveSpeed = 1 -- 107
				if elapsedTime < recovery then -- 107
					moveSpeed = math.min(elapsedTime / recovery, 1) -- 109
				end -- 109
				____self.velocityX = moveSpeed * (____self.faceRight and move or -move) -- 111
				return not ____self.onSurface -- 112
			end -- 103
		end -- 99
	} -- 99
) -- 99
UnitAction:add( -- 117
	"jump", -- 117
	{ -- 117
		priority = 3, -- 118
		reaction = 2, -- 119
		recovery = 0.1, -- 120
		queued = true, -- 121
		available = function(____self) return ____self.onSurface end, -- 122
		create = function(____self) -- 123
			local jump = ____self.unitDef.jump -- 124
			____self.velocityY = jump -- 125
			return once(function() -- 126
				local ____self_5 = ____self -- 127
				local playable = ____self_5.playable -- 127
				playable.speed = 1 -- 128
				sleep(playable:play("jump", false)) -- 129
			end) -- 126
		end -- 123
	} -- 123
) -- 123
UnitAction:add( -- 134
	"fallOff", -- 134
	{ -- 134
		priority = 2, -- 135
		reaction = -1, -- 136
		recovery = 0.3, -- 137
		available = function(____self) return not ____self.onSurface end, -- 138
		create = function(____self) -- 139
			local ____self_6 = ____self -- 140
			local playable = ____self_6.playable -- 140
			if playable.current ~= "jumping" then -- 140
				playable.speed = 1 -- 142
				playable:play("jumping", true) -- 143
			end -- 143
			return loop(function() -- 145
				if ____self.onSurface then -- 145
					playable.speed = 1 -- 147
					sleep(playable:play("landing", false)) -- 148
					return true -- 149
				end -- 149
				return false -- 151
			end) -- 145
		end -- 139
	} -- 139
) -- 139
local ____DecisionTree_7 = DecisionTree -- 156
local Selector = ____DecisionTree_7.Selector -- 156
local Match = ____DecisionTree_7.Match -- 156
local Action = ____DecisionTree_7.Action -- 156
Data.store["AI:playerControl"] = toAI(React.createElement( -- 158
	Selector, -- 159
	nil, -- 159
	React.createElement( -- 159
		Match, -- 160
		{ -- 160
			desc = "fmove key down", -- 160
			onCheck = function(____self) -- 160
				local keyLeft = ____self.entity.keyLeft -- 161
				local keyRight = ____self.entity.keyRight -- 162
				return not (keyLeft and keyRight) and (keyLeft and ____self.faceRight or keyRight and not ____self.faceRight) -- 163
			end -- 160
		}, -- 160
		React.createElement(Action, {name = "turn"}) -- 160
	), -- 160
	React.createElement( -- 160
		Match, -- 172
		{ -- 172
			desc = "is falling", -- 172
			onCheck = function(____self) return not ____self.onSurface end -- 172
		}, -- 172
		React.createElement(Action, {name = "fallOff"}) -- 172
	), -- 172
	React.createElement( -- 172
		Match, -- 176
		{ -- 176
			desc = "jump key down", -- 176
			onCheck = function(____self) return ____self.entity.keyJump end -- 176
		}, -- 176
		React.createElement(Action, {name = "jump"}) -- 176
	), -- 176
	React.createElement( -- 176
		Match, -- 180
		{ -- 180
			desc = "fmove key down", -- 180
			onCheck = function(____self) return ____self.entity.keyLeft or ____self.entity.keyRight end -- 180
		}, -- 180
		React.createElement(Action, {name = "move"}) -- 180
	), -- 180
	React.createElement(Action, {name = "idle"}) -- 180
)) -- 180
local unitDef = Dictionary() -- 188
unitDef.linearAcceleration = Vec2(0, -15) -- 189
unitDef.bodyType = "Dynamic" -- 190
unitDef.scale = 1 -- 191
unitDef.density = 1 -- 192
unitDef.friction = 1 -- 193
unitDef.restitution = 0 -- 194
unitDef.playable = "spine:Spine/moling" -- 195
unitDef.defaultFaceRight = true -- 196
unitDef.size = Size(60, 300) -- 197
unitDef.sensity = 0 -- 198
unitDef.move = 300 -- 199
unitDef.jump = 1000 -- 200
unitDef.detectDistance = 350 -- 201
unitDef.hp = 5 -- 202
unitDef.tag = "player" -- 203
unitDef.decisionTree = "AI:playerControl" -- 204
unitDef.actions = Array({ -- 205
	"idle", -- 206
	"turn", -- 207
	"move", -- 208
	"jump", -- 209
	"fallOff", -- 210
	"cancel" -- 211
}) -- 211
Observer("Add", {"player"}):watch(function(____self) -- 214
	local unit = Unit( -- 215
		unitDef, -- 215
		world, -- 215
		____self, -- 215
		Vec2(300, -350) -- 215
	) -- 215
	unit.order = PlayerLayer -- 216
	unit.group = PlayerGroup -- 217
	unit.playable.position = Vec2(0, -150) -- 218
	unit.playable:play("idle", true) -- 219
	world:addChild(unit) -- 220
	world.camera.followTarget = unit -- 221
	return false -- 222
end) -- 214
Observer("Add", {"x", "icon"}):watch(function(____self, x, icon) -- 225
	local sprite = toNode(React.createElement( -- 226
		"sprite", -- 226
		{file = icon}, -- 226
		React.createElement( -- 226
			"loop", -- 226
			nil, -- 226
			React.createElement( -- 226
				"spawn", -- 226
				nil, -- 226
				React.createElement("angle-y", {time = 5, start = 0, stop = 360}), -- 226
				React.createElement( -- 226
					"sequence", -- 226
					nil, -- 226
					React.createElement("move-y", {time = 2.5, start = 0, stop = 40, easing = Ease.OutQuad}), -- 226
					React.createElement("move-y", {time = 2.5, start = 40, stop = 0, easing = Ease.InQuad}) -- 226
				) -- 226
			) -- 226
		) -- 226
	)) -- 226
	if not sprite then -- 226
		return false -- 239
	end -- 239
	local body = toNode(React.createElement( -- 241
		"body", -- 241
		{ -- 241
			type = "Dynamic", -- 241
			world = world, -- 241
			linearAcceleration = Vec2(0, -10), -- 241
			x = x, -- 241
			order = ItemLayer, -- 241
			group = ItemGroup -- 241
		}, -- 241
		React.createElement("rect-fixture", {width = sprite.width * 0.5, height = sprite.height}), -- 241
		React.createElement("rect-fixture", {sensorTag = 0, width = sprite.width, height = sprite.height}) -- 241
	)) -- 241
	if not body then -- 241
		return false -- 249
	end -- 249
	local itemBody = body -- 251
	body:addChild(sprite) -- 252
	itemBody:onBodyEnter(function(item) -- 253
		if tolua.type(item) == "Platformer::Unit" then -- 253
			____self.picked = true -- 255
			itemBody.group = Data.groupHide -- 256
			itemBody:schedule(once(function() -- 257
				sleep(sprite:runAction(Spawn( -- 258
					Scale(0.2, 1, 1.3, Ease.OutBack), -- 259
					Opacity(0.2, 1, 0) -- 260
				))) -- 260
				____self.body = nil -- 262
			end)) -- 257
		end -- 257
	end) -- 253
	world:addChild(body) -- 267
	____self.body = body -- 268
	return false -- 269
end) -- 225
Observer("Remove", {"body"}):watch(function(____self) -- 272
	local body = tolua.cast(____self.oldValues.body, "Body") -- 273
	if body ~= nil then -- 273
		body:removeFromParent() -- 275
	end -- 275
	return false -- 277
end) -- 272
local function loadExcel() -- 301
	local xlsx = Content:loadExcel("Data/items.xlsx", {"items"}) -- 302
	if xlsx ~= nil then -- 302
		local its = xlsx.items -- 304
		if not its then -- 304
			return -- 305
		end -- 305
		local names = its[2] -- 306
		table.remove(names, 1) -- 307
		if not Struct:has("Item") then -- 307
			Struct.Item(names) -- 309
		end -- 309
		Group({"item"}):each(function(e) -- 311
			e:destroy() -- 312
			return false -- 313
		end) -- 311
		do -- 311
			local i = 2 -- 315
			while i < #its do -- 315
				local st = Struct:load(its[i + 1]) -- 316
				local item = { -- 317
					name = st.Name, -- 318
					no = st.No, -- 319
					x = st.X, -- 320
					num = st.Num, -- 321
					icon = st.Icon, -- 322
					desc = st.Desc, -- 323
					item = true -- 324
				} -- 324
				Entity(item) -- 326
				i = i + 1 -- 315
			end -- 315
		end -- 315
	end -- 315
end -- 301
local keyboardEnabled = true -- 335
local playerGroup = Group({"player"}) -- 337
local function updatePlayerControl(key, flag, vpad) -- 338
	if keyboardEnabled and vpad then -- 338
		keyboardEnabled = false -- 340
	end -- 340
	playerGroup:each(function(____self) -- 342
		____self[key] = flag -- 343
		return false -- 344
	end) -- 342
end -- 338
local function CircleButton(props) -- 352
	return React.createElement( -- 353
		"custom-node", -- 353
		__TS__ObjectAssign( -- 353
			{onCreate = function() return CircleButtonCreate({text = props.text, radius = 60, fontSize = 36}) end}, -- 353
			props -- 357
		) -- 357
	) -- 357
end -- 352
local ui = toNode(React.createElement( -- 360
	"align-node", -- 360
	{ -- 360
		windowRoot = true, -- 360
		style = {flexDirection = "column-reverse"}, -- 360
		onButtonDown = function(id, buttonName) -- 360
			if id ~= 0 then -- 360
				return -- 363
			end -- 363
			repeat -- 363
				local ____switch48 = buttonName -- 363
				local ____cond48 = ____switch48 == "dpleft" -- 363
				if ____cond48 then -- 363
					updatePlayerControl("keyLeft", true, true) -- 365
					break -- 365
				end -- 365
				____cond48 = ____cond48 or ____switch48 == "dpright" -- 365
				if ____cond48 then -- 365
					updatePlayerControl("keyRight", true, true) -- 366
					break -- 366
				end -- 366
				____cond48 = ____cond48 or ____switch48 == "b" -- 366
				if ____cond48 then -- 366
					updatePlayerControl("keyJump", true, true) -- 367
					break -- 367
				end -- 367
			until true -- 367
		end, -- 362
		onButtonUp = function(id, buttonName) -- 362
			if id ~= 0 then -- 362
				return -- 371
			end -- 371
			repeat -- 371
				local ____switch51 = buttonName -- 371
				local ____cond51 = ____switch51 == "dpleft" -- 371
				if ____cond51 then -- 371
					updatePlayerControl("keyLeft", false, true) -- 373
					break -- 373
				end -- 373
				____cond51 = ____cond51 or ____switch51 == "dpright" -- 373
				if ____cond51 then -- 373
					updatePlayerControl("keyRight", false, true) -- 374
					break -- 374
				end -- 374
				____cond51 = ____cond51 or ____switch51 == "b" -- 374
				if ____cond51 then -- 374
					updatePlayerControl("keyJump", false, true) -- 375
					break -- 375
				end -- 375
			until true -- 375
		end -- 370
	}, -- 370
	React.createElement( -- 370
		"align-node", -- 370
		{style = {height = 60, justifyContent = "space-between", margin = {0, 20, 40}, flexDirection = "row"}}, -- 370
		React.createElement( -- 370
			"align-node", -- 370
			{style = {width = 130, height = 60}}, -- 370
			React.createElement( -- 370
				"menu", -- 370
				{ -- 370
					width = 250, -- 370
					height = 120, -- 370
					anchorX = 0, -- 370
					anchorY = 0, -- 370
					scaleX = 0.5, -- 370
					scaleY = 0.5 -- 370
				}, -- 370
				React.createElement( -- 370
					CircleButton, -- 381
					{ -- 381
						text = "Left\n(a)", -- 381
						anchorX = 0, -- 381
						anchorY = 0, -- 381
						onTapBegan = function() return updatePlayerControl("keyLeft", true, true) end, -- 381
						onTapEnded = function() return updatePlayerControl("keyLeft", false, true) end -- 381
					} -- 381
				), -- 381
				React.createElement( -- 381
					CircleButton, -- 386
					{ -- 386
						text = "Right\n(a)", -- 386
						x = 130, -- 386
						anchorX = 0, -- 386
						anchorY = 0, -- 386
						onTapBegan = function() return updatePlayerControl("keyRight", true, true) end, -- 386
						onTapEnded = function() return updatePlayerControl("keyRight", false, true) end -- 386
					} -- 386
				) -- 386
			) -- 386
		), -- 386
		React.createElement( -- 386
			"align-node", -- 386
			{style = {width = 60, height = 60}}, -- 386
			React.createElement( -- 386
				"menu", -- 386
				{ -- 386
					width = 120, -- 386
					height = 120, -- 386
					anchorX = 0, -- 386
					anchorY = 0, -- 386
					scaleX = 0.5, -- 386
					scaleY = 0.5 -- 386
				}, -- 386
				React.createElement( -- 386
					CircleButton, -- 395
					{ -- 395
						text = "Jump\n(j)", -- 395
						anchorX = 0, -- 395
						anchorY = 0, -- 395
						onTapBegan = function() return updatePlayerControl("keyJump", true, true) end, -- 395
						onTapEnded = function() return updatePlayerControl("keyJump", false, true) end -- 395
					} -- 395
				) -- 395
			) -- 395
		) -- 395
	) -- 395
)) -- 395
if ui then -- 395
	ui:addTo(Director.ui) -- 407
	ui:schedule(function() -- 408
		local keyA = Keyboard:isKeyPressed("A") -- 409
		local keyD = Keyboard:isKeyPressed("D") -- 410
		local keyJ = Keyboard:isKeyPressed("J") -- 411
		if keyD or keyD or keyJ then -- 411
			keyboardEnabled = true -- 413
		end -- 413
		if not keyboardEnabled then -- 413
			return false -- 416
		end -- 416
		updatePlayerControl("keyLeft", keyA, false) -- 418
		updatePlayerControl("keyRight", keyD, false) -- 419
		updatePlayerControl("keyJump", keyJ, false) -- 420
		return false -- 421
	end) -- 408
end -- 408
local pickedItemGroup = Group({"picked"}) -- 425
local windowFlags = { -- 426
	"NoDecoration", -- 427
	"AlwaysAutoResize", -- 428
	"NoSavedSettings", -- 429
	"NoFocusOnAppearing", -- 430
	"NoNav", -- 431
	"NoMove" -- 432
} -- 432
Director.ui:schedule(function() -- 434
	local size = App.visualSize -- 435
	ImGui.SetNextWindowBgAlpha(0.35) -- 436
	ImGui.SetNextWindowPos( -- 437
		Vec2(size.width - 10, 10), -- 437
		"Always", -- 437
		Vec2(1, 0) -- 437
	) -- 437
	ImGui.SetNextWindowSize( -- 438
		Vec2(100, 300), -- 438
		"FirstUseEver" -- 438
	) -- 438
	ImGui.Begin( -- 439
		"BackPack", -- 439
		windowFlags, -- 439
		function() -- 439
			if ImGui.Button("重新加载Excel") then -- 439
				loadExcel() -- 441
			end -- 441
			ImGui.Separator() -- 443
			ImGui.Dummy(Vec2(100, 10)) -- 444
			ImGui.Text("背包 (TSX)") -- 445
			ImGui.Separator() -- 446
			ImGui.Columns(3, false) -- 447
			pickedItemGroup:each(function(e) -- 448
				local item = e -- 449
				if item.num > 0 then -- 449
					if ImGui.ImageButton( -- 449
						"item" .. tostring(item.no), -- 451
						item.icon, -- 451
						Vec2(50, 50) -- 451
					) then -- 451
						item.num = item.num - 1 -- 452
						local sprite = Sprite(item.icon) -- 453
						if not sprite then -- 453
							return false -- 454
						end -- 454
						sprite.scaleY = 0.5 -- 455
						sprite.scaleX = 0.5 -- 455
						sprite:perform(Spawn( -- 456
							Opacity(1, 1, 0), -- 457
							Y(1, 150, 250) -- 458
						)) -- 458
						local player = playerGroup:find(function() return true end) -- 460
						if player ~= nil then -- 460
							local unit = player.unit -- 462
							unit:addChild(sprite) -- 463
						end -- 463
					end -- 463
					if ImGui.IsItemHovered() then -- 463
						ImGui.BeginTooltip(function() -- 467
							ImGui.Text(item.name) -- 468
							ImGui.TextColored(themeColor, "数量：") -- 469
							ImGui.SameLine() -- 470
							ImGui.Text(tostring(item.num)) -- 471
							ImGui.TextColored(themeColor, "描述：") -- 472
							ImGui.SameLine() -- 473
							ImGui.Text(tostring(item.desc)) -- 474
						end) -- 467
					end -- 467
					ImGui.NextColumn() -- 477
				end -- 477
				return false -- 479
			end) -- 448
		end -- 439
	) -- 439
	return false -- 482
end) -- 434
Entity({player = true}) -- 485
loadExcel() -- 486
return ____exports -- 486