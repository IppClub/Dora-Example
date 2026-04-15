-- [yue]: Example/TextInput.yue
local _ENV = Dora -- 2
local LineRect = require("UI.View.Shape.LineRect") -- 3
local SolidRect = require("UI.View.Shape.SolidRect") -- 4
local utf8 = require("utf-8") -- 5
local Class <const> = Class -- 6
local Label <const> = Label -- 6
local Vec2 <const> = Vec2 -- 6
local Line <const> = Line -- 6
local Color <const> = Color -- 6
local loop <const> = loop -- 6
local sleep <const> = sleep -- 6
local math <const> = math -- 6
local ClipNode <const> = ClipNode -- 6
local Size <const> = Size -- 6
local Keyboard <const> = Keyboard -- 6
local App <const> = App -- 6
local Node <const> = Node -- 6
local property <const> = property -- 6
local TextInput = Class((function(args) -- 8
	local fontName, fontSize, width, height, hint, text = args.fontName, args.fontSize, args.width, args.height, args.hint, args.text -- 9
	if hint == nil then -- 14
		hint = "" -- 14
	end -- 14
	if text == nil then -- 15
		text = hint -- 15
	end -- 15
	local label -- 18
	do -- 18
		local _with_0 = Label(fontName, fontSize) -- 18
		_with_0.batched = false -- 19
		_with_0.text = text -- 20
		_with_0.y = height / 2 - fontSize / 2 -- 21
		_with_0.anchor = Vec2.zero -- 22
		_with_0.alignment = "Left" -- 23
		label = _with_0 -- 18
	end -- 18
	local cursor = Line({ -- 25
		Vec2.zero, -- 25
		Vec2(0, fontSize + 2) -- 25
	}, Color(0xffffffff)) -- 25
	local blink -- 26
	blink = function() -- 26
		return loop(function() -- 26
			cursor.visible = true -- 27
			sleep(0.5) -- 28
			cursor.visible = false -- 29
			return sleep(0.5) -- 30
		end) -- 26
	end -- 26
	cursor.y = label.y -- 32
	cursor.visible = false -- 33
	local updateText -- 35
	updateText = function(text) -- 35
		label.text = text -- 36
		local offsetX = math.max(label.width + 3 - width, 0) -- 37
		label.x = -offsetX -- 38
		cursor.x = label.width - offsetX - 10 -- 39
		return cursor:schedule(blink()) -- 40
	end -- 35
	local node -- 42
	do -- 42
		local _with_0 = ClipNode(SolidRect({ -- 42
			width = width, -- 42
			height = height -- 42
		})) -- 42
		local textEditing = "" -- 43
		local textDisplay = "" -- 44
		_with_0.size = Size(width, height) -- 46
		_with_0.position = Vec2(width, height) / 2 -- 47
		_with_0.hint = hint -- 48
		_with_0:addChild(label) -- 49
		_with_0:addChild(cursor) -- 50
		local updateIMEPos -- 52
		updateIMEPos = function(next) -- 52
			return _with_0:convertToWindowSpace(Vec2(-label.x + label.width, 0), function(pos) -- 53
				Keyboard:updateIMEPosHint(pos) -- 54
				if next then -- 55
					return next() -- 55
				end -- 55
			end) -- 53
		end -- 52
		local startEditing -- 56
		startEditing = function() -- 56
			return updateIMEPos(function() -- 57
				_with_0:detachIME() -- 58
				_with_0:attachIME() -- 59
				return updateIMEPos() -- 60
			end) -- 57
		end -- 56
		_with_0.updateDisplayText = function(_self, text) -- 61
			textDisplay = text -- 62
			label.text = text -- 63
		end -- 61
		_with_0:onAttachIME(function() -- 65
			_with_0.keyboardEnabled = true -- 66
			return updateText(textDisplay) -- 67
		end) -- 65
		_with_0:onDetachIME(function() -- 69
			_with_0.keyboardEnabled = false -- 70
			cursor.visible = false -- 71
			cursor:unschedule() -- 72
			textEditing = "" -- 73
			label.x = 0 -- 74
			if textDisplay == "" then -- 75
				label.text = _with_0.hint -- 75
			end -- 75
		end) -- 69
		_with_0:onTapped(function(touch) -- 77
			if touch.first then -- 77
				return startEditing() -- 77
			end -- 77
		end) -- 77
		_with_0:onKeyPressed(function(key) -- 79
			if App.platform == "Android" and utf8.len(textEditing) == 1 then -- 80
				if key == "BackSpace" then -- 81
					textEditing = "" -- 81
				end -- 81
			else -- 83
				if textEditing ~= "" then -- 83
					return -- 83
				end -- 83
			end -- 80
			if "BackSpace" == key then -- 85
				if #textDisplay > 0 then -- 86
					textDisplay = utf8.sub(textDisplay, 1, -2) -- 87
					return updateText(textDisplay) -- 88
				end -- 86
			elseif "Return" == key then -- 89
				return _with_0:detachIME() -- 90
			end -- 84
		end) -- 79
		_with_0:onTextInput(function(text) -- 92
			textDisplay = utf8.sub(textDisplay, 1, -1 - utf8.len(textEditing)) .. text -- 93
			textEditing = "" -- 94
			updateText(textDisplay) -- 95
			return updateIMEPos() -- 96
		end) -- 92
		_with_0:onTextEditing(function(text, start) -- 98
			textDisplay = utf8.sub(textDisplay, 1, -1 - utf8.len(textEditing)) .. text -- 99
			textEditing = text -- 100
			label.text = textDisplay -- 101
			local offsetX = math.max(label.width + 3 - width, 0) -- 102
			label.x = -offsetX -- 103
			local charSprite = label:getCharacter(utf8.len(textDisplay) - utf8.len(textEditing) + start) -- 104
			if charSprite then -- 105
				cursor.x = charSprite.x + charSprite.width / 2 - offsetX + 1 -- 106
				cursor:schedule(blink()) -- 107
			else -- 109
				updateText(textDisplay) -- 109
			end -- 105
			return updateIMEPos() -- 110
		end) -- 98
		node = _with_0 -- 42
	end -- 42
	local _with_0 = Node() -- 112
	_with_0.content = node -- 113
	_with_0.cursor = cursor -- 114
	_with_0.label = label -- 115
	_with_0.size = Size(width, height) -- 116
	_with_0:addChild(node) -- 117
	return _with_0 -- 112
end), { -- 119
	text = property((function(self) -- 119
		return self.label.text -- 119
	end), function(self, value) -- 120
		self.content:detachIME() -- 121
		return self.content:updateDisplayText(value) -- 122
	end) -- 119
}) -- 8
local _with_0 = TextInput({ -- 126
	hint = "点这里进行输入", -- 126
	width = 300, -- 127
	height = 60, -- 128
	fontName = "sarasa-mono-sc-regular", -- 129
	fontSize = 40 -- 130
}) -- 125
local themeColor = App.themeColor:toARGB() -- 132
_with_0.label.color = Color(0xffff0080) -- 135
_with_0:addChild(LineRect({ -- 137
	x = -2, -- 137
	width = _with_0.width + 4, -- 138
	height = _with_0.height, -- 139
	color = themeColor -- 140
})) -- 136
return _with_0 -- 125
