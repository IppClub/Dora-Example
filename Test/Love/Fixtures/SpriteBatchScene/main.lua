local image
local batch
local arrayBatch
local arrayShader
local attributeBatch
local attributeShader
local frames = 0
local screenshotRequested = false
local screenshotVerified = false

function love.load()
	love.filesystem.setIdentity("dora-love-spritebatch")
	image = love.graphics.newImage("atlas.png")
	image:setFilter("nearest")
	local red = love.graphics.newQuad(0, 0, 64, 64, image)
	local green = love.graphics.newQuad(64, 0, 64, 64, image)
	local blue = love.graphics.newQuad(0, 64, 64, 64, image)
	local yellow = love.graphics.newQuad(64, 64, 64, 64, image)
	batch = love.graphics.newSpriteBatch(image, 2, "dynamic")
	batch:setColor(1, 1, 1, 1)
	assert(batch:add(red, 24, 24) == 1)
	assert(batch:add(green, 104, 24) == 2)
	assert(batch:add(blue, 184, 24) == 3)
	batch:setColor({1, 1, 1, 0.5})
	assert(batch:add(yellow, 264, 24) == 4)
	assert(batch:getCount() == 4 and batch:getBufferSize() == 4)
	batch:set(2, green, 104, 104, 0.15, 1.15, 0.8, 32, 32)
	batch:setColor()
	batch:setDrawRange(1, 4)
	batch:flush()
	local redLayer = love.image.newImageData(16, 16)
	local cyanLayer = love.image.newImageData(16, 16)
	redLayer:mapPixel(function() return 1, 0, 0, 1 end)
	cyanLayer:mapPixel(function() return 0, 1, 1, 1 end)
	local arrayImage = love.graphics.newArrayImage({redLayer, cyanLayer}, {mipmaps = false})
	arrayImage:setFilter("nearest")
	local layerQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
	layerQuad:setLayer(2)
	arrayBatch = love.graphics.newSpriteBatch(arrayImage, 2, "dynamic")
	assert(arrayBatch:add(layerQuad, 24, 200) == 1)
	assert(arrayBatch:addLayer(1, 64, 200) == 2)
	arrayBatch:setLayer(2, 2, 64, 200)
	assert(arrayBatch:addLayer(1, layerQuad, 104, 200) == 3)
	assert(arrayBatch:getCount() == 3 and arrayBatch:getBufferSize() == 4)
	assert(not pcall(arrayBatch.addLayer, arrayBatch, 0, 0, 0))
	assert(not pcall(arrayBatch.addLayer, arrayBatch, 3, 0, 0))
	assert(not pcall(batch.addLayer, batch, 1, 0, 0))
	assert(not pcall(arrayBatch.setTexture, arrayBatch, image))
	arrayShader = love.graphics.newShader([[
		extern ArrayImage MainTex;
		void effect() {
			love_PixelColor = Texel(MainTex, VaryingTexCoord.xyz)
				* VaryingColor * vec4(0.5, 1.0, 1.0, 1.0);
		}
	]])
	attributeBatch = love.graphics.newSpriteBatch(image, 1, "dynamic")
	assert(attributeBatch:add(red, 0, 0) == 1)
	local attributeMesh = love.graphics.newMesh({
		{"VertexPosition", "float", 2},
		{"VertexColor", "float", 4},
		{"Offset", "float", 2},
	}, {
		{0, 0, 0.5, 0, 0, 1, 12, 0},
		{24, 0, 0.5, 0, 0, 1, 12, 0},
		{24, 24, 0.5, 0, 0, 1, 12, 0},
		{0, 24, 0.5, 0, 0, 1, 12, 0},
	}, "points")
	attributeBatch:attachAttribute("VertexPosition", attributeMesh)
	attributeBatch:attachAttribute("VertexColor", attributeMesh)
	attributeBatch:attachAttribute("Offset", attributeMesh)
	assert(not pcall(attributeBatch.attachAttribute, attributeBatch, "Missing", attributeMesh))
	attributeMesh = nil
	collectgarbage("collect")
	attributeShader = love.graphics.newShader([[
		attribute vec2 Offset;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.xy += Offset;
			return transform * vertex;
		}
	]], [[
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(texture, uv) * color;
		}
	]])
	local rangeStart, rangeCount = batch:getDrawRange()
	assert(rangeStart == 1 and rangeCount == 4 and batch:getTexture() == image)
	print("LOVE_SPRITEBATCH_STATE_PASS", batch:getCount(), batch:getBufferSize(), rangeStart, rangeCount)
	print("LOVE_SPRITEBATCH_SAVE_ROOT", love.filesystem.getSaveDirectory())
end

function love.update()
	frames = frames + 1
	if frames > 240 and not screenshotVerified then
		error("SpriteBatch screenshot callback did not complete")
	end
	if frames >= 90 and screenshotVerified then
		batch:clear()
		assert(batch:getCount() == 0)
		assert(love.event.quit())
	end
end

function love.draw()
	love.graphics.clear(0.02, 0.025, 0.04, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(batch, 12, 12)
	love.graphics.draw(arrayBatch, 12, 12)
	love.graphics.setShader(arrayShader)
	love.graphics.draw(arrayBatch, 12, 52)
	love.graphics.setShader(attributeShader)
	love.graphics.draw(attributeBatch, 180, 300)
	love.graphics.setShader()
	love.graphics.setColor(0.3, 0.8, 1, 1)
	love.graphics.rectangle("line", 20, 20, 330, 165)
	if frames >= 10 and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("spritebatch.png")
		love.graphics.captureScreenshot(function(data)
			local redR, redG, redB = data:getPixel(50, 50)
			local greenR, greenG, greenB = data:getPixel(116, 116)
			local blueR, blueG, blueB = data:getPixel(220, 60)
			local yellowR, yellowG, yellowB = data:getPixel(300, 60)
			local arrayCyan1R, arrayCyan1G, arrayCyan1B = data:getPixel(44, 220)
			local arrayCyan2R, arrayCyan2G, arrayCyan2B = data:getPixel(84, 220)
			local arrayRedR, arrayRedG, arrayRedB = data:getPixel(124, 220)
			local shaderRedR, shaderRedG, shaderRedB = data:getPixel(124, 260)
			local attachedR, attachedG, attachedB = data:getPixel(204, 312)
			print("LOVE_SPRITEBATCH_PIXEL_VALUES", redR, redG, redB,
				greenR, greenG, greenB, blueR, blueG, blueB, yellowR, yellowG, yellowB)
			print("LOVE_SPRITEBATCH_ATTRIBUTE_VALUES", attachedR, attachedG, attachedB)
			assert(redR > 0.8 and redG < 0.25 and redB < 0.3)
			assert(greenR < 0.25 and greenG > 0.35 and greenB < 0.3)
			assert(blueR < 0.25 and blueG < 0.6 and blueB > 0.65)
			assert(yellowR > 0.4 and yellowG > 0.35 and yellowB < 0.35)
			assert(arrayCyan1R < 0.1 and arrayCyan1G > 0.9 and arrayCyan1B > 0.9)
			assert(arrayCyan2R < 0.1 and arrayCyan2G > 0.9 and arrayCyan2B > 0.9)
			assert(arrayRedR > 0.9 and arrayRedG < 0.1 and arrayRedB < 0.1)
			assert(shaderRedR > 0.45 and shaderRedR < 0.55
				and shaderRedG < 0.1 and shaderRedB < 0.1)
			assert(attachedR > 0.45 and attachedR < 0.55
				and attachedG < 0.1 and attachedB < 0.1,
				("attached pixel %.4f %.4f %.4f"):format(attachedR, attachedG, attachedB))
			screenshotVerified = true
			print("LOVE_SPRITEBATCH_PIXEL_PASS", redR, greenG, blueB, yellowR, yellowG)
			print("LOVE_SPRITEBATCH_ARRAY_PASS", arrayCyan1G, arrayCyan2B, arrayRedR, shaderRedR)
			print("LOVE_SPRITEBATCH_ATTRIBUTE_PASS", attachedR, attachedG, attachedB)
		end)
	end
end

function love.quit()
	print("LOVE_SPRITEBATCH_QUIT_PASS", batch:getCount())
	return false
end
