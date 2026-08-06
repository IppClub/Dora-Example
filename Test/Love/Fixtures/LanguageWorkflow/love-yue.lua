-- [yue]: love-yue.yue
local love = require("love") -- 1
local elapsed = 0 -- 2
love.load = function() -- 4
	elapsed = 0 -- 5
end -- 4
love.update = function(deltaTime) -- 7
	elapsed = elapsed + deltaTime -- 8
end -- 7
love.draw = function() -- 10
	love.graphics.clear(0, 0, 0, 1) -- 11
	love.graphics.setColor(1, 0.5, 0.25, 1) -- 12
	return love.graphics.rectangle("fill", 10, 20, 100, 50) -- 13
end -- 10
