local function sameLines(actual, expected)
	assert(#actual == #expected, ("line count: %d ~= %d"):format(#actual, #expected))
	for index, value in ipairs(expected) do
		assert(actual[index] == value,
			("line %d: %q ~= %q"):format(index, actual[index], value))
	end
end

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest")
	local atlas = love.image.newImageData(18, 8)
	for y = 0, 7 do
		for x = 0, 17 do atlas:setPixel(x, y, 1, 0, 1, 1) end
		for x = 1, 3 do atlas:setPixel(x, y, 1, 1, 1, 1) end
		for x = 5, 9 do atlas:setPixel(x, y, 1, 1, 1, 1) end
		for x = 11, 16 do atlas:setPixel(x, y, 1, 1, 1, 1) end
	end
	local font = love.graphics.newImageFont(atlas, "ABV", 1)
	font:setLineHeight(1.25)
	assert(font:getWidth("AB V") == 17)
	assert(font:getWidth("AB\nV") == 10)
	assert(font:getWidth("A\tB") == 10)
	local expected = {
		[0] = {0, {"", "", "  ", "", " ", "", "", "", "", " ", "", " "}},
		[4] = {4, {"A", "", "  ", "", " ", "A", "", "", "A ", "", " "}},
		[7] = {7, {"A", "B  ", "V ", "A", "B", "A ", "B "}},
		[10] = {10, {"AB  ", "V ", "AB", "A B "}},
		[14] = {10, {"AB  ", "V ", "AB", "A B "}},
		[30] = {27, {"AB  V AB", "A B "}},
	}
	for _, limit in ipairs({0, 4, 7, 10, 14, 30}) do
		local width, lines = font:getWrap("AB  V AB\nA B ", limit)
		assert(width == expected[limit][1], ("wrap %d width: %s"):format(limit, width))
		sameLines(lines, expected[limit][2])
	end

	local canvas = love.graphics.newCanvas(160, 96)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setFont(font)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("AB V", 2, 2)
	love.graphics.printf({{1, 0, 0, 1}, "AB ", {0, 1, 0, 1}, "V AB"}, 2, 20, 42, "left")
	love.graphics.printf("AB V AB", 2, 44, 42, "center")
	love.graphics.printf("A B V", 2, 68, 42, "justify")
	love.graphics.setCanvas()

	local data = canvas:newImageData()
	local hash, count = 0, 0
	local minx, miny, maxx, maxy = 160, 96, -1, -1
	for y = 0, 95 do
		for x = 0, 159 do
			local r, g, b, a = data:getPixel(x, y)
			local values = {math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
				math.floor(b * 255 + 0.5), math.floor(a * 255 + 0.5)}
			for _, value in ipairs(values) do hash = (hash * 257 + value) % 65521 end
			if values[1] ~= 0 or values[2] ~= 0 or values[3] ~= 0 then
				count = count + 1
				minx, miny, maxx, maxy = math.min(minx, x), math.min(miny, y),
					math.max(maxx, x), math.max(maxy, y)
			end
		end
	end
	assert(hash == 40478, "pixel hash differs from LÖVE 11.5: " .. hash)
	assert(count == 576, "colored pixel count differs from LÖVE 11.5: " .. count)
	assert(minx == 2 and miny == 2 and maxx == 41 and maxy == 75,
		("pixel bounds differ: %d,%d,%d,%d"):format(minx, miny, maxx, maxy))
	print("LOVE_TEXT_LAYOUT_PARITY_PASS", hash, count, minx, miny, maxx, maxy)
	love.event.quit()
end
