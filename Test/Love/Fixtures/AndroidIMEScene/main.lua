local frames = 0
local keyPressed = 0
local keyReleased = 0
local textInput = 0
local closingFrame

function love.load()
	assert(love.keyboard.hasTextInput(), "Love text input must be enabled by default")
	assert(love.keyboard.hasScreenKeyboard(), "Android must report screen keyboard support")
	love.keyboard.setTextInput(true, 24, 36, 160, 24)
	assert(love.keyboard.hasTextInput(), "explicit Android text input did not become active")
end

function love.keypressed(key, scancode, isRepeat)
	assert(key == "a" and scancode == "a" and not isRepeat,
		("unexpected Android IME key: %s/%s repeat=%s")
			:format(key, scancode, tostring(isRepeat)))
	keyPressed = keyPressed + 1
	assert(keyPressed == 1, "explicit Android IME duplicated keypressed")
	assert(love.keyboard.isDown("a"), "Android IME key state was not set before keypressed")
end

function love.keyreleased(key, scancode)
	assert(key == "a" and scancode == "a", "unexpected Android IME key release")
	keyReleased = keyReleased + 1
	assert(keyReleased == 1, "explicit Android IME duplicated keyreleased")
	assert(not love.keyboard.isDown("a"), "Android IME key state was not cleared before keyreleased")
end

function love.textinput(text)
	assert(text == "a", "unexpected Android IME text input: " .. text)
	textInput = textInput + 1
	assert(textInput == 1, "explicit Android IME duplicated textinput")
end

function love.update()
	frames = frames + 1
	if not closingFrame and keyPressed == 1 and keyReleased == 1 and textInput == 1 then
		love.keyboard.setTextInput(false)
		assert(not love.keyboard.hasTextInput(), "Android text input did not deactivate")
		closingFrame = frames
	elseif closingFrame and frames >= closingFrame + 10 then
		print("LOVE_ANDROID_IME_PASS", "default=true", "key=single", "text=a", "closed=true")
		love.event.quit()
	end
	if frames == 850 then
		error(("Android IME timed out key=%d/%d text=%d")
			:format(keyPressed, keyReleased, textInput))
	end
end

function love.draw()
	love.graphics.clear(0.04, 0.04, 0.06, 1)
	love.graphics.setColor(keyPressed == 1 and 0.2 or 0.7,
		textInput == 1 and 0.9 or 0.2, keyReleased == 1 and 0.8 or 0.2, 1)
	love.graphics.rectangle("fill", 24, 36, 160, 24)
end
