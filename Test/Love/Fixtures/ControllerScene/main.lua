local pad
local pressed = false
local rawPressed = false
local rawAxis = false

function love.load()
	local joystick = require("love.joystick")
	assert(joystick.getJoystickCount() == 1)
	pad = assert(joystick.getJoysticks()[1])
	assert(pad:isConnected() and pad:isGamepad())
	assert(pad:getName() == "Dora Dev Virtual Controller")
	local id, instanceId = pad:getID()
	assert(id == 1 and type(instanceId) == "number" and instanceId >= 1 and pad:getConnectedIndex() == 1)
	assert(#pad:getGUID() == 32)
	local vendor, product, version = pad:getDeviceInfo()
	assert(type(vendor) == "number" and type(product) == "number" and type(version) == "number")
	assert(pad:getAxisCount() >= 6 and pad:getButtonCount() >= 15 and pad:getHatCount() == 0)
	local axes = {pad:getAxes()}
	assert(#axes == pad:getAxisCount() and type(pad:getAxis(1)) == "number" and pad:getHat(1) == "c")
	local inputType, inputIndex = pad:getGamepadMapping("a")
	assert(inputType == "button" and inputIndex == 1)
	local mapping = assert(pad:getGamepadMappingString())
	assert(joystick.getGamepadMappingString(pad:getGUID()) == mapping)
	assert(joystick.setGamepadMapping(pad:getGUID(), "a", "button", 1))
	local saved = joystick.saveGamepadMappings("controller-mappings.txt")
	local stored = assert(love.filesystem.read("controller-mappings.txt"))
	assert(stored == saved and saved:find(pad:getGUID(), 1, true))
	joystick.loadGamepadMappings("controller-mappings.txt")
	assert(love.filesystem.remove("controller-mappings.txt"))
	print("LOVE_JOYSTICK_MAPPING_PASS", inputType, inputIndex, #saved)
	local vibrationSupported = pad:isVibrationSupported()
	assert(type(vibrationSupported) == "boolean")
	if vibrationSupported then assert(pad:setVibration()) end
	local left, right = pad:getVibration()
	assert(left == 0 and right == 0)
	print("LOVE_JOYSTICK_DEVICE_PASS", #axes, pad:getButtonCount(), pad:getGUID(), vibrationSupported)
	print("LOVE_CONTROLLER_READY", controller_scene_owner, pad:getName())
end

function love.joystickpressed(joystick, button)
	assert(joystick == pad and button == 1)
	rawPressed = true
	print("LOVE_JOYSTICK_RAW_DOWN", button)
end

function love.joystickaxis(joystick, axis, value)
	assert(joystick == pad and axis == 1 and math.abs(value - 0.5) < 0.0001)
	rawAxis = true
	print("LOVE_JOYSTICK_RAW_AXIS", axis, value)
end

function love.joystickreleased(joystick, button)
	assert(joystick == pad and button == 1 and rawPressed and rawAxis)
	print("LOVE_JOYSTICK_RAW_PASS", button)
end

function love.gamepadpressed(joystick, button)
	assert(controller_scene_owner == "first")
	assert(joystick == pad and button == "a" and pad:isGamepadDown("a"))
	pressed = true
	print("LOVE_CONTROLLER_DOWN", controller_scene_owner, button)
end

function love.gamepadreleased(joystick, button)
	assert(controller_scene_owner == "first")
	assert(joystick == pad and button == "a" and not pad:isGamepadDown("a"))
	assert(pressed and rawPressed and rawAxis)
	print("LOVE_CONTROLLER_PASS", controller_scene_owner, button)
	love.event.quit()
end

function love.draw()
	love.graphics.clear(controller_scene_owner == "first" and 0.03 or 0.16, 0.08, 0.18, 1)
end
