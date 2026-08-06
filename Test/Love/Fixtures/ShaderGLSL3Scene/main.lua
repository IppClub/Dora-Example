local canvas
local textureCanvas
local mesh
local shader
local frame = 0

local function assertColor(image, x, y, expected, label)
	local r, g, b, a = image:getPixel(x, y)
	assert(math.abs(r - expected[1]) < 0.02 and math.abs(g - expected[2]) < 0.02
		and math.abs(b - expected[3]) < 0.02 and a > 0.98,
		label .. ": " .. r .. "," .. g .. "," .. b .. "," .. a)
end

function love.load()
	canvas = love.graphics.newCanvas(64, 32)
	textureCanvas = love.graphics.newCanvas(2, 2)
	mesh = love.graphics.newMesh({
		{"VertexPosition", "float", 2},
		{"VertexTexCoord", "float", 2},
		{"Shift", "float", 2},
	}, {
		{2, 2, 0.5, 0.5, 12, 4},
		{26, 2, 0.5, 0.5, 12, 4},
		{2, 22, 0.5, 0.5, 12, 4},
	}, "triangles")
	mesh:setTexture(textureCanvas)

	shader = love.graphics.newShader([[
#pragma language glsl3
		in vec2 Shift;
		out highp vec4 Shade;
		vec4 position(mat4 transform, vec4 vertex) {
			Shade = vec4(0.25, 0.5, 1.0, 1.0);
			vertex.xy += Shift;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		in highp vec4 Shade;
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
			return texture(tex, uv) * color * Shade;
		}
	]])

	local valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		attribute vec2 Shift;
		varying vec2 Shared;
		vec4 position(mat4 transform, vec4 vertex) {
			Shared = Shift;
			return transform * vertex;
		}
	]], [[
#pragma language glsl3
		varying vec2 Shared;
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
			return Texel(tex, uv) * vec4(Shared / 12.0, 1.0, 1.0);
		}
	]])
	assert(valid and message == nil, "GLSL3 Love aliases should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += float(love_VertexID) * 0.0;
			return transform * vertex;
		}
	]])
	assert(valid and message == nil, "GLSL3 love_VertexID should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += float(love_InstanceID) * 0.0;
			return transform * vertex;
		}
	]])
	assert(valid and message == nil, "GLSL3 love_InstanceID should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl1
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) { return Texel(tex, uv) * color; }
	]])
	assert(valid and message == nil, "explicit GLSL1 pragma should compile: " .. tostring(message))

	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]], [[
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("languages must match", 1, true))

	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl4
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) { return color; }
	]])
	assert(not valid and message:find("Invalid shader language: glsl4", 1, true))

	valid, message = love.graphics.validateShader(false, [[
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) { return color; }
#pragma language glsl3
	]])
	assert(not valid and message:find("first non-whitespace line", 1, true))

	valid, message = love.graphics.validateShader(false, [[
#pragma language glsl3
		in vec2 PixelOnly;
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
			return vec4(PixelOnly, 0.0, 1.0);
		}
	]])
	assert(not valid and message:find("no matching vertex Shader output", 1, true))
end

function love.draw()
	love.graphics.setCanvas(textureCanvas)
	love.graphics.clear(1, 1, 1, 1)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(shader)
	love.graphics.draw(mesh)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local image = canvas:newImageData()
	assertColor(image, 18, 9, {0.25, 0.5, 1.0}, "GLSL3 in/out and texture")
	print("LOVE_SHADER_GLSL3_PASS", image:getDimensions())
	love.event.quit()
end
