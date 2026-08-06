local graphics = require("love.graphics")
local image = require("love.image")

local canvas
local scratch
local rendered = false
local verified = false

local function equal(actual, expected, label)
	assert(actual == expected,
		("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local function near(actual, expected)
	return math.abs(actual - expected) < 0.04
end

local function verifyPixel(data, x, y, expected, label)
	local r, g, b, a = data:getPixel(x, y)
	assert(near(r, expected[1]) and near(g, expected[2])
		and near(b, expected[3]) and near(a, expected[4]),
		("%s pixel %.3f %.3f %.3f %.3f"):format(label, r, g, b, a))
end

function love.load()
	assert(graphics.isActive())
	assert(not graphics.isGammaCorrect())
	local supportedTarget = {sentinel = true}
	local supported = graphics.getSupported(supportedTarget)
	equal(supported, supportedTarget, "getSupported target")
	assert(supported.sentinel and supported.multicanvasformats and supported.clampzero
		and not supported.lighten and supported.fullnpot and supported.pixelshaderhighp
		and supported.shaderderivatives and supported.glsl3 and supported.instancing)
	local textureTarget = {sentinel = true}
	local textureTypes = graphics.getTextureTypes(textureTarget)
	equal(textureTypes, textureTarget, "getTextureTypes target")
	assert(textureTypes.sentinel and textureTypes["2d"] and textureTypes.array
		and textureTypes.cube and textureTypes.volume)
	local formatTarget = {sentinel = true}
	local imageFormats = graphics.getImageFormats(formatTarget)
	equal(imageFormats, formatTarget, "getImageFormats target")
	assert(imageFormats.sentinel and imageFormats.r8 and imageFormats.rgba8
		and type(imageFormats.DXT1) == "boolean" and not imageFormats.BC4s
		and type(imageFormats.EACr) == "boolean" and imageFormats.normal == nil
		and imageFormats.srgba8 == nil and imageFormats.depth24 == nil)
	local rendererName, rendererVersion, rendererVendor, rendererDevice =
		graphics.getRendererInfo()
	local osName = love.system.getOS()
	if osName == "OS X" then
		equal(rendererName, "Metal", "renderer name")
	elseif osName == "Windows" then
		assert(rendererName == "Direct3D 11" or rendererName == "Direct3D 12",
			("renderer name: expected Direct3D, got %s"):format(rendererName))
	else
		assert(rendererName ~= "Noop", "graphics workflow requires a real renderer")
	end
	assert(rendererVersion:find("bgfx API ", 1, true) == 1
		and #rendererVendor > 0 and #rendererDevice > 0)
	local derivativeShader = graphics.newShader([[
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			highp float derivative = abs(dFdx(screen.x)) + abs(dFdy(screen.y))
				+ fwidth(uv.x);
			return Texel(texture, uv) * color * (derivative * 0.0 + 1.0);
		}
	]])
	assert(derivativeShader)
	local r, g, b, a = graphics.getBackgroundColor()
	equal(r + g + b, 0, "default background RGB")
	equal(a, 1, "default background alpha")

	graphics.setBackgroundColor(0.125, 0.25, 0.5, 0.75)
	graphics.setDefaultFilter("nearest", "nearest", 2)
	graphics.push("all")
	graphics.setBackgroundColor(1, 0, 0, 1)
	graphics.setDefaultFilter("linear")
	graphics.pop()
	r, g, b, a = graphics.getBackgroundColor()
	equal(r, 0.125, "restored background red")
	equal(g, 0.25, "restored background green")
	equal(b, 0.5, "restored background blue")
	equal(a, 0.75, "restored background alpha")
	local min, mag, anisotropy = graphics.getDefaultFilter()
	equal(min, "nearest", "restored default minification filter")
	equal(mag, "nearest", "restored default magnification filter")
	equal(anisotropy, 2, "restored default anisotropy")

	local pixels = image.newImageData(2, 2)
	local drawable = graphics.newImage(pixels)
	min, mag, anisotropy = drawable:getFilter()
	equal(min, "nearest", "Image inherited default filter")
	equal(mag, "nearest", "Image inherited default magnification filter")
	equal(anisotropy, 2, "Image inherited default anisotropy")
	canvas = graphics.newCanvas(32, 32)
	min, mag, anisotropy = canvas:getFilter()
	equal(min, "nearest", "Canvas inherited default filter")
	equal(mag, "nearest", "Canvas inherited default magnification filter")
	equal(anisotropy, 2, "Canvas inherited default anisotropy")

	graphics.origin()
	graphics.translate(2, 3)
	graphics.applyTransform(love.math.newTransform(4, 5, 0, 2, 3))
	local x, y = graphics.transformPoint(1, 1)
	equal(x, 8, "applied transform x")
	equal(y, 11, "applied transform y")
	local inverseX, inverseY = graphics.inverseTransformPoint(x, y)
	equal(inverseX, 1, "inverse transform x")
	equal(inverseY, 1, "inverse transform y")
	graphics.replaceTransform(love.math.newTransform(10, 12))
	graphics.shear(2, 3)
	x, y = graphics.transformPoint(4, 5)
	equal(x, 24, "replaced and sheared transform x")
	equal(y, 29, "replaced and sheared transform y")
	graphics.origin()

	scratch = graphics.newCanvas(4, 4)
	graphics.setCanvas(scratch)
	graphics.setColor(0, 0, 0, 0)
	graphics.setBackgroundColor(1, 1, 1, 0)
	graphics.setDefaultFilter("nearest")
	graphics.setLineWidth(7)
	graphics.setPointSize(4)
	graphics.setBlendMode("add", "premultiplied")
	graphics.setScissor(1, 1, 2, 2)
	graphics.setColorMask(false, false, false, false)
	graphics.setDepthMode("less", true)
	graphics.setMeshCullMode("back")
	graphics.setFrontFaceWinding("cw")
	graphics.setStencilTest("greater", 2)
	graphics.translate(9, 10)
	graphics.reset()
	equal(graphics.getCanvas(), nil, "reset Canvas")
	equal(graphics.getScissor(), nil, "reset scissor")
	equal(graphics.getStencilTest(), nil, "reset stencil test")
	min, mag, anisotropy = graphics.getDefaultFilter()
	equal(min, "linear", "reset default filter")
	equal(mag, "linear", "reset default magnification filter")
	equal(anisotropy, 1, "reset anisotropy")
	r, g, b, a = graphics.getColor()
	equal(r + g + b + a, 4, "reset color")
	x, y = graphics.transformPoint(3, 4)
	equal(x, 3, "reset transform x")
	equal(y, 4, "reset transform y")
	graphics.discard(false, false)
	graphics.discard({false}, false)
	graphics.flushBatch()
end

function love.draw()
	if not rendered then
		graphics.setCanvas(canvas)
		graphics.clear(0, 0, 0, 1)
		graphics.setColor(1, 0, 0, 1)
		graphics.setScissor(4, 4, 20, 20)
		graphics.intersectScissor(12, 0, 20, 16)
		local x, y, width, height = graphics.getScissor()
		equal(x, 12, "intersected scissor x")
		equal(y, 4, "intersected scissor y")
		equal(width, 12, "intersected scissor width")
		equal(height, 12, "intersected scissor height")
		graphics.rectangle("fill", 0, 0, 32, 32)
		graphics.flushBatch()
		graphics.setScissor()
		graphics.setColor(0, 1, 0, 1)
		graphics.applyTransform(love.math.newTransform(2, 20))
		graphics.rectangle("fill", 0, 0, 6, 6)
		graphics.origin()
		graphics.setCanvas()
		rendered = true
	end
	graphics.clear(0.05, 0.05, 0.08, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.draw(canvas, 16, 16)
end

function love.update()
	if rendered and not verified then
		local data = canvas:newImageData()
		verifyPixel(data, 13, 5, {1, 0, 0, 1}, "intersected scissor inside")
		verifyPixel(data, 5, 5, {0, 0, 0, 1}, "intersected scissor left outside")
		verifyPixel(data, 13, 17, {0, 0, 0, 1}, "intersected scissor bottom outside")
		verifyPixel(data, 3, 21, {0, 1, 0, 1}, "applied transform draw")
		verified = true
		love.event.quit()
	end
end
