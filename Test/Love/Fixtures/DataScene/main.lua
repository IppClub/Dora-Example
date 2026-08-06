local data = require("love.data")
local frames = 0

function love.load()
	local bytes = data.newByteData("Dora-Love-Data")
	local view = data.newDataView(bytes, 5, 4)
	assert(view:getString() == "Love")
	local viewClone = view:clone()
	bytes = nil
	view = nil
	collectgarbage("collect")
	assert(viewClone:getString() == "Love")

	local hex = data.encode("string", "hex", viewClone)
	local base64 = data.encode("string", "base64", viewClone)
	assert(hex == "4c6f7665" and base64 == "TG92ZQ==")
	assert(data.decode("string", "hex", hex) == "Love")
	assert(data.decode("string", "base64", base64) == "Love")

	local raw = string.rep("Dora-Love-Data-", 128)
	for _, format in ipairs({"zlib", "gzip", "deflate", "lz4"}) do
		local compressed = data.compress("data", format, raw, 9)
		assert(compressed:getFormat() == format)
		assert(data.decompress("string", compressed) == raw)
	end
	local sha256 = data.encode("string", "hex", data.hash("sha256", "abc"))
	assert(sha256 == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

	local packed = data.pack("data", "<I2c4", 0x1234, "Love")
	local number, text, nextPosition = data.unpack("<I2c4", packed)
	assert(number == 0x1234 and text == "Love" and nextPosition == 7)
	assert(packed:getSize() == data.getPackedSize("<I2c4"))

	local legacy = love.math.compress("data", "zlib", "legacy")
	assert(love.math.decompress("string", legacy) == "legacy")
	print("LOVE_DATA_CORE_PASS", viewClone:getSize(), hex, base64,
		packed:getSize(), legacy:getFormat(), sha256)
end

function love.update()
	frames = frames + 1
	if frames == 2 then love.event.quit() end
end

function love.quit()
	print("LOVE_DATA_RELEASE_PASS")
	return false
end
