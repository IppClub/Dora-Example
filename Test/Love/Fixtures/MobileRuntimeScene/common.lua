local function configure(red, green, focused, mixWithSystem)
	local canvas
	local image
	local source
	local rendered = false
	local pixelsChecked = false
	local joystickAdded = false
	local keyPressed = false
	local gamepadPressed = false
	local gamepadAxis = false
	local testAudio = true
	local phase = 0
	local frames = 0

	function love.load()
		local os = love.system.getOS()
		testAudio = os ~= "Linux"
		local mixAccepted = love.audio.setMixWithSystem(mixWithSystem)
		if os == "iOS" then
			assert(mixAccepted, "iOS AVAudioSession mixing policy was not accepted")
		else
			assert((os == "Android" or os == "Linux" or os == "Windows") and not mixAccepted,
				"only iOS may accept the system audio mixing policy")
		end
		assert(type(love.system.hasBackgroundMusic()) == "boolean")
		love.system.vibrate(0)
		canvas = love.graphics.newCanvas(16, 16)
		local imageData = love.image.newImageData(2, 2)
		imageData:mapPixel(function() return 1, 1, 1, 1 end)
		image = love.graphics.newImage(imageData)

		local soundData = love.sound.newSoundData(800, 8000, 16, 1)
		source = love.audio.newSource(soundData, "static")
		source:setVolume(0)
		source:setLooping(true)

		local stats = love.graphics.getStats()
		assert(stats.canvases == 1 and stats.images == 1,
			("unexpected initial resources: canvases=%d images=%d"):format(stats.canvases, stats.images))
		assert(stats.texturememory > 0, "LoveNode texture memory was not reported")
	end

	function love.joystickadded(joystick)
		assert(joystick:getName() == "Virtual Mobile Controller")
		joystickAdded = true
	end

	function love.keypressed(key, scancode, isrepeat)
		assert(focused, "keyboard input crossed the LoveNode focus boundary")
		assert(key == "a" and scancode == "a" and isrepeat == false)
		assert(love.keyboard.isDown("a"))
		keyPressed = true
	end

	function love.gamepadpressed(joystick, button)
		assert(focused, "gamepad button input crossed the LoveNode focus boundary")
		assert(button == "a" and joystick:isGamepadDown("a"))
		gamepadPressed = true
	end

	function love.gamepadaxis(joystick, axis, value)
		if math.abs(value) < 0.0001 then return end
		assert(focused, "gamepad axis input crossed the LoveNode focus boundary")
		assert(axis == "leftx" and math.abs(value - 0.5) < 0.0001)
		assert(math.abs(joystick:getGamepadAxis("leftx") - value) < 0.0001)
		gamepadAxis = true
	end

	function love.draw()
		if rendered then return end
		love.graphics.setCanvas(canvas)
		love.graphics.clear(red, green, 0.25, 1)
		love.graphics.setColor(red, green, 0.25, 1)
		love.graphics.rectangle("fill", 2, 2, 12, 12)
		love.graphics.setCanvas()

		love.graphics.clear(0.02, 0.03, 0.04, 1)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(canvas, 0, 0)
		love.graphics.draw(image, 20, 4)
		love.graphics.draw(image, 24, 4)

		local target = {sentinel = true}
		local stats = love.graphics.getStats(target)
		assert(stats == target and stats.sentinel)
		assert(stats.drawcalls > 0 and stats.drawcallsbatched > 0,
			"mobile renderer did not report submitted and batched draws")
		assert(stats.canvasswitches == 2 and stats.canvases == 1 and stats.images == 1,
			"per-instance graphics statistics changed unexpectedly")
		rendered = true
	end

	function love.update()
		frames = frames + 1
		if not rendered then return end
		if not pixelsChecked then
			local pixels = canvas:newImageData()
			local r, g, b, a = pixels:getPixel(8, 8)
			assert(math.abs(r - red) < 0.02 and math.abs(g - green) < 0.02
				and math.abs(b - 0.25) < 0.02 and math.abs(a - 1) < 0.02,
				("unexpected mobile Canvas pixel: %.3f %.3f %.3f %.3f"):format(r, g, b, a))
			pixelsChecked = true
			return
		end

		if phase == 0 then
			if not joystickAdded or frames < 10 then return end
			if focused and not (keyPressed and gamepadPressed and gamepadAxis) then return end
			if not testAudio then
				phase = 3
				assert(love.event.quit())
				return
			end
			assert(source:play() and source:isPlaying())
			assert(love.audio.getActiveSourceCount() == 1)
			phase = 1
		elseif phase == 1 then
			source:pause()
			assert(source:isPaused() and love.audio.getActiveSourceCount() == 1)
			phase = 2
		elseif phase == 2 then
			assert(source:play() and source:isPlaying())
			source:stop()
			assert(not source:isPlaying() and love.audio.getActiveSourceCount() == 0)
			phase = 3
			assert(love.event.quit())
		end
	end
end

return configure
