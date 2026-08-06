local image
local quads = {}
local frames = 0

function love.load()
	image = love.graphics.newImage("atlas.png")
	local minFilter, magFilter, anisotropy = image:getFilter()
	assert(minFilter == "linear" and magFilter == "linear" and anisotropy == 1)
	image:setFilter("nearest")
	minFilter, magFilter, anisotropy = image:getFilter()
	assert(minFilter == "nearest" and magFilter == "nearest" and anisotropy == 1)
	assert(image:setWrap("repeat", "mirroredrepeat", "clampzero"))
	local wrapU, wrapV, wrapW = image:getWrap()
	assert(wrapU == "repeat" and wrapV == "mirroredrepeat" and wrapW == "clampzero")
	quads[1] = love.graphics.newQuad(0, 0, 64, 64, image)
	quads[2] = love.graphics.newQuad(64, 0, 64, 64, image)
	quads[3] = love.graphics.newQuad(0, 64, 64, 64, image)
	quads[4] = love.graphics.newQuad(64, 64, 64, 64, image)
	quads[5] = love.graphics.newQuad(96, 96, 96, 96, image)
	local x, y, width, height = quads[4]:getViewport()
	local textureWidth, textureHeight = quads[4]:getTextureDimensions()
	assert(x == 64 and y == 64 and width == 64 and height == 64)
	assert(textureWidth == 128 and textureHeight == 128)
	print("LOVE_QUAD_METRICS_PASS", x, y, width, height, textureWidth, textureHeight)
	print("LOVE_TEXTURE_SAMPLER_STATE_PASS", minFilter, magFilter, anisotropy, wrapU, wrapV, wrapW)
end

function love.update()
	frames = frames + 1
	if frames == 60 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_TEXTURE_SAMPLER_QUIT_PASS")
	return false
end

function love.draw()
	love.graphics.clear(0.025, 0.025, 0.035, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, quads[1], 30, 30, 0, 1.25, 1.25)
	love.graphics.draw(image, quads[2], 130, 30, 0, 1.25, 1.25)
	love.graphics.draw(image, quads[3], 230, 30, 0, 1.25, 1.25)
	love.graphics.draw(image, quads[4], 330, 30, 0, 1.25, 1.25)
	love.graphics.draw(image, quads[5], 30, 140, 0, 1.25, 1.25)
	image:setFilter("linear")
	love.graphics.draw(image, quads[5], 180, 140, 0, 1.25, 1.25)
	image:setFilter("nearest")
	love.graphics.setColor(1, 1, 1, 0.75)
	for index = 0, 3 do
		love.graphics.rectangle("line", 30 + index * 100, 30, 80, 80)
	end
	love.graphics.setColor(0.25, 0.75, 1, 1)
	love.graphics.rectangle("line", 16, 16, 388, 110)
	love.graphics.rectangle("line", 16, 126, 300, 128)
end
