local graphics = require("love.graphics")
local image = require("love.image")

local function configure(resourceCount)
	local images = {}
	local canvases = {}
	local fonts = {}
	local phase = 0

	function love.load()
		for index = 1, resourceCount do
			local pixels = image.newImageData(2 + index, 2 + index)
			pixels:mapPixel(function()
				return index / resourceCount, 0.25, 0.5, 1
			end)
			images[index] = graphics.newImage(pixels)
			canvases[index] = graphics.newCanvas(12 + index, 12 + index)
			fonts[index] = graphics.newFont(10 + index)
		end

		local stats = graphics.getStats()
		assert(stats.images == resourceCount,
			("images=%d expected=%d"):format(stats.images, resourceCount))
		assert(stats.canvases == resourceCount,
			("canvases=%d expected=%d"):format(stats.canvases, resourceCount))
		assert(stats.fonts == resourceCount,
			("fonts=%d expected=%d"):format(stats.fonts, resourceCount))
		assert(stats.texturememory > 0, "owned textures did not contribute texture memory")
	end

	function love.draw()
		if phase ~= 0 then return end
		graphics.setCanvas(canvases[1])
		graphics.clear(0, 0, 0, 1)
		graphics.setColor(1, 0, 0, 1)
		graphics.rectangle("fill", 1, 1, 3, 3)
		graphics.rectangle("fill", 5, 1, 3, 3)
		graphics.setCanvas()

		local shader = graphics.newShader([[
			vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
				return color;
			}
		]])
		graphics.setShader(shader)
		graphics.rectangle("fill", 1, 1, 2, 2)
		graphics.setShader()
		graphics.draw(images[1], 20, 2)
		graphics.draw(images[1], 26, 2)

		local target = {sentinel = true}
		local stats = graphics.getStats(target)
		assert(stats == target and stats.sentinel, "getStats did not reuse the target table")
		assert(stats.drawcalls == 3,
			("drawcalls=%d expected=3"):format(stats.drawcalls))
		assert(stats.drawcallsbatched == 2,
			("drawcallsbatched=%d expected=2"):format(stats.drawcallsbatched))
		assert(stats.canvasswitches == 2,
			("canvasswitches=%d expected=2"):format(stats.canvasswitches))
		assert(stats.shaderswitches == 2,
			("shaderswitches=%d expected=2"):format(stats.shaderswitches))
		assert(stats.images == resourceCount and stats.canvases == resourceCount
			and stats.fonts == resourceCount,
			"resource stats crossed LoveNode state boundaries")
		assert(stats.texturememory > 0, "texturememory was not preserved during drawing")
		phase = 1
	end

	function love.update()
		if phase ~= 1 then return end
		local stats = graphics.getStats()
		assert(stats.drawcalls == 0 and stats.drawcallsbatched == 0
			and stats.canvasswitches == 0 and stats.shaderswitches == 0,
			"per-frame graphics stats did not reset after present")
		assert(stats.images == resourceCount and stats.canvases == resourceCount
			and stats.fonts == resourceCount and stats.texturememory > 0,
			"persistent graphics stats changed at the frame boundary")
		phase = 2
		love.event.quit()
	end
end

return configure
