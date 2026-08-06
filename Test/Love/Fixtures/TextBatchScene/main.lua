local staticText
local dynamicText
local smallText
local font18
local font24
local font32
local frames = 0
local screenshotRequested = false
local screenshotVerified = false
local gapWidth = 0

local function countDominant(data, x0, y0, x1, y1, channel)
	local count = 0
	for y = y0, y1 do
		for x = x0, x1 do
			local red, green, blue, alpha = data:getPixel(x, y)
			local values = {red, green, blue}
			local selected = values[channel]
			local otherA = values[channel % 3 + 1]
			local otherB = values[(channel + 1) % 3 + 1]
			if alpha > 0.5 and selected > 0.35 and selected > otherA + 0.12 and selected > otherB + 0.12 then
				count = count + 1
			end
		end
	end
	return count
end

local function countBright(data, x0, y0, x1, y1)
	local count = 0
	for y = y0, y1 do
		for x = x0, x1 do
			local red, green, blue = data:getPixel(x, y)
			if red + green + blue > 1.45 then
				count = count + 1
			end
		end
	end
	return count
end

function love.load()
	love.filesystem.setIdentity("dora-love-text-batch")
	font18 = love.graphics.newFont(18)
	font24 = love.graphics.newFont(24)
	font32 = love.graphics.newFont(32)

	staticText = love.graphics.newText(font24, {
		{1, 0.18, 0.16, 1}, "RED ",
		{0.18, 1, 0.28, 1}, "GREEN ",
		{0.18, 0.45, 1, 1}, "BLUE",
	})
	local firstWidth, firstHeight = staticText:getDimensions()
	assert(firstWidth > 150 and firstHeight == font24:getHeight())
	assert(staticText:add("APPENDED ENTRY", 0, 55) == 2)
	local transform = love.math.newTransform(0, 100)
	assert(staticText:addf("JUSTIFY GAP", 300, "justify", transform) == 3)
	assert(staticText:getFont() == font24 and staticText:getWidth(1) == firstWidth)
	gapWidth = font24:getWidth("GAP")

	dynamicText = love.graphics.newText(font18, "atlas seed abc 123")
	smallText = love.graphics.newText(font18)
	assert(smallText:addf("CENTER\nMULTI FONT", 180, "center", 0, 0) == 1)

	local scratch = love.graphics.newText(font18, "temporary")
	scratch:add("discarded", 10, 10)
	scratch:clear()
	assert(scratch:getWidth() == 0 and scratch:getHeight() == 0)
	print("LOVE_TEXT_STATE_PASS", firstWidth, firstHeight,
		staticText:getWidth(2), staticText:getWidth(3), gapWidth)
	print("LOVE_TEXT_SAVE_ROOT", love.filesystem.getSaveDirectory())
end

function love.update()
	frames = frames + 1
	if frames == 6 then
		dynamicText:setFont(font32)
		dynamicText:set({{1, 0.72, 0.18, 1}, "UPDATED ", {0.25, 0.9, 1, 1}, "GLYPHS Ω中"})
		local width, height = dynamicText:getDimensions()
		assert(dynamicText:getFont() == font32 and width > 200 and height == font32:getHeight())
		print("LOVE_TEXT_UPDATE_PASS", width, height)
	end
	if frames > 240 and not screenshotVerified then
		error("Text screenshot callback did not complete")
	end
	if frames >= 90 and screenshotVerified then
		staticText:clear()
		dynamicText:clear()
		smallText:clear()
		assert(love.event.quit())
	end
end

function love.draw()
	love.graphics.clear(0.02, 0.025, 0.04, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(staticText, 30, 25)
	love.graphics.draw(smallText, 380, 30)
	love.graphics.draw(dynamicText, 30, 235)
	love.graphics.setColor(0.3, 0.8, 1, 1)
	love.graphics.rectangle("line", 20, 15, 340, 180)
	love.graphics.rectangle("line", 20, 225, 550, 60)
	if frames >= 15 and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("text-batch.png")
		love.graphics.captureScreenshot(function(data)
			local redWidth = font24:getWidth("RED ")
			local greenWidth = font24:getWidth("GREEN ")
			local redPixels = countDominant(data, 28, 22, math.floor(32 + redWidth), 55, 1)
			local greenPixels = countDominant(data, math.floor(28 + redWidth), 22,
				math.floor(34 + redWidth + greenWidth), 55, 2)
			local bluePixels = countDominant(data, math.floor(28 + redWidth + greenWidth), 22, 350, 55, 3)
			local justifyPixels = countBright(data, math.floor(325 - gapWidth), 118, 335, 158)
			local updatedPixels = countBright(data, 28, 230, 565, 280)
			print("LOVE_TEXT_PIXEL_VALUES", redPixels, greenPixels, bluePixels,
				justifyPixels, updatedPixels)
			assert(redPixels > 8 and greenPixels > 8 and bluePixels > 8)
			assert(justifyPixels > 8 and updatedPixels > 30)
			screenshotVerified = true
			print("LOVE_TEXT_PIXEL_PASS", redPixels, greenPixels, bluePixels,
				justifyPixels, updatedPixels)
		end)
	end
end

function love.quit()
	print("LOVE_TEXT_QUIT_PASS", staticText:getWidth(), dynamicText:getWidth(), smallText:getWidth())
	return false
end
