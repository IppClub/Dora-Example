local elapsed = 0
local pig = love.graphics.newImage("pig.png")
local escaped, escape_error = pcall(love.graphics.newImage, "../RuntimeSceneSecond/boot.lua")
assert(not escaped and escape_error:find("escapes the Love instance source root"))

function love.load()
	assert(boot_instance_value ~= nil)
	local width, height = pig:getDimensions()
	assert(width == 256 and height == 256)
end

function love.update(deltaTime)
	elapsed = elapsed + deltaTime
end

function love.draw()
	assert(elapsed >= 0)
	local width, height = love.graphics.getDimensions()
	assert(width == 800 and height == 600)
	love.graphics.clear(0.05, 0.08, 0.12, 1)
	love.graphics.setColor(0.2, 0.75, 1, 1)
	love.graphics.rectangle("fill", 40, 50, 260, 120)
	love.graphics.setColor(1, 0.35, 0.2, 0.9)
	love.graphics.circle("fill", 430, 180, 72)
	love.graphics.setColor(0.9, 0.9, 0.3, 1)
	love.graphics.setLineWidth(8)
	love.graphics.line(80, 360, 260, 280, 440, 390, 650, 250)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(pig, 380, 455, 0.18, 0.42, 0.42, 128, 128)
	love.graphics.setColor(0.2, 0.9, 1, 1)
	love.graphics.rectangle("line", 320, 395, 120, 90)
	love.graphics.setColor(0.75, 0.4, 1, 1)
	love.graphics.push()
	love.graphics.translate(610, 100)
	love.graphics.rotate(0.35)
	love.graphics.rectangle("line", 0, 0, 120, 70)
	love.graphics.pop()
	love.graphics.setColor(0.3, 1, 0.55, 0.9)
	love.graphics.ellipse("line", 180, 500, 75, 35)
	love.graphics.polygon("fill", 500, 470, 570, 540, 640, 470)
end

function love.quit()
	elapsed = -1
end
