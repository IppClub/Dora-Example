local function expectFailure(label, action, expected)
	local ok, message = pcall(action)
	assert(not ok, label .. " unexpectedly succeeded")
	for _, fragment in ipairs(expected) do
		assert(message:find(fragment, 1, true), label .. " missing diagnostic fragment: " .. fragment .. "\n" .. message)
	end
	print("LOVE_RESOURCE_FAILURE_PASS", label, message)
end

function love.load()
	local image = require("love.image")
	local sound = require("love.sound")

	expectFailure("missing-image", function()
		love.graphics.newImage("missing.png")
	end, {"Love Image", "missing.png", "file does not exist"})

	expectFailure("corrupt-image", function()
		love.graphics.newImage("corrupt.png")
	end, {"Love Image", "corrupt.png", "TextureCache", "format 'png'", "LoveNode"})

	expectFailure("missing-imagedata", function()
		image.newImageData("missing.png")
	end, {"Love ImageData", "missing.png", "resolution failed", "file does not exist"})

	expectFailure("corrupt-imagedata", function()
		image.newImageData("corrupt.png")
	end, {"Love ImageData", "corrupt.png", "decode failed", "bimg"})

	expectFailure("missing-sounddata", function()
		sound.newSoundData("missing.wav")
	end, {"Love SoundData", "missing.wav", "resolution failed", "file does not exist"})

	expectFailure("corrupt-sounddata", function()
		sound.newSoundData("corrupt.wav")
	end, {"Love SoundData", "corrupt.wav", "decode failed", "SoLoud"})

	expectFailure("missing-decoder", function()
		sound.newDecoder("missing.wav")
	end, {"Love Decoder", "missing.wav", "resolution failed", "file does not exist"})

	expectFailure("corrupt-decoder", function()
		sound.newDecoder("corrupt.wav")
	end, {"Love Decoder", "corrupt.wav", "decode failed", "SoLoud"})

	expectFailure("missing-font", function()
		love.graphics.newFont("missing.ttf", 18)
	end, {"Love Font", "missing.ttf", "resolution failed", "file does not exist"})

	expectFailure("corrupt-font", function()
		love.graphics.newFont("corrupt.ttf", 18)
	end, {"Love Font", "corrupt.ttf", "FontCache", "format 'ttf'", "size 18", "LoveNode"})

	expectFailure("missing-audio", function()
		love.audio.newSource("missing.wav", "static")
	end, {"Love audio Source", "missing.wav", "static", "resolution failed", "file does not exist"})

	expectFailure("corrupt-audio", function()
		love.audio.newSource("corrupt.wav", "stream")
	end, {"Love audio Source", "corrupt.wav", "stream", "SoLoud", "format 'wav'", "LoveNode"})
end

local frames = 0
function love.update()
	frames = frames + 1
	if frames == 2 then
		assert(love.event.quit())
	end
end

function love.quit()
	print("LOVE_RESOURCE_FAILURE_RELEASE_PASS")
	return false
end
