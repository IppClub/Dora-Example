-- [yue]: Example/FixedLabel.yue
local _ENV = Dora -- 2
local require <const> = require -- 3
local sleep <const> = sleep -- 3
local Node <const> = Node -- 3
local LineRect = require("UI.View.Shape.LineRect") -- 4
local FixedLabel = require("UI.Control.Basic.FixedLabel") -- 5
local utf8 = require("utf-8") -- 6
local createLabel -- 8
createLabel = function(textAlign) -- 8
	local _with_0 = FixedLabel({ -- 9
		text = "", -- 9
		width = 100, -- 9
		height = 30, -- 9
		textAlign = textAlign -- 9
	}) -- 9
	_with_0:addChild(LineRect({ -- 10
		width = 100, -- 10
		height = 30, -- 10
		color = 0xffff0080 -- 10
	})) -- 10
	local text = "1.23456壹贰叁肆伍陆柒玐玖" -- 11
	local textLen = utf8.len(text) -- 12
	_with_0:once(function() -- 13
		for i = 1, textLen do -- 14
			_with_0.text = utf8.sub(text, 1, i) -- 15
			sleep(0.3) -- 16
		end -- 14
	end) -- 13
	return _with_0 -- 9
end -- 8
local _with_0 = Node() -- 18
_with_0:addChild(createLabel("Center")) -- 19
_with_0:addChild((function() -- 20
	local _with_1 = createLabel("Left") -- 20
	_with_1.y = 40 -- 21
	return _with_1 -- 20
end)()) -- 20
_with_0:addChild((function() -- 22
	local _with_1 = createLabel("Right") -- 22
	_with_1.y = -40 -- 23
	return _with_1 -- 22
end)()) -- 22
return _with_0 -- 18
