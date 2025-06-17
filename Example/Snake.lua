-- [tsx]: Snake.tsx
local ____lualib = require("lualib_bundle") -- 1
local __TS__Class = ____lualib.__TS__Class -- 1
local __TS__ArrayForEach = ____lualib.__TS__ArrayForEach -- 1
local __TS__ArraySome = ____lualib.__TS__ArraySome -- 1
local __TS__ArrayUnshift = ____lualib.__TS__ArrayUnshift -- 1
local __TS__New = ____lualib.__TS__New -- 1
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local toNode = ____DoraX.toNode -- 2
local ____Dora = require("Dora") -- 3
local Node = ____Dora.Node -- 3
local Size = ____Dora.Size -- 3
local Vec2 = ____Dora.Vec2 -- 3
local Director = ____Dora.Director -- 3
local Label = ____Dora.Label -- 3
local Sequence = ____Dora.Sequence -- 3
local Spawn = ____Dora.Spawn -- 3
local Ease = ____Dora.Ease -- 3
local Color = ____Dora.Color -- 3
local threadLoop = ____Dora.threadLoop -- 3
local DrawNode = ____Dora.DrawNode -- 3
local Scale = ____Dora.Scale -- 3
local App = ____Dora.App -- 3
local tolua = ____Dora.tolua -- 3
local View = ____Dora.View -- 3
local Line = ____Dora.Line -- 3
local ____InputManager = require("InputManager") -- 4
local CreateManager = ____InputManager.CreateManager -- 4
local Trigger = ____InputManager.Trigger -- 4
local GamePad = ____InputManager.GamePad -- 4
local function KeyDown(keyName, buttonName) -- 6
	return Trigger.Selector({ -- 7
		Trigger.KeyDown(keyName), -- 8
		Trigger.ButtonDown(buttonName) -- 9
	}) -- 9
end -- 6
local inputManager = CreateManager({Game = { -- 13
	Up = KeyDown("W", "dpup"), -- 15
	Down = KeyDown("S", "dpdown"), -- 16
	Left = KeyDown("A", "dpleft"), -- 17
	Right = KeyDown("D", "dpright"), -- 18
	Start = KeyDown("R", "b") -- 19
}}) -- 19
inputManager:getNode():addTo(Director.ui) -- 23
local ____opt_0 = toNode(React.createElement(GamePad, { -- 23
	inputManager = inputManager, -- 23
	noLeftStick = true, -- 23
	noRightStick = true, -- 23
	noTriggerPad = true, -- 23
	noControlPad = true -- 23
})) -- 23
if ____opt_0 ~= nil then -- 23
	____opt_0:addTo(Director.ui) -- 25
end -- 25
inputManager:pushContext("Game") -- 29
local GRID_SIZE = 20 -- 32
local CELL_SIZE = 20 -- 33
local GAME_WIDTH = GRID_SIZE * CELL_SIZE -- 34
local GAME_HEIGHT = GRID_SIZE * CELL_SIZE -- 35
local INITIAL_SPEED = 0.15 -- 36
local function updateViewSize() -- 39
	local camera = tolua.cast(Director.currentCamera, "Camera2D") -- 40
	if camera then -- 40
		camera.zoom = View.size.height / GAME_HEIGHT -- 42
	end -- 42
end -- 39
updateViewSize() -- 45
Director.entry:onAppChange(function(settingName) -- 46
	if settingName == "Size" then -- 46
		updateViewSize() -- 48
	end -- 48
end) -- 46
local function filterChild(node, filter) -- 60
	local children = {} -- 61
	node:eachChild(function(child) -- 62
		if filter(child) then -- 62
			children[#children + 1] = child -- 64
		end -- 64
		return false -- 66
	end) -- 62
	return children -- 68
end -- 60
local SnakeGame = __TS__Class() -- 71
SnakeGame.name = "SnakeGame" -- 71
function SnakeGame.prototype.____constructor(self) -- 84
	self.snake = {} -- 73
	self.food = nil -- 74
	self.currentDirection = "Right" -- 75
	self.nextDirection = "Right" -- 76
	self.score = 0 -- 77
	self.isGameOver = false -- 80
	self.speed = INITIAL_SPEED -- 81
	self.lastMoveTime = 0 -- 82
	Line({ -- 85
		Vec2(-GAME_WIDTH / 2, -GAME_HEIGHT / 2), -- 86
		Vec2(GAME_WIDTH / 2, -GAME_HEIGHT / 2), -- 87
		Vec2(GAME_WIDTH / 2, GAME_HEIGHT / 2 - 1), -- 88
		Vec2(-GAME_WIDTH / 2, GAME_HEIGHT / 2 - 1), -- 89
		Vec2(-GAME_WIDTH / 2, -GAME_HEIGHT / 2) -- 90
	}):addTo(Director.entry) -- 90
	self.root = Node() -- 94
	self.root.size = Size(GAME_WIDTH, GAME_HEIGHT) -- 95
	Director.entry:addChild(self.root) -- 96
	self.scoreLabel = Label("sarasa-mono-sc-regular", 30 * 2, true) -- 99
	self.scoreLabel.scaleX = 0.5 -- 100
	self.scoreLabel.scaleY = 0.5 -- 101
	self.scoreLabel.text = "Score: 0" -- 102
	self.scoreLabel.position = Vec2(80, GAME_HEIGHT - 30) -- 103
	self.scoreLabel.alignment = "Left" -- 104
	self.root:addChild(self.scoreLabel, 1) -- 105
	self.gameOverLabel = Label("sarasa-mono-sc-regular", 36 * 2, true) -- 108
	self.gameOverLabel.scaleX = 0.5 -- 109
	self.gameOverLabel.scaleY = 0.5 -- 110
	self.gameOverLabel.text = "Game Over!\nPress R to restart" -- 111
	self.gameOverLabel.position = Vec2(GAME_WIDTH / 2, GAME_HEIGHT / 2) -- 112
	self.gameOverLabel.visible = false -- 113
	self.root:addChild(self.gameOverLabel, 1) -- 114
	self:resetGame() -- 117
	self:setupControls() -- 120
	self:startGameLoop() -- 123
end -- 84
function SnakeGame.prototype.resetGame(self) -- 126
	__TS__ArrayForEach( -- 128
		filterChild( -- 128
			self.root, -- 128
			function(child) return child.tag == "snake" or child.tag == "food" end -- 128
		), -- 128
		function(____, child) -- 129
			child:removeFromParent() -- 130
		end -- 129
	) -- 129
	self.snake = { -- 134
		Vec2(5, 10), -- 135
		Vec2(4, 10), -- 136
		Vec2(3, 10) -- 137
	} -- 137
	self.currentDirection = "Right" -- 139
	self.nextDirection = "Right" -- 140
	self.score = 0 -- 141
	self.speed = INITIAL_SPEED -- 142
	self.isGameOver = false -- 143
	self.lastMoveTime = 0 -- 144
	self.scoreLabel.text = "Score: " .. tostring(self.score) -- 145
	self.gameOverLabel.visible = false -- 146
	self:drawSnake() -- 149
	self:spawnFood() -- 152
end -- 126
function SnakeGame.prototype.drawSnake(self) -- 155
	__TS__ArrayForEach( -- 157
		filterChild( -- 157
			self.root, -- 157
			function(child) return child.tag == "snake" end -- 157
		), -- 157
		function(____, child) -- 158
			child:removeFromParent() -- 159
		end -- 158
	) -- 158
	for ____, segment in ipairs(self.snake) do -- 163
		local segmentNode = Node() -- 164
		segmentNode.tag = "snake" -- 165
		segmentNode.size = Size(CELL_SIZE, CELL_SIZE) -- 166
		segmentNode.position = Vec2(segment.x * CELL_SIZE + CELL_SIZE / 2, segment.y * CELL_SIZE + CELL_SIZE / 2) -- 167
		local drawNode = DrawNode() -- 172
		drawNode.position = Vec2(CELL_SIZE / 2, CELL_SIZE / 2) -- 173
		segmentNode:addChild(drawNode) -- 174
		drawNode:drawPolygon( -- 176
			{ -- 177
				Vec2(-CELL_SIZE / 2, -CELL_SIZE / 2), -- 178
				Vec2(CELL_SIZE / 2, -CELL_SIZE / 2), -- 179
				Vec2(CELL_SIZE / 2, CELL_SIZE / 2), -- 180
				Vec2(-CELL_SIZE / 2, CELL_SIZE / 2) -- 181
			}, -- 181
			Color(0, 255, 0, 255), -- 183
			1, -- 184
			Color(0, 200, 0, 255) -- 185
		) -- 185
		self.root:addChild(segmentNode) -- 188
	end -- 188
end -- 155
function SnakeGame.prototype.spawnFood(self) -- 192
	__TS__ArrayForEach( -- 194
		filterChild( -- 194
			self.root, -- 194
			function(child) return child.tag == "food" end -- 194
		), -- 194
		function(____, child) -- 195
			child:removeFromParent() -- 196
		end -- 195
	) -- 195
	local availableCells = {} -- 200
	do -- 200
		local x = 0 -- 201
		while x < GRID_SIZE do -- 201
			do -- 201
				local y = 0 -- 202
				while y < GRID_SIZE do -- 202
					local pos = Vec2(x, y) -- 203
					if not __TS__ArraySome( -- 203
						self.snake, -- 204
						function(____, segment) return segment:equals(pos) end -- 204
					) then -- 204
						availableCells[#availableCells + 1] = pos -- 205
					end -- 205
					y = y + 1 -- 202
				end -- 202
			end -- 202
			x = x + 1 -- 201
		end -- 201
	end -- 201
	if #availableCells == 0 then -- 201
		self:gameOver(true) -- 212
		return -- 213
	end -- 213
	local randomIndex = math.floor(math.random() * #availableCells) -- 216
	self.food = availableCells[randomIndex + 1] -- 217
	local foodNode = Node() -- 220
	foodNode.tag = "food" -- 221
	foodNode.size = Size(CELL_SIZE, CELL_SIZE) -- 222
	foodNode.position = Vec2(self.food.x * CELL_SIZE + CELL_SIZE / 2, self.food.y * CELL_SIZE + CELL_SIZE / 2) -- 223
	local drawNode = DrawNode() -- 228
	drawNode.position = Vec2(CELL_SIZE / 2, CELL_SIZE / 2) -- 229
	foodNode:addChild(drawNode) -- 230
	drawNode:drawPolygon( -- 232
		{ -- 233
			Vec2(-CELL_SIZE / 2, -CELL_SIZE / 2), -- 234
			Vec2(CELL_SIZE / 2, -CELL_SIZE / 2), -- 235
			Vec2(CELL_SIZE / 2, CELL_SIZE / 2), -- 236
			Vec2(-CELL_SIZE / 2, CELL_SIZE / 2) -- 237
		}, -- 237
		Color(255, 0, 0, 255), -- 239
		1, -- 240
		Color(200, 0, 0, 255) -- 241
	) -- 241
	foodNode:runAction(Sequence( -- 245
		Spawn( -- 246
			Scale(0.5, 1, 0.8, Ease.OutBack), -- 247
			Scale(0.5, 1, 1.2, Ease.OutBack) -- 248
		), -- 248
		Spawn( -- 250
			Scale(0.5, 0.8, 1, Ease.OutBack), -- 251
			Scale(0.5, 1.2, 1, Ease.OutBack) -- 252
		) -- 252
	)) -- 252
	self.root:addChild(foodNode) -- 256
end -- 192
function SnakeGame.prototype.moveSnake(self) -- 259
	if self.isGameOver then -- 259
		return -- 260
	end -- 260
	local head = self.snake[1] -- 262
	local newHead -- 263
	repeat -- 263
		local ____switch31 = self.currentDirection -- 263
		local ____cond31 = ____switch31 == "Up" -- 263
		if ____cond31 then -- 263
			newHead = Vec2(head.x, head.y + 1) -- 268
			break -- 269
		end -- 269
		____cond31 = ____cond31 or ____switch31 == "Down" -- 269
		if ____cond31 then -- 269
			newHead = Vec2(head.x, head.y - 1) -- 271
			break -- 272
		end -- 272
		____cond31 = ____cond31 or ____switch31 == "Left" -- 272
		if ____cond31 then -- 272
			newHead = Vec2(head.x - 1, head.y) -- 274
			break -- 275
		end -- 275
		____cond31 = ____cond31 or ____switch31 == "Right" -- 275
		if ____cond31 then -- 275
			newHead = Vec2(head.x + 1, head.y) -- 277
			break -- 278
		end -- 278
	until true -- 278
	if newHead.x < 0 or newHead.x >= GRID_SIZE or newHead.y < 0 or newHead.y >= GRID_SIZE or __TS__ArraySome( -- 278
		self.snake, -- 285
		function(____, segment) return segment:equals(newHead) end, -- 285
		1 -- 285
	) then -- 285
		self:gameOver() -- 287
		return -- 288
	end -- 288
	__TS__ArrayUnshift(self.snake, newHead) -- 292
	if self.food and newHead:equals(self.food) then -- 292
		self.score = self.score + 1 -- 296
		self.scoreLabel.text = "Score: " .. tostring(self.score) -- 297
		if self.score % 5 == 0 then -- 297
			self.speed = math.max(0.05, self.speed * 0.9) -- 301
		end -- 301
		self:spawnFood() -- 304
	else -- 304
		table.remove(self.snake) -- 307
	end -- 307
	self:drawSnake() -- 311
	self.currentDirection = self.nextDirection -- 314
end -- 259
function SnakeGame.prototype.gameOver(self, isWin) -- 317
	if isWin == nil then -- 317
		isWin = false -- 317
	end -- 317
	self.isGameOver = true -- 318
	self.gameOverLabel.text = isWin and "You Win!\nPress R (B) to restart" or "Game Over!\nPress R (B) to restart" -- 319
	self.gameOverLabel.visible = true -- 322
end -- 317
function SnakeGame.prototype.setupControls(self) -- 325
	self.root:gslot( -- 326
		"Input.Up", -- 326
		function() -- 326
			if self.currentDirection ~= "Down" then -- 326
				self.nextDirection = "Up" -- 328
			end -- 328
		end -- 326
	) -- 326
	self.root:gslot( -- 331
		"Input.Down", -- 331
		function() -- 331
			if self.currentDirection ~= "Up" then -- 331
				self.nextDirection = "Down" -- 333
			end -- 333
		end -- 331
	) -- 331
	self.root:gslot( -- 336
		"Input.Left", -- 336
		function() -- 336
			if self.currentDirection ~= "Right" then -- 336
				self.nextDirection = "Left" -- 338
			end -- 338
		end -- 336
	) -- 336
	self.root:gslot( -- 341
		"Input.Right", -- 341
		function() -- 341
			if self.currentDirection ~= "Left" then -- 341
				self.nextDirection = "Right" -- 343
			end -- 343
		end -- 341
	) -- 341
	self.root:gslot( -- 346
		"Input.Start", -- 346
		function() -- 346
			if self.isGameOver then -- 346
				self:resetGame() -- 348
			end -- 348
		end -- 346
	) -- 346
end -- 325
function SnakeGame.prototype.startGameLoop(self) -- 353
	threadLoop(function() -- 354
		local now = App.runningTime -- 355
		if now - self.lastMoveTime >= self.speed then -- 355
			self:moveSnake() -- 357
			self.lastMoveTime = now -- 358
		end -- 358
		return false -- 360
	end) -- 354
end -- 353
__TS__New(SnakeGame) -- 366
return ____exports -- 366