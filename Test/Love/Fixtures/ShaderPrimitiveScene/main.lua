local canvas
local shader
local mrtRed
local mrtGreen
local mrtShader
local frame = 0

local function isTint(r, g, b, a)
	return math.abs(r - 0.25) < 0.02 and math.abs(g - 0.5) < 0.02
		and math.abs(b - 1) < 0.02 and a > 0.98
end

local function assertTint(image, x, y, label)
	local r, g, b, a = image:getPixel(x, y)
	assert(isTint(r, g, b, a), label .. ": " .. r .. "," .. g .. "," .. b .. "," .. a)
end

local function assertBlack(image, x, y, label)
	local r, g, b, a = image:getPixel(x, y)
	assert(r < 0.02 and g < 0.02 and b < 0.02 and a > 0.98,
		label .. ": " .. r .. "," .. g .. "," .. b .. "," .. a)
end

function love.load()
	canvas = love.graphics.newCanvas(96, 64)
	mrtRed = love.graphics.newCanvas(8, 8)
	mrtGreen = love.graphics.newCanvas(8, 8)
	shader = love.graphics.newShader([[
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(texture, uv) * color * vec4(0.25, 0.5, 1.0, 1.0);
		}
	]])
	mrtShader = love.graphics.newShader([[
		void effect() {
			love_Canvases[0] = vec4(1, 0, 0, 1);
			love_Canvases[1] = vec4(0, 1, 0, 1);
		}
	]])
end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(2)
	love.graphics.setPointSize(5)
	love.graphics.setMeshCullMode("back")
	love.graphics.setShader(shader)

	love.graphics.rectangle("fill", 4, 4, 12, 10)
	love.graphics.circle("fill", 28, 9, 5)
	love.graphics.ellipse("fill", 44, 9, 7, 4, 24)
	love.graphics.polygon("fill", 56, 4, 68, 4, 62, 14)

	love.graphics.rectangle("line", 4, 22, 12, 10)
	love.graphics.circle("line", 28, 27, 5)
	love.graphics.ellipse("line", 44, 27, 7, 4, 24)
	love.graphics.polygon("line", 56, 22, 68, 22, 62, 32)
	love.graphics.line(4, 42, 16, 54)
	love.graphics.points(28, 48)

	love.graphics.push()
	love.graphics.translate(40, 42)
	love.graphics.scale(2, 1)
	love.graphics.rectangle("fill", 0, 0, 6, 8)
	love.graphics.pop()

	love.graphics.setShader()
	love.graphics.setMeshCullMode("none")
	love.graphics.setCanvas({mrtRed, mrtGreen})
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(mrtShader)
	love.graphics.rectangle("fill", 0, 0, 8, 8)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local image = canvas:newImageData()
	assertTint(image, 8, 8, "Shader fill rectangle")
	assertTint(image, 28, 9, "Shader fill circle")
	assertTint(image, 44, 9, "Shader fill ellipse")
	assertTint(image, 62, 8, "Shader fill polygon")
	assertTint(image, 4, 27, "Shader line rectangle")
	assertTint(image, 28, 22, "Shader line circle")
	assertTint(image, 44, 23, "Shader line ellipse")
	assertTint(image, 62, 22, "Shader line polygon")
	assertTint(image, 10, 48, "Shader polyline")
	assertTint(image, 28, 48, "Shader points")
	assertTint(image, 46, 46, "transformed Shader primitive")
	assertBlack(image, 10, 27, "line rectangle interior was filled")
	assertBlack(image, 28, 27, "line circle interior was filled")
	assertBlack(image, 44, 27, "line ellipse interior was filled")

	local pointPixels = 0
	for y = 44, 52 do
		for x = 24, 32 do
			local r, g, b, a = image:getPixel(x, y)
			if isTint(r, g, b, a) then pointPixels = pointPixels + 1 end
		end
	end
	assert(pointPixels == 25, "Shader pointSize=5 covered " .. pointPixels .. " pixels instead of 25")
	local red = mrtRed:newImageData()
	local green = mrtGreen:newImageData()
	local rr, rg, rb, ra = red:getPixel(4, 4)
	local gr, gg, gb, ga = green:getPixel(4, 4)
	assert(rr > 0.98 and rg < 0.02 and rb < 0.02 and ra > 0.98,
		"Shader primitive MRT attachment 0 failed")
	assert(gr < 0.02 and gg > 0.98 and gb < 0.02 and ga > 0.98,
		"Shader primitive MRT attachment 1 failed")
	print("LOVE_SHADER_PRIMITIVE_PASS", image:getDimensions(), pointPixels)
	love.event.quit()
end
