local graphics = require("love.graphics")

local canvases = {}
local rendered = false
local verified = false

local function drawSample(canvas, style, join, shader)
	graphics.setCanvas(canvas)
	graphics.clear(0, 0, 0, 1)
	graphics.setColor(1, 1, 1, 1)
	graphics.setLineWidth(10)
	graphics.setLineStyle(style)
	graphics.setLineJoin(join)
	graphics.setShader(shader)
	graphics.line(6, 38, 24, 8, 42, 38)
	graphics.setShader()
	graphics.setCanvas()
end

local function comparePixels(left, right)
	local changed = 0
	local leftFractional = 0
	local rightFractional = 0
	for y = 0, 47 do
		for x = 0, 47 do
			local lr = left:getPixel(x, y)
			local rr = right:getPixel(x, y)
			if math.abs(lr - rr) > 0.05 then changed = changed + 1 end
			if lr > 0.02 and lr < 0.98 then leftFractional = leftFractional + 1 end
			if rr > 0.02 and rr < 0.98 then rightFractional = rightFractional + 1 end
		end
	end
	return changed, leftFractional, rightFractional
end

function love.load()
	assert(graphics.getLineStyle() == "smooth")
	assert(graphics.getLineJoin() == "miter")
	graphics.setLineStyle("rough")
	graphics.setLineJoin("bevel")
	graphics.push("all")
	graphics.setLineStyle("smooth")
	graphics.setLineJoin("none")
	graphics.pop()
	assert(graphics.getLineStyle() == "rough")
	assert(graphics.getLineJoin() == "bevel")
	assert(not pcall(graphics.setLineStyle, "invalid"))
	assert(not pcall(graphics.setLineJoin, "invalid"))
	graphics.reset()
	assert(graphics.getLineStyle() == "smooth")
	assert(graphics.getLineJoin() == "miter")

	for index = 1, 6 do
		canvases[index] = graphics.newCanvas(48, 48)
	end
end

function love.draw()
	if not rendered then
		drawSample(canvases[1], "rough", "miter")
		drawSample(canvases[2], "smooth", "miter")
		drawSample(canvases[3], "rough", "bevel")
		drawSample(canvases[4], "rough", "none")
		local shader = graphics.newShader([[
			#pragma language glsl3
			vec4 position(mat4 transform_projection, vec4 vertex_position) {
				vertex_position.x += float(love_VertexID) * 0.0;
				return transform_projection * vertex_position;
			}
		]])
		drawSample(canvases[5], "smooth", "bevel", shader)
		graphics.setCanvas(canvases[6])
		graphics.clear(0, 0, 0, 1)
		graphics.setColor(1, 1, 1, 1)
		graphics.setLineWidth(10)
		graphics.setLineStyle("rough")
		graphics.setLineJoin("miter")
		graphics.origin()
		graphics.scale(1, 2)
		graphics.line(6, 12, 42, 12)
		graphics.origin()
		graphics.setCanvas()
		rendered = true
	end

	graphics.clear(0.04, 0.04, 0.06, 1)
	graphics.setColor(1, 1, 1, 1)
	for index, canvas in ipairs(canvases) do
		graphics.draw(canvas, 4 + (index - 1) * 30, 4, 0, 0.6, 0.6)
	end
end

function love.update()
	if rendered and not verified then
		local rough = canvases[1]:newImageData()
		local smooth = canvases[2]:newImageData()
		local bevel = canvases[3]:newImageData()
		local none = canvases[4]:newImageData()
		local shader = canvases[5]:newImageData()
		local transformed = canvases[6]:newImageData()
		local styleChanged, roughFractional, smoothFractional = comparePixels(rough, smooth)
		local miterBevelChanged = comparePixels(rough, bevel)
		local bevelNoneChanged = comparePixels(bevel, none)
		assert(styleChanged >= 20,
			("rough/smooth geometry differs by only %d pixels"):format(styleChanged))
		assert(smoothFractional > roughFractional + 10,
			("smooth antialias fringe %d is not greater than rough %d")
				:format(smoothFractional, roughFractional))
		assert(miterBevelChanged >= 10,
			("miter/bevel geometry differs by only %d pixels"):format(miterBevelChanged))
		assert(bevelNoneChanged >= 10,
			("bevel/none geometry differs by only %d pixels"):format(bevelNoneChanged))
		local sr, sg, sb = shader:getPixel(24, 12)
		assert(sr > 0.5 and sg > 0.5 and sb > 0.5,
			("custom Shader line pixel %.3f %.3f %.3f"):format(sr, sg, sb))
		local transformedWidth = 0
		for y = 0, 47 do
			local r = transformed:getPixel(24, y)
			if r > 0.5 then transformedWidth = transformedWidth + 1 end
		end
		assert(transformedWidth >= 18 and transformedWidth <= 22,
			("scaled line width is %d pixels, expected about 20"):format(transformedWidth))
		verified = true
		love.event.quit()
	end
end
