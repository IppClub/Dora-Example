local device
local deviceName = ""
local elapsed = 0
local retryElapsed = 0
local started = false
local finished = false
local armed = false
local message = "enumerating capture devices"

local function finish(result)
	if finished then return end
	finished = true
	assert(love.filesystem.write("result.txt", result))
	print("LOVE_PHYSICAL_RECORDING_RESULT", result)
	love.event.quit()
end

function love.load()
	local devices = love.audio.getRecordingDevices()
	if #devices == 0 then
		finish("failed: no SDL capture device")
		return
	end
	device = devices[1]
	deviceName = device:getName()
	message = "press Space or click to request microphone access"
end

function love.update(dt)
	if finished or not device then return end
	if not armed then return end
	elapsed = elapsed + dt
	if not started then
		retryElapsed = retryElapsed + dt
		if retryElapsed >= 0.5 then
			retryElapsed = 0
			started = device:start(16000, 16000, 16, 1)
			message = started and "recording" or "waiting for microphone permission/device"
		end
		if not started and elapsed >= 20 then
			finish("failed: capture device did not start")
		end
		return
	end

	local count = device:getSampleCount()
	message = string.format("recording %d samples", count)
	if count < 4096 and elapsed < 15 then return end

	local data = device:stop()
	if not data then
		finish("failed: capture returned no SoundData")
		return
	end
	local samples = data:getSampleCount()
	if samples < 256 then
		finish(string.format("failed: only %d captured samples", samples))
		return
	end
	local minimum, maximum = 1, -1
	local sumSquares = 0
	local nonzero = 0
	for index = 0, samples - 1 do
		local sample = data:getSample(index)
		minimum = math.min(minimum, sample)
		maximum = math.max(maximum, sample)
		sumSquares = sumSquares + sample * sample
		if math.abs(sample) > 1 / 32768 then nonzero = nonzero + 1 end
	end
	local range = maximum - minimum
	local rms = math.sqrt(sumSquares / samples)
	if nonzero == 0 or range <= 1 / 32768 then
		finish(string.format("failed: silent capture samples=%d range=%.8f rms=%.8f", samples, range, rms))
		return
	end
	finish(string.format(
		"platform=macOS device=%s samples=%d format=16000/16/1 waveform=pass range=%.8f rms=%.8f",
		deviceName:gsub("[\r\n]", " "), samples, range, rms))
end

local function armRecording()
	if armed or finished or not device then return end
	armed = true
	message = "requesting microphone: " .. deviceName
end

function love.keypressed(key)
	if key == "space" or key == "return" then armRecording() end
end

function love.mousepressed()
	armRecording()
end

function love.draw()
	love.graphics.clear(0.04, 0.055, 0.075, 1)
	love.graphics.setColor(0.3, 0.8, 1, 1)
	love.graphics.print("Love RecordingDevice physical capture", 24, 32)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(message, 24, 76)
	love.graphics.print("The test checks real PCM frames and waveform range.", 24, 112)
	love.graphics.print("No permission request is made before explicit interaction.", 24, 140)
end
