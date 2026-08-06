local events = {}

function love.load()
	assert(not love.keyboard.hasKeyRepeat())
	love.keyboard.setKeyRepeat(true)
	assert(love.keyboard.hasKeyRepeat())
	for _, pair in ipairs({
		{"a", "a"}, {"return", "return"}, {"escape", "escape"}, {"space", "space"},
		{"f1", "f1"}, {"left", "left"}, {"lctrl", "lctrl"}, {"kp1", "kp1"},
		{"numlock", "numlock"},
	}) do
		assert(love.keyboard.getScancodeFromKey(pair[1]) == pair[2], pair[1])
		assert(love.keyboard.getKeyFromScancode(pair[2]) == pair[1], pair[2])
	end
	assert(not love.keyboard.isDown("f24") and not love.keyboard.isScancodeDown("app2"))
	assert(type(love.keyboard.hasScreenKeyboard()) == "boolean")
	love.keyboard.setTextInput(true, 24, 36, 160, 24)
	assert(love.keyboard.hasTextInput())
	print("LOVE_KEYBOARD_TEXT_READY")
end

function love.keypressed(key, scancode, isrepeat)
	assert(key == "a" and scancode == "a")
	assert(love.keyboard.isDown({"escape", "a"}))
	assert(love.keyboard.isScancodeDown({"escape", "a"}))
	events[#events + 1] = "pressed:" .. tostring(isrepeat)
end

function love.textinput(text)
	assert(text == "你")
	events[#events + 1] = "text:" .. text
end

function love.textedited(text, start, length)
	assert(text == "拼音" and start == 1 and length == 2)
	print("LOVE_TEXT_EDITING_PASS", text, start, length)
	events[#events + 1] = "edited:" .. text .. ":" .. start .. ":" .. length
end

function love.keyreleased(key, scancode)
	assert(key == "a" and scancode == "a")
	assert(not love.keyboard.isDown("a") and not love.keyboard.isScancodeDown("a"))
	events[#events + 1] = "released"
end

function love.update()
	if #events == 5 then
		assert(table.concat(events, "|") == "pressed:false|pressed:true|text:你|edited:拼音:1:2|released")
		print("LOVE_KEYBOARD_TEXT_PASS", table.concat(events, "|"))
		love.event.quit()
	end
end

function love.draw()
	love.graphics.clear(0.03, 0.08, 0.16, 1)
end
