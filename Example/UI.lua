-- [yue]: Example/UI.yue
local _ENV = Dora -- 2
local Button = require("UI.Control.Basic.Button") -- 3
local LineRect = require("UI.View.Shape.LineRect") -- 4
local ScrollArea = require("UI.Control.Basic.ScrollArea") -- 5
local tostring <const> = tostring -- 6
local print <const> = print -- 6
local Size <const> = Size -- 6
local Vec2 <const> = Vec2 -- 6
local Director <const> = Director -- 6
local AlignNode <const> = AlignNode -- 6
local Panel -- 8
Panel = function(width, height, viewWidth, viewHeight) -- 8
	local _with_0 = ScrollArea({ -- 10
		width = width, -- 10
		height = height, -- 11
		paddingX = 50, -- 12
		paddingY = 50, -- 13
		viewWidth = viewWidth, -- 14
		viewHeight = viewHeight -- 15
	}) -- 9
	for i = 1, 50 do -- 17
		_with_0.view:addChild((function() -- 18
			local _with_1 = Button({ -- 19
				text = "点击\n按钮" .. tostring(i), -- 19
				width = 60, -- 20
				height = 60, -- 21
				fontName = "sarasa-mono-sc-regular", -- 22
				fontSize = 16 -- 23
			}) -- 18
			_with_1:onTapped(function() -- 25
				return print("clicked " .. tostring(i)) -- 25
			end) -- 25
			return _with_1 -- 18
		end)()) -- 18
	end -- 17
	_with_0.view:alignItems(Size(viewWidth, height)) -- 26
	_with_0.updateSize = function(self, w, h) -- 27
		self.position = Vec2(w / 2, h / 2) -- 28
		self:adjustSizeWithAlign("Auto", 10, Size(w, h), Size(width, h)) -- 29
		if self.border then -- 30
			self.border:removeFromParent() -- 30
		end -- 30
		self.border = LineRect({ -- 31
			x = -w / 2, -- 31
			y = -h / 2, -- 31
			width = w, -- 31
			height = h, -- 31
			color = 0xffffffff -- 31
		}) -- 31
		return _with_0:addChild(self.border) -- 32
	end -- 27
	return _with_0 -- 9
end -- 8
return Director.ui:addChild((function() -- 34
	local _with_0 = AlignNode(true) -- 34
	_with_0:css("justify-content: space-between; flex-direction: row") -- 35
	_with_0:addChild((function() -- 36
		local _with_1 = AlignNode() -- 36
		_with_1:css("width: 30%; height: 100%; padding: 10") -- 37
		_with_1:addChild((function() -- 38
			local _with_2 = AlignNode() -- 38
			_with_2:css("width: 100%; height: 100%") -- 39
			local panel = Panel(500, 1000, 1000, 1000) -- 40
			_with_2:addChild(panel) -- 41
			_with_2:onAlignLayout(function(w, h) -- 42
				return panel:updateSize(w, h) -- 42
			end) -- 42
			return _with_2 -- 38
		end)()) -- 38
		return _with_1 -- 36
	end)()) -- 36
	_with_0:addChild((function() -- 43
		local _with_1 = AlignNode() -- 43
		_with_1:css("width: 40%; height: 100%; padding: 10; justify-content: center") -- 44
		_with_1:addChild((function() -- 45
			local _with_2 = AlignNode() -- 45
			_with_2:css("width: 100%; height: 50%") -- 46
			local panel = Panel(600, 1000, 1000, 1000) -- 47
			_with_2:addChild(panel) -- 48
			_with_2:onAlignLayout(function(w, h) -- 49
				return panel:updateSize(w, h) -- 49
			end) -- 49
			return _with_2 -- 45
		end)()) -- 45
		return _with_1 -- 43
	end)()) -- 43
	_with_0:addChild((function() -- 50
		local _with_1 = AlignNode() -- 50
		_with_1:css("width: 30%; height: 100%; padding: 10; flex-direction: column-reverse") -- 51
		_with_1:addChild((function() -- 52
			local _with_2 = AlignNode() -- 52
			_with_2:css("width: 100%; height: 40%") -- 53
			local panel = Panel(600, 1000, 1000, 1000) -- 54
			_with_2:addChild(panel) -- 55
			_with_2:onAlignLayout(function(w, h) -- 56
				return panel:updateSize(w, h) -- 56
			end) -- 56
			return _with_2 -- 52
		end)()) -- 52
		return _with_1 -- 50
	end)()) -- 50
	return _with_0 -- 34
end)()) -- 34
