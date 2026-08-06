local canvas
local frame = 0
local screenshotRequested = false
local screenshotVerified = false
local canvasVerified = false
local expect

local position3 = {
	{"VertexPosition", "float", 3},
	{"VertexColor", "byte", 4},
}

local function triangle(x, y, z, r, g, b, reversed)
	local vertices = {
		{x, y, z, r, g, b, 1},
		{x + 24, y, z, r, g, b, 1},
		{x, y + 24, z, r, g, b, 1},
	}
	if reversed then
		vertices[2], vertices[3] = vertices[3], vertices[2]
	end
	return love.graphics.newMesh(position3, vertices, "triangles", "dynamic")
end

local front
local back
local near
local far
local mapped
local textureCanvas
local maskCanvas
local textured
local tintShader

function love.load()
	canvas = love.graphics.newCanvas(96, 64)
	local packedFront = string.pack("=fffBBBBfffBBBBfffBBBB",
		4, 4, 0, 0, 255, 0, 255,
		28, 4, 0, 0, 255, 0, 255,
		4, 28, 0, 0, 255, 0, 255)
	front = love.graphics.newMesh(position3,
		love.filesystem.newFileData(packedFront, "front-mesh.bin"), "triangles", "static")
	local fx, fy, fz, fr, fg = front:getVertex(1)
	assert(fx == 4 and fy == 4 and fz == 0 and fr == 0 and fg == 1)
	front:setVertices(love.filesystem.newFileData(
		string.pack("=fffBBBB", 4, 4, 0, 0, 255, 0, 255), "front-patch.bin"), 1, 1)
	local frontSource = triangle(4, 4, 0, 0, 1, 0, false)
	front:attachAttribute("VertexPosition", frontSource, "pervertex", "VertexPosition")
	front:attachAttribute("VertexColor", frontSource, "perinstance", "VertexColor")
	assert(front:isAttributeEnabled("VertexPosition"))
	frontSource = nil
	collectgarbage()
	back = triangle(36, 4, 0, 1, 0, 0, true)
	near = triangle(4, 36, 0.2, 0, 1, 0, false)
	far = triangle(4, 36, 0.8, 1, 0, 0, false)
	mapped = love.graphics.newMesh({
		{36, 36, 0, 0, 0, 1, 1, 1},
		{60, 36, 0, 0, 0, 1, 1, 1},
		{36, 60, 0, 0, 0, 1, 1, 1},
		{68, 36, 0, 0, 1, 0, 1, 1},
		{92, 36, 0, 0, 1, 0, 1, 1},
		{68, 60, 0, 0, 1, 0, 1, 1},
	}, "triangles", "stream")
	mapped:setVertexMap(love.filesystem.newFileData(
		string.pack("=I2I2I2I2I2I2", 0, 1, 2, 3, 4, 5), "mapped-indices.bin"), "uint16")
	mapped:setDrawRange(1, 3)
	assert(mapped:getVertexCount() == 6)
	local start, count = mapped:getDrawRange()
	assert(start == 1 and count == 3)
	textureCanvas = love.graphics.newCanvas(4, 4)
	maskCanvas = love.graphics.newCanvas(2, 2)
	maskCanvas:setFilter("nearest")
	maskCanvas:setWrap("repeat", "mirroredrepeat")
	textured = love.graphics.newMesh({
		{68, 36, 0, 0},
		{92, 36, 1, 0},
		{92, 60, 1, 1},
		{68, 60, 0, 1},
	}, "fan", "dynamic")
	textured:setTexture(textureCanvas)
	tintShader = love.graphics.newShader("tint.frag")
	assert(tintShader:getWarnings() == "")
	assert(tintShader:hasUniform("tint") and tintShader:hasUniform("intensity")
		and tintShader:hasUniform("mask") and tintShader:hasUniform("layers"))
	local function packed(name, format, ...)
		return love.filesystem.newFileData(string.pack(format, ...), name)
	end
	tintShader:sendColor("tint", packed("tint.bin", "=fff", 1, 0.5, 0), 0, 12)
	tintShader:send("intensity", packed("intensity.bin", "=f", 1))
	tintShader:send("mode", packed("mode.bin", "=i4", 1))
	tintShader:send("flags", packed("flags.bin", "=I4", 4000000000))
	tintShader:send("enabled", packed("enabled.bin", "=i4", 1))
	tintShader:send("weights", packed("weights.bin", "=I4fff", 99, 0.25, 1, 0.5), 4, 12)
	tintShader:send("offsets", packed("offsets.bin", "=i4i4i4i4", 0, 0, 2, -2))
	tintShader:send("palette", packed("palette.bin", "=ffffff", 0, 0, 0, 1, 1, 1))
	tintShader:send("basis", packed("basis.bin", "=ffff", 1, 2, 3, 4))
	tintShader:send("frames", "column", packed("frames.bin", "=ffffffffffffffffff",
		1,2,3, 4,5,6, 7,8,9, 9,8,7, 6,5,4, 3,2,1))
	tintShader:send("transforms", packed("transforms.bin", "=ffffffffffffffffffffffffffffffff",
		1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1,
		1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16), "row")
	tintShader:send("mask", maskCanvas)
	tintShader:send("layers", textureCanvas, maskCanvas)
	assert(not pcall(tintShader.sendColor, tintShader, "mask", {1, 1, 1, 1}))
	love.graphics.setCanvas(maskCanvas)
	assert(not pcall(tintShader.send, tintShader, "mask", maskCanvas))
	love.graphics.setCanvas()
	local valid, validationError = love.graphics.validateShader(false, "tint.frag")
	assert(valid and validationError == nil)
	valid, validationError = love.graphics.validateShader(false,
		"vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) { invalid syntax; }")
	assert(not valid and type(validationError) == "string" and #validationError > 0)
	valid, validationError = love.graphics.validateShader(false,
		"extern Image excessive[16]; vec4 effect(vec4 c, Image t, vec2 uv, vec2 s) { return Texel(excessive[0], uv); }")
	assert(not valid and validationError:find("15 additional Image uniforms", 1, true))
end

function love.draw()
	love.graphics.setCanvas(maskCanvas)
	love.graphics.clear(0.25, 1, 1, 1)
	love.graphics.setCanvas(textureCanvas)
	love.graphics.clear(0, 0, 1, 1)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)

	-- Default Love front winding is ccw. Only the first triangle should survive back-face culling.
	love.graphics.setFrontFaceWinding("ccw")
	love.graphics.setMeshCullMode("back")
	love.graphics.draw(front)
	love.graphics.draw(back)

	-- Draw the near triangle first. The later far triangle must fail the less test.
	love.graphics.setMeshCullMode("none")
	love.graphics.setDepthMode("less", true)
	love.graphics.draw(near)
	love.graphics.draw(far)
	love.graphics.setDepthMode()

	-- The draw range selects only the cyan indexed triangle; magenta must remain absent.
	love.graphics.draw(mapped)
	love.graphics.setShader(tintShader)
	assert(not pcall(love.graphics.setCanvas, maskCanvas))
	-- The same runtime-compiled Shader must work on both Dora's ordinary Sprite
	-- path and the indexed textured-Mesh path.
	love.graphics.draw(textureCanvas, 68, 4, 0, 6, 6)
	love.graphics.draw(textured)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(canvas, 0, 0)
	if canvasVerified and not screenshotRequested then
		screenshotRequested = true
		love.graphics.captureScreenshot("mesh-depth-shader.png")
		love.graphics.captureScreenshot(function(data)
			assert(data:getWidth() == 96 and data:getHeight() == 64)
			expect(data, 10, 10, 0, 1, 0, "screenshot ccw front")
			expect(data, 10, 42, 0, 1, 0, "screenshot depth less")
			expect(data, 42, 42, 0, 1, 1, "screenshot indexed mesh")
			expect(data, 74, 10, 0.0625, 0.5, 0, "screenshot Shader Canvas")
			screenshotVerified = true
			print("LOVE_MESH_DEPTH_VISUAL_EVIDENCE_PASS", data:getDimensions())
		end)
	end
end

expect = function(image, x, y, r, g, b, label)
	local ar, ag, ab, aa = image:getPixel(x, y)
	assert(math.abs(ar - r) < 0.02 and math.abs(ag - g) < 0.02
		and math.abs(ab - b) < 0.02 and aa > 0.98,
		label .. ": " .. ar .. "," .. ag .. "," .. ab .. "," .. aa)
end

function love.update()
	frame = frame + 1
	if frame < 2 then return end
	if not canvasVerified then
		local image = canvas:newImageData()
		local shaderPixels, minX, minY, maxX, maxY = 0, 96, 64, -1, -1
		for y = 0, 63 do
			for x = 0, 95 do
				local r, g, b = image:getPixel(x, y)
				if r > 0.03 and r < 0.1 and g > 0.3 and g < 0.7 and b < 0.2 then
					shaderPixels = shaderPixels + 1
					minX, minY = math.min(minX, x), math.min(minY, y)
					maxX, maxY = math.max(maxX, x), math.max(maxY, y)
				end
			end
		end
		print("LOVE_SHADER_PIXEL_BOUNDS", shaderPixels, minX, minY, maxX, maxY)
		expect(image, 10, 10, 0, 1, 0, "ccw front")
		expect(image, 42, 10, 0, 0, 0, "reversed back")
		expect(image, 10, 42, 0, 1, 0, "depth less")
		expect(image, 42, 42, 0, 1, 1, "indexed draw range")
		expect(image, 64, 42, 0, 0, 0, "excluded draw range")
		expect(image, 74, 10, 0.0625, 0.5, 0, "runtime-compiled Shader Canvas sampler array")
		expect(image, 74, 42, 0.0625, 0.5, 0, "runtime-compiled Shader Mesh sampler array")
		canvasVerified = true
		print("LOVE_MESH_DEPTH_CANVAS_PASS", image:getDimensions())
	end
	if not screenshotVerified or not love.filesystem.getInfo("mesh-depth-shader.png", "file") then return end
	local image = canvas:newImageData()
	expect(image, 10, 10, 0, 1, 0, "ccw front")
	expect(image, 42, 10, 0, 0, 0, "reversed back")
	expect(image, 10, 42, 0, 1, 0, "depth less")
	expect(image, 42, 42, 0, 1, 1, "indexed draw range")
	expect(image, 64, 42, 0, 0, 0, "excluded draw range")
	expect(image, 74, 10, 0.0625, 0.5, 0, "runtime-compiled Shader Canvas sampler array")
	expect(image, 74, 42, 0.0625, 0.5, 0, "runtime-compiled Shader Mesh sampler array")
	print("LOVE_MESH_DEPTH_PASS", image:getDimensions())
	assert(love.event.quit())
end
