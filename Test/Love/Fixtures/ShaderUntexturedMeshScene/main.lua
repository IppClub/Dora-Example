local canvas
local mesh
local pointMesh
local texturedPoint
local textureCanvas
local shader
local frame = 0

function love.load()
	canvas = love.graphics.newCanvas(40, 32)
	mesh = love.graphics.newMesh({
		{4, 4, 0, 0, 1, 1, 1, 1},
		{28, 4, 1, 0, 1, 1, 1, 1},
		{28, 28, 1, 1, 1, 1, 1, 1},
		{4, 28, 0, 1, 1, 1, 1, 1},
	}, "fan", "static")
	pointMesh = love.graphics.newMesh({{34, 20, 0.5, 0.5, 1, 1, 1, 1}}, "points")
	texturedPoint = love.graphics.newMesh({{34, 8, 0.5, 0.5, 1, 1, 1, 1}}, "points")
	textureCanvas = love.graphics.newCanvas(2, 2)
	texturedPoint:setTexture(textureCanvas)
	shader = love.graphics.newShader("untextured.frag")
end

function love.draw()
	love.graphics.setCanvas(textureCanvas)
	love.graphics.clear(1, 0, 0, 1)
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setPointSize(6)
	love.graphics.setShader(shader)
	love.graphics.draw(mesh)
	love.graphics.setMeshCullMode("back")
	love.graphics.draw(pointMesh)
	love.graphics.setShader()
	love.graphics.draw(texturedPoint)
	love.graphics.setMeshCullMode("none")
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function love.update()
	frame = frame + 1
	if frame ~= 2 then return end
	local image = canvas:newImageData()
	local r, g, b, a = image:getPixel(16, 16)
	assert(math.abs(r - 0.25) < 0.02 and math.abs(g - 0.5) < 0.02
		and math.abs(b - 1) < 0.02 and a > 0.98,
		"untextured Shader Mesh did not sample the white default texture: "
			.. r .. "," .. g .. "," .. b .. "," .. a)
	r, g, b, a = image:getPixel(34, 20)
	assert(math.abs(r - 0.25) < 0.02 and math.abs(g - 0.5) < 0.02
		and math.abs(b - 1) < 0.02 and a > 0.98,
		"Shader Mesh point size/cull/default texture failed")
	r, g, b, a = image:getPixel(34, 8)
	assert(r > 0.98 and g < 0.02 and b < 0.02 and a > 0.98,
		"textured Mesh point did not sample its Canvas texture")
	print("LOVE_SHADER_UNTEXTURED_MESH_PASS", image:getDimensions())
	love.event.quit()
end
