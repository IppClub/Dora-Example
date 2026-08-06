local originalClipboard

function love.load()
	local system = require("love.system")
	assert(system == love.system)
	assert(system.getOS() == "OS X" or system.getOS() == "Windows")
	local processors = system.getProcessorCount()
	assert(type(processors) == "number" and processors >= 1)

	local state, percent, seconds = system.getPowerInfo()
	local validStates = {
		unknown = true,
		battery = true,
		nobattery = true,
		charging = true,
		charged = true,
	}
	assert(validStates[state])
	assert(percent == nil or (percent >= 0 and percent <= 100))
	assert(seconds == nil or seconds >= 0)

	originalClipboard = system.getClipboardText()
	local marker = "Dora Love system clipboard validation"
	system.setClipboardText(marker)
	assert(system.getClipboardText() == marker)
	system.setClipboardText(originalClipboard)
	assert(not system.openURL("file:///tmp/dora-love-system-test"))
	system.vibrate()
	system.vibrate(0.25)
	assert(not system.hasBackgroundMusic())
	print("LOVE_SYSTEM_HOST_PASS", system.getOS(), processors, state,
		percent == nil and "nil" or percent, seconds == nil and "nil" or seconds)
end

function love.update()
	assert(love.event.quit())
end

function love.quit()
	if originalClipboard ~= nil and love.system.getClipboardText() ~= originalClipboard then
		love.system.setClipboardText(originalClipboard)
	end
	print("LOVE_SYSTEM_QUIT_PASS")
	return false
end
