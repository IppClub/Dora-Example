-- [yue]: Example/Ruler.yue
local _ENV = Dora -- 2
local Ruler = require("UI.Control.Basic.Ruler") -- 3
local CircleButton = require("UI.Control.Basic.CircleButton") -- 4
local print <const> = print -- 5
local ruler = Ruler({ -- 8
	width = 600, -- 8
	height = 150 -- 9
}) -- 7
local _with_0 = CircleButton({ -- 13
	text = "显示", -- 13
	y = -200, -- 14
	radius = 60, -- 15
	fontSize = 40 -- 16
}) -- 12
_with_0:onTapped(function() -- 18
	if _with_0.text == "显示" then -- 19
		_with_0.text = "隐藏" -- 20
		return ruler:show(0, 0, 100, 10, function(value) -- 21
			return print(value) -- 22
		end) -- 21
	else -- 24
		_with_0.text = "显示" -- 24
		return ruler:hide() -- 25
	end -- 19
end) -- 18
return _with_0 -- 12
