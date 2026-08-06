local canvas
local textureCanvas
local ownMesh
local attachedMesh
local pointMesh
local sourceMesh
local pointSource
local instancedMesh
local instanceSource
local vertexIDMesh
local largeMesh
local ownShader
local attachedShader
local instancedShader
local vertexIDShader
local imageVertexIDShader
local largeVertexIDShader
local mismatchShader
local unusedShader
local frame = 0

local function assertColor(image, x, y, expected, label)
	local r, g, b, a = image:getPixel(x, y)
	assert(math.abs(r - expected[1]) < 0.02 and math.abs(g - expected[2]) < 0.02
		and math.abs(b - expected[3]) < 0.02 and a > 0.98,
		label .. ": " .. r .. "," .. g .. "," .. b .. "," .. a)
end

function love.load()
	canvas = love.graphics.newCanvas(80, 64)
	textureCanvas = love.graphics.newCanvas(2, 2)
	ownMesh = love.graphics.newMesh({
		{"VertexPosition", "float", 2},
		{"VertexTexCoord", "float", 2},
		{"CustomOffset", "float", 2},
		{"CustomScale", "unorm16", 2},
		{"CustomBias", "byte", 4},
	}, {
		{2, 2, 0.5, 0.5, 8, 0, 1, 1, 0.25, 0, 0, 1},
		{14, 2, 0.5, 0.5, 8, 0, 1, 1, 0.25, 0, 0, 1},
		{2, 14, 0.5, 0.5, 8, 0, 1, 1, 0.25, 0, 0, 1},
	}, "triangles")
	ownMesh:setTexture(textureCanvas)

	attachedMesh = love.graphics.newMesh({{36, 2}, {48, 2}, {36, 14}}, "triangles")
	sourceMesh = love.graphics.newMesh({
		{"Shift", "float", 2}, {"Bias", "float", 2},
	}, {
		{0, 12, 4, 0}, {0, 12, 40, 40}, {0, 12, 80, 80},
	}, "triangles")
	attachedMesh:attachAttribute("Shift", sourceMesh, "pervertex", "Shift")
	attachedMesh:attachAttribute("Bias", sourceMesh, "perinstance", "Bias")

	pointMesh = love.graphics.newMesh({{60, 8}}, "points")
	pointSource = love.graphics.newMesh({
		{"Shift", "float", 2}, {"Bias", "float", 2},
	}, {{0, 20, 4, 0}}, "points")
	pointMesh:attachAttribute("Shift", pointSource, "perinstance", "Shift")
	pointMesh:attachAttribute("Bias", pointSource, "perinstance", "Bias")

	instancedMesh = love.graphics.newMesh({{2, 48}, {12, 48}, {2, 58}}, "triangles")
	instanceSource = love.graphics.newMesh({
		{"Offset", "float", 2}, {"InstanceColor", "float", 4},
	}, {
		{0, 0, 1, 0, 0, 1}, {10, 0, 0, 1, 0, 1}, {20, 0, 0, 0, 1, 1},
	}, "points")
	instancedMesh:attachAttribute("Offset", instanceSource, "perinstance", "Offset")
	instancedMesh:attachAttribute("VertexColor", instanceSource, "perinstance", "InstanceColor")
	vertexIDMesh = love.graphics.newMesh({{62, 48}, {62, 48}, {62, 48}}, "triangles")
	largeMesh = love.graphics.newMesh(65538, "triangles")
	largeMesh:setVertex(65536, 18, 34, 0, 0, 0, 1, 0, 1)
	largeMesh:setVertex(65537, 26, 34, 0, 0, 0, 1, 0, 1)
	largeMesh:setVertex(65538, 18, 42, 0, 0, 0, 1, 0, 1)
	largeMesh:setVertexMap(65536, 65537, 65538)

	ownShader = love.graphics.newShader([[
		attribute vec2 CustomOffset;
		attribute vec2 CustomScale;
		attribute vec4 CustomBias;
		varying vec4 OwnShade;
		vec4 position(mat4 transform, vec4 vertex) {
			OwnShade = vec4(CustomScale.x, 0.0, 0.0, 1.0);
			vertex.xy += CustomOffset * CustomScale + CustomBias.xy * 4.0;
			return transform * vertex;
		}
	]], [[
		varying vec4 OwnShade;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(texture, uv) * color * OwnShade;
		}
	]])
	attachedShader = love.graphics.newShader([[
		attribute vec2 Shift;
		attribute vec2 Bias;
		varying float ShadeScalar;
		varying vec2 ShadePair;
		varying vec3 ShadeTriple;
		varying highp vec4 ShadeQuad;
		vec4 position(mat4 transform, vec4 vertex) {
			ShadeScalar = Bias.x / 4.0;
			ShadePair = Shift / 24.0;
			ShadeTriple = vec3(0.25, 0.5, 1.0);
			ShadeQuad = vec4(0.25, 0.5, 1.0, 1.0);
			vertex.xy += Shift + Bias;
			return transform * vertex;
		}
	]], [[
		varying float ShadeScalar;
		varying vec2 ShadePair;
		varying vec3 ShadeTriple;
		varying highp vec4 ShadeQuad;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(texture, uv) * color * ShadeQuad
				* vec4(ShadeTriple.x / 0.25, ShadePair.y / 0.5, ShadeScalar, 1.0);
		}
	]])
	instancedShader = love.graphics.newShader([[
	#pragma language glsl3
		layout(location = 4) in highp vec2 Offset;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.xy += Offset + vec2(float(love_InstanceID) * 10.0, 0.0);
			return transform * vertex;
		}
	]])
	vertexIDShader = love.graphics.newShader([[
	#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			if (love_VertexID == 1) vertex.x += 12.0;
			if (love_VertexID == 2) vertex.y += 12.0;
			return transform * vertex;
		}
	]])
	imageVertexIDShader = love.graphics.newShader([[
	#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			if (love_VertexID == 1) vertex.x += 12.0;
			if (love_VertexID == 2) vertex.xy += vec2(12.0, 12.0);
			if (love_VertexID == 3) vertex.y += 12.0;
			return transform * vertex;
		}
	]])
	largeVertexIDShader = love.graphics.newShader([[
	#pragma language glsl3
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += float(love_VertexID) * 0.0;
			return transform * vertex;
		}
	]])
	mismatchShader = love.graphics.newShader([[
		attribute vec3 Shift;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.xyz += Shift * 0.0;
			return transform * vertex;
		}
	]])
	unusedShader = love.graphics.newShader([[
		attribute vec4 NotUsed;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]])
	local wideDeclarations = {}
	local wideUses = {}
	for index = 1, 11 do
		wideDeclarations[index] = "attribute float Wide" .. index .. ";"
		wideUses[index] = "vertex.x += Wide" .. index .. " * 0.0;"
	end
	local wideShader = love.graphics.newShader(table.concat(wideDeclarations, "\n")
		.. "\nvec4 position(mat4 transform, vec4 vertex) {\n"
		.. table.concat(wideUses, "\n") .. "\nreturn transform * vertex;\n}")
	assert(wideShader, "ordinary Shader should survive an unavailable instanced variant")

	local valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(location = 4) in vec2 First;
		layout(location = 4) in vec2 Second;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.xy += First + Second;
			return transform * vertex;
		}
	]])
	assert(not valid and message:find("same active layout location", 1, true),
		"duplicate active attribute locations need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(location = 3) in vec2 BuiltinConflict;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.xy += BuiltinConflict;
			return transform * vertex;
		}
	]])
	assert(not valid and message:find("between 4 and 15", 1, true),
		"built-in attribute location conflicts need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(location = 15) in float LastPortableLocation;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += LastPortableLocation * 0.0;
			return transform * vertex;
		}
	]])
	assert(valid and message == nil, "last portable attribute location should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(location = 16) in float OutsidePortableRange;
		vec4 position(mat4 transform, vec4 vertex) {
			vertex.x += OutsidePortableRange * 0.0;
			return transform * vertex;
		}
	]])
	assert(not valid and message:find("between 4 and 15", 1, true),
		"attribute locations outside the portable range need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(binding = 1) uniform Image OtherTexture;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return Texel(OtherTexture, uv) * color;
		}
	]])
	assert(not valid and message:find("only for GLSL3 vertex attributes", 1, true),
		"non-attribute layout qualifiers need a directed diagnostic")
	valid, message = love.graphics.validateShader(false, [[
	#pragma language glsl3
		layout(location = 4) in vec2 NotUsed;
		vec4 position(mat4 transform, vec4 vertex) { return transform * vertex; }
	]])
	assert(valid and message == nil, "unused explicit-location attribute should compile: " .. tostring(message))

	valid, message = love.graphics.validateShader(false, [[
		varying vec2 PixelOnly;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return vec4(PixelOnly, 0.0, 1.0); }
	]])
	assert(not valid and message:find("no matching vertex Shader output", 1, true))
	valid, message = love.graphics.validateShader(false, [[
		varying vec2 Shared;
		vec4 position(mat4 transform, vec4 vertex) { Shared = vec2(1.0); return transform * vertex; }
	]], [[
		varying vec3 Shared;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { return vec4(Shared, 1.0); }
	]])
	assert(not valid and message:find("mismatched vertex/pixel types", 1, true))
	valid, message = love.graphics.validateShader(false, [[
		varying vec2 Duplicate;
		varying vec2 Duplicate;
		vec4 position(mat4 transform, vec4 vertex) { Duplicate = vec2(1.0); return transform * vertex; }
	]])
	assert(not valid and message:find("duplicate Love vertex Shader varying", 1, true))
	valid, message = love.graphics.validateShader(false, [[
		varying float SameName;
		attribute float SameName;
		vec4 position(mat4 transform, vec4 vertex) { SameName = 1.0; return transform * vertex; }
	]])
	assert(not valid and message:find("both an attribute and a varying", 1, true))
	local manyVertex, manyPixel = {}, {}
	for index = 1, 11 do
		manyVertex[#manyVertex + 1] = "varying float V" .. index .. ";"
		manyPixel[#manyPixel + 1] = "varying float V" .. index .. ";"
	end
	manyVertex[#manyVertex + 1] = "vec4 position(mat4 t, vec4 v) {"
	for index = 1, 11 do manyVertex[#manyVertex + 1] = "V" .. index .. " = 1.0;" end
	manyVertex[#manyVertex + 1] = "return t * v; }"
	manyPixel[#manyPixel + 1] = "vec4 effect(vec4 c, Image t, vec2 uv, vec2 p) { return vec4(V11); }"
	valid, message = love.graphics.validateShader(false,
		table.concat(manyVertex, "\n"), table.concat(manyPixel, "\n"))
	assert(not valid and message:find("more custom varying semantic slots", 1, true))
	valid, message = love.graphics.validateShader(false, [[
		varying float CustomValue;
		vec4 position(mat4 transform, vec4 vertex) { CustomValue = 0.5; return transform * vertex; }
	]], [[
		varying float CustomValue;
		void effect() { love_PixelColor = vec4(CustomValue, 0.0, 0.0, 1.0); }
	]])
	assert(valid and message == nil, "custom effect varying should compile: " .. tostring(message))
	valid, message = love.graphics.validateShader(false, [[
		varying vec2 VertexOnly;
		vec4 position(mat4 transform, vec4 vertex) { VertexOnly = vertex.xy; return transform * vertex; }
	]])
	assert(valid and message == nil, "unused vertex-only varying should link: " .. tostring(message))
end

function love.draw()
	love.graphics.setCanvas(textureCanvas)
	love.graphics.clear(1, 0, 0, 1)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(imageVertexIDShader)
	love.graphics.draw(textureCanvas, 60, 2)
	love.graphics.rectangle("fill", 60, 34, 2, 2)

	love.graphics.setShader(ownShader)
	love.graphics.draw(ownMesh)

	love.graphics.setShader(attachedShader)
	local missing = love.graphics.newMesh({{2, 34}, {10, 34}, {2, 42}}, "triangles")
	assert(not pcall(love.graphics.draw, missing), "missing custom attributes should reject draw")
	attachedMesh:setAttributeEnabled("Shift", false)
	assert(not pcall(love.graphics.draw, attachedMesh), "disabled custom attribute should reject draw")
	attachedMesh:setAttributeEnabled("Shift", true)
	love.graphics.draw(attachedMesh)
	love.graphics.setPointSize(5)
	love.graphics.draw(pointMesh)
	love.graphics.setShader(instancedShader)
	love.graphics.drawInstanced(instancedMesh, 3)
	love.graphics.setShader(vertexIDShader)
	love.graphics.draw(vertexIDMesh)

	love.graphics.setShader(mismatchShader)
	assert(not pcall(love.graphics.draw, attachedMesh), "attribute component mismatch should reject draw")
	love.graphics.setShader(unusedShader)
	love.graphics.draw(missing)
	love.graphics.setShader()
	love.graphics.draw(largeMesh)
	love.graphics.setShader(largeVertexIDShader)
	love.graphics.draw(largeMesh, 16, 0)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local image = canvas:newImageData()
	assertColor(image, 14, 5, {1, 0, 0}, "self custom attribute through vec4 varying")
	assertColor(image, 64, 6, {1, 0, 0}, "GLSL3 love_VertexID Image quad")
	assertColor(image, 64, 38, {1, 1, 1}, "GLSL3 love_VertexID graphics primitive")
	assertColor(image, 44, 17, {0.25, 0.5, 1}, "pervertex/perinstance attached attributes")
	assertColor(image, 64, 28, {0.25, 20 / 24, 1}, "expanded point custom attributes through varyings")
	assertColor(image, 4, 36, {1, 1, 1}, "unused attribute declaration")
	assertColor(image, 20, 36, {0, 1, 0}, "32-bit Mesh default renderer path")
	assertColor(image, 36, 36, {0, 1, 0}, "32-bit Mesh Shader and love_VertexID path")
	assertColor(image, 4, 50, {1, 0, 0}, "drawInstanced first per-instance row")
	assertColor(image, 24, 50, {0, 1, 0}, "drawInstanced second per-instance row")
	assertColor(image, 44, 50, {0, 0, 1}, "drawInstanced third per-instance row")
	assertColor(image, 64, 50, {1, 1, 1}, "GLSL3 love_VertexID triangle")
	local pointPixels = 0
	for y = 24, 32 do
		for x = 60, 68 do
			local r, g, b, a = image:getPixel(x, y)
			if math.abs(r - 0.25) < 0.02 and math.abs(g - 20 / 24) < 0.02
				and math.abs(b - 1) < 0.02 and a > 0.98 then
				pointPixels = pointPixels + 1
			end
		end
	end
	assert(pointPixels == 25, "custom attribute point covered " .. pointPixels .. " pixels")
	print("LOVE_SHADER_CUSTOM_ATTRIBUTE_PASS", image:getDimensions(), pointPixels)
	love.event.quit()
end
