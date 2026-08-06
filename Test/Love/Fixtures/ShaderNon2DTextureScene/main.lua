local canvas
local arrayImage
local cubeImage
local volumeImage
local arrayImage2
local cubeImage2
local volumeImage2
local arrayShader
local cubeShader
local volumeShader
local arraySamplerArrayShader
local cubeSamplerArrayShader
local volumeSamplerArrayShader
local frame = 0

local function solid(red, green, blue)
	local data = love.image.newImageData(4, 4)
	data:mapPixel(function()
		return red, green, blue, 1
	end)
	return data
end

local function assertColor(image, x, y, expected, label)
	local red, green, blue, alpha = image:getPixel(x, y)
	assert(math.abs(red - expected[1]) < 0.02
		and math.abs(green - expected[2]) < 0.02
		and math.abs(blue - expected[3]) < 0.02 and alpha > 0.98,
		label .. ": " .. red .. "," .. green .. "," .. blue .. "," .. alpha)
end

function love.load()
	canvas = love.graphics.newCanvas(192, 32)
	local red = solid(1, 0, 0)
	local green = solid(0, 1, 0)
	local blue = solid(0, 0, 1)
	local yellow = solid(1, 1, 0)
	local magenta = solid(1, 0, 1)
	local cyan = solid(0, 1, 1)

	arrayImage = love.graphics.newArrayImage({red, green, blue}, {mipmaps = false})
	cubeImage = love.graphics.newCubeImage({red, green, blue, yellow, magenta, cyan})
	volumeImage = love.graphics.newVolumeImage({red, green, blue})
	arrayImage2 = love.graphics.newArrayImage({yellow, magenta, cyan}, {mipmaps = false})
	cubeImage2 = love.graphics.newCubeImage({cyan, magenta, yellow, blue, green, red})
	volumeImage2 = love.graphics.newVolumeImage({yellow, magenta, cyan})
	arrayImage:setFilter("nearest")
	cubeImage:setFilter("nearest")
	volumeImage:setFilter("nearest")
	arrayImage2:setFilter("nearest")
	cubeImage2:setFilter("nearest")
	volumeImage2:setFilter("nearest")
	volumeImage:setWrap("clamp", "clamp", "mirroredrepeat")

	assert(arrayImage:getTextureType() == "array" and arrayImage:getLayerCount() == 3)
	assert(cubeImage:getTextureType() == "cube" and cubeImage:getDepth() == 1)
	assert(volumeImage:getTextureType() == "volume" and volumeImage:getDepth() == 3)

	arrayShader = love.graphics.newShader([[
		extern ArrayImage source;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(source, vec3(uv, 1.0)) * color;
		}
	]])
	cubeShader = love.graphics.newShader([[
		extern CubeImage source;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(source, vec3(1.0, 0.0, 0.0)) * color;
		}
	]])
	volumeShader = love.graphics.newShader([[
#pragma language glsl3
		uniform VolumeImage source;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return texture(source, vec3(uv, 0.5)) * color;
		}
	]])
	arrayShader:send("source", arrayImage)
	cubeShader:send("source", cubeImage)
	volumeShader:send("source", volumeImage)

	assert(not pcall(arrayShader.send, arrayShader, "source", cubeImage))
	assert(not pcall(cubeShader.send, cubeShader, "source", canvas))
	arraySamplerArrayShader = love.graphics.newShader([[
		extern ArrayImage sources[2];
		extern int selector;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(sources[selector], vec3(uv, 2.0)) * color;
		}
	]])
	cubeSamplerArrayShader = love.graphics.newShader([[
#pragma language glsl3
		uniform CubeImage sources[2];
		uniform int selector;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return texture(sources[selector], vec3(1.0, 0.0, 0.0)) * color;
		}
	]])
	volumeSamplerArrayShader = love.graphics.newShader([[
#pragma language glsl3
		uniform VolumeImage sources[2];
		uniform int selector;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return texture(sources[selector], vec3(uv, 0.5)) * color;
		}
	]])
	for _, shader in ipairs({arraySamplerArrayShader, cubeSamplerArrayShader,
		volumeSamplerArrayShader}) do
		shader:send("selector", 1)
	end
	arraySamplerArrayShader:send("sources", arrayImage, arrayImage2)
	cubeSamplerArrayShader:send("sources", cubeImage, cubeImage2)
	volumeSamplerArrayShader:send("sources", volumeImage, volumeImage2)
	assert(not pcall(arraySamplerArrayShader.send, arraySamplerArrayShader,
		"sources", cubeImage, cubeImage2))
end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(arrayShader)
	love.graphics.rectangle("fill", 0, 0, 32, 32)
	love.graphics.setShader(cubeShader)
	love.graphics.rectangle("fill", 32, 0, 32, 32)
	love.graphics.setShader(volumeShader)
	love.graphics.rectangle("fill", 64, 0, 32, 32)
	love.graphics.setShader(arraySamplerArrayShader)
	love.graphics.rectangle("fill", 96, 0, 32, 32)
	love.graphics.setShader(cubeSamplerArrayShader)
	love.graphics.rectangle("fill", 128, 0, 32, 32)
	love.graphics.setShader(volumeSamplerArrayShader)
	love.graphics.rectangle("fill", 160, 0, 32, 32)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local image = canvas:newImageData()
	assertColor(image, 16, 16, {0, 1, 0}, "ArrayImage layer")
	assertColor(image, 48, 16, {1, 0, 0}, "CubeImage +X face")
	assertColor(image, 80, 16, {0, 1, 0}, "VolumeImage middle slice")
	assertColor(image, 112, 16, {0, 1, 1}, "ArrayImage sampler array")
	assertColor(image, 144, 16, {0, 1, 1}, "CubeImage sampler array")
	assertColor(image, 176, 16, {1, 0, 1}, "VolumeImage sampler array")
	print("LOVE_SHADER_NON2D_PASS", image:getDimensions())
	love.event.quit()
end
