-- Selected API assertions from love2d/love testing/ at commit
-- 357b005e5332d7fca847a40eac5b1d263e6e7398. The upstream suite identifies
-- itself as Love 12-oriented, so this fixture only carries assertions whose
-- APIs and expected values are also part of Love 11.5.

local cases = {}

local function add(module, name, test)
	cases[#cases + 1] = {module = module, name = name, test = test}
end

local function skip(module, name, reason)
	cases[#cases + 1] = {module = module, name = name, skip = reason}
end

local function skipMany(module, names, reason)
	for _, name in ipairs(names) do
		skip(module, name, reason)
	end
end

local function equal(actual, expected, label)
	assert(actual == expected,
		("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

add("data", "ByteData", function()
	local data = love.data.newByteData("helloworld")
	equal(data:getString(), "helloworld", "data string")
	equal(data:getSize(), 10, "data size")
	local clone = data:clone()
	assert(clone ~= data)
	equal(clone:getString(), "helloworld", "clone string")
	equal(clone:getSize(), 10, "clone size")
	assert(data:getFFIPointer() == nil)

	local released = love.data.newByteData("released")
	equal(released:type(), "ByteData", "object exact type")
	assert(released:typeOf("ByteData"))
	assert(released:typeOf("Data"))
	assert(released:typeOf("Object"))
	assert(not released:typeOf("ImageData"))
	local capturedGetSize = released.getSize
	assert(released:release())
	assert(not released:release())
	equal(released:type(), "ByteData", "released object type")
	assert(released:typeOf("Data"))
	local normalOk, normalError = pcall(function()
		released:getSize()
	end)
	assert(not normalOk)
	assert(tostring(normalError):find("Cannot use object after it has been released.", 1, true))
	local capturedOk, capturedError = pcall(capturedGetSize, released)
	assert(not capturedOk)
	assert(tostring(capturedError):find("Cannot use object after it has been released.", 1, true))
	local moduleOk, moduleError = pcall(love.data.encode, "string", "hex", released)
	assert(not moduleOk)
	assert(tostring(moduleError):find("Cannot use object after it has been released.", 1, true))
end)

add("data", "CompressedData", function()
	local compressed = love.data.compress("data", "zlib", "helloworld", -1)
	equal(compressed:getFormat(), "zlib", "compressed format")
	equal(love.data.decompress("data", compressed):getString(), "helloworld", "compressed round-trip")
	local clone = compressed:clone()
	assert(clone ~= compressed)
	equal(love.data.decompress("string", clone), "helloworld", "compressed clone")
end)

add("data", "compress/decompress", function()
	for _, format in ipairs({"lz4", "zlib", "gzip"}) do
		for _, level in ipairs({-1, 0, 9}) do
			local compressed = love.data.compress("string", format, "helloworld", level)
			equal(love.data.decompress("string", format, compressed), "helloworld",
				format .. " level " .. level)
		end
	end
end)

add("data", "encode/decode", function()
	for _, format in ipairs({"base64", "hex"}) do
		local encoded = love.data.encode("string", format, "helloworld", 0)
		equal(love.data.decode("string", format, encoded), "helloworld", format .. " string")
		local encodedData = love.data.encode("data", format, "helloworld", 0)
		equal(love.data.decode("data", format, encodedData):getString(), "helloworld", format .. " data")
	end
end)

add("data", "hash", function()
	local expected = {
		md5 = "fc5e038d38a57032085441e7fe7010b0",
		sha1 = "6adfb183a4a2c94a2f92dab5ade762a47889a5a1",
		sha224 = "b033d770602994efa135c5248af300d81567ad5b59cec4bccbf15bcc",
		sha256 = "936a185caaa266bb9cbe981e9e05cb78cd732b0b3280eb944412bb6f8f8f07af",
		sha384 = "97982a5b1414b9078103a1c008c4e3526c27b41cdbcf80790560a40f2a9bf2ed4427ab1428789915ed4b3dc07c454bd9",
		sha512 = "1594244d52f2d8c12b142bb61f47bc2eaf503d6d9ca8480cae9fcf112f66e4967dc5e8fa98285e36db8af1b8ffa8b84cb15e0fbcf836c3deb803c13f37659a60",
	}
	for algorithm, digest in pairs(expected) do
		equal(love.data.encode("string", "hex", love.data.hash(algorithm, "helloworld")),
			digest, algorithm)
	end
end)

add("data", "getPackedSize", function()
	equal(love.data.getPackedSize(">xI3b"), 5, "packed size 1")
	equal(love.data.getPackedSize(">I2B"), 3, "packed size 2")
	equal(love.data.getPackedSize(">I4I4I4I4x"), 17, "packed size 3")
end)

add("data", "pack/unpack", function()
	local packed = love.data.pack("string", ">s5s4I3", "hello", "love", 100)
	local a, b, c = love.data.unpack(">s5s4I3", packed)
	equal(a, "hello", "unpack string 1")
	equal(b, "love", "unpack string 2")
	equal(c, 100, "unpack integer")
	local packedData = love.data.pack("data", ">I4I4", 9999, 1000)
	local d, e = love.data.unpack(">I4I4", packedData)
	equal(d, 9999, "unpack data 1")
	equal(e, 1000, "unpack data 2")
end)

add("data", "newDataView", function()
	local parent = love.data.newByteData("helloworld")
	local view = love.data.newDataView(parent, 2, 5)
	assert(parent:release())
	equal(view:getString(), "llowo", "native view retains released parent")
	parent = nil
	collectgarbage("collect")
	equal(view:getString(), "llowo", "view keeps parent alive")
	equal(view:getSize(), 5, "view size")
end)

add("math", "colorFromBytes/colorToBytes", function()
	local r, g, b, a = love.math.colorFromBytes(51, 51, 51, 51)
	equal(r, 0.2, "color from bytes red")
	equal(g, 0.2, "color from bytes green")
	equal(b, 0.2, "color from bytes blue")
	equal(a, 0.2, "color from bytes alpha")
	r, g, b, a = love.math.colorToBytes(0.2, 0.2, 0.2, 0.2)
	equal(r, 51, "color to bytes red")
	equal(g, 51, "color to bytes green")
	equal(b, 51, "color to bytes blue")
	equal(a, 51, "color to bytes alpha")
end)

add("math", "RandomGenerator", function()
	local first = love.math.newRandomGenerator(3418323524, 20529293)
	local low, high = first:getSeed()
	equal(low, 3418323524, "seed low")
	equal(high, 20529293, "seed high")
	local second = love.math.newRandomGenerator(1448323524, 10329293)
	assert(first:random() ~= second:random())
	second:setState(first:getState())
	equal(first:random(), second:random(), "restored RNG state")
end)

add("math", "Transform", function()
	local transform = love.math.newTransform()
	transform:translate(10, 8)
	transform:scale(2, 3)
	transform:rotate(math.pi / 2)
	transform:shear(1, 2)
	local x, y = transform:transformPoint(1, 1)
	equal(math.floor(x + 0.5), 4, "transform x")
	equal(math.floor(y + 0.5), 14, "transform y")
	transform:reset()
	x, y = transform:transformPoint(1, 1)
	equal(x, 1, "reset x")
	equal(y, 1, "reset y")
	assert(transform:isAffine2DTransform())
end)

add("math", "BezierCurve", function()
	local curve = love.math.newBezierCurve(1, 1, 2, 2, 3, 1)
	equal(curve:getControlPointCount(), 3, "control point count")
	equal(curve:getDegree(), 2, "curve degree")
	local x = curve:evaluate(0.5)
	equal(x, 2, "curve evaluation")
	local derivative = curve:getDerivative()
	equal(derivative:getControlPointCount(), 2, "derivative control point count")
end)

add("math", "isConvex/triangulate", function()
	assert(love.math.isConvex({0, 0, 1, 0, 1, 1, 0, 1}))
	assert(not love.math.isConvex({1, 2, 2, 4, 3, 4, 2, 1, 3, 1}))
	local triangles = love.math.triangulate({0, 0, 1, 0, 1, 1, 0, 1})
	equal(#triangles, 2, "square triangles")
end)

add("math", "perlinNoise", function()
	local first = love.math.perlinNoise(0.125, 0.25, 0.5, 1)
	equal(first, love.math.perlinNoise(0.125, 0.25, 0.5, 1), "deterministic Perlin noise")
	assert(first >= 0 and first <= 1)
	assert(love.math.perlinNoise(0.125) ~= love.math.perlinNoise(0.25))
end)

add("math", "simplexNoise", function()
	for dimensions = 1, 4 do
		local coordinates = {0.125, 0.25, 0.5, 1}
		local value = love.math.simplexNoise(table.unpack(coordinates, 1, dimensions))
		assert(value >= 0 and value <= 1)
		equal(value, love.math.simplexNoise(table.unpack(coordinates, 1, dimensions)),
			"deterministic " .. dimensions .. "D simplex noise")
	end
	assert(love.math.simplexNoise(0.125, 0.25) ~= love.math.perlinNoise(0.125, 0.25))
end)

add("math", "random state", function()
	love.math.setRandomSeed(9001)
	local low, high = love.math.getRandomSeed()
	equal(low, 9001, "global seed low")
	equal(high, 0, "global seed high")
	local state = love.math.getRandomState()
	love.math.setRandomState(state)
	equal(love.math.getRandomState(), state, "global random state")
	for _ = 1, 10 do
		local value = love.math.random(5, 100)
		assert(value >= 5 and value <= 100)
	end
end)

add("event", "clear", function()
	for _ = 1, 3 do love.event.push("test", 1, 2, 3) end
	love.event.clear()
	local count = 0
	for _ in love.event.poll() do count = count + 1 end
	equal(count, 0, "cleared event count")
end)

add("event", "poll", function()
	for _ = 1, 3 do love.event.push("test", 1, 2, 3) end
	local count = 0
	for _ in love.event.poll() do count = count + 1 end
	equal(count, 3, "polled event count")
end)

skip("event", "pump", "upstream test marks pump as internally used and does not assert behavior")

add("event", "push", function()
	love.event.push("add", 1, 2, 3)
	love.event.push("ignore", 1, 2, 3)
	love.event.push("add", 1, 2, 3)
	love.event.push("ignore", 1, 2, 3)
	local total = 0
	for name, a, b, c in love.event.poll() do
		if name == "add" then total = total + a + b + c end
	end
	equal(total, 12, "pushed event values")
end)

add("event", "quit", function()
	assert(love.event.quit(0))
	local name, status = love.event.wait()
	equal(name, "quit", "quit event name")
	equal(status, 0, "quit event status")
	assert(love.event.quit("restart"))
	name, status = love.event.wait()
	equal(name, "quit", "restart event name")
	equal(status, "restart", "restart event status")
end)

skip("event", "wait", "upstream test marks wait as requiring additional test infrastructure")

add("timer", "getAverageDelta", function()
	assert(type(love.timer.getAverageDelta()) == "number")
end)

add("timer", "getDelta", function()
	assert(type(love.timer.getDelta()) == "number")
end)

add("timer", "getFPS", function()
	assert(type(love.timer.getFPS()) == "number")
end)

add("timer", "getTime", function()
	local started = love.timer.getTime()
	love.timer.sleep(1)
	equal(math.floor(love.timer.getTime() - started), 1, "one second elapsed")
end)

add("timer", "sleep", function()
	local started = love.timer.getTime()
	love.timer.sleep(1)
	equal(math.floor(love.timer.getTime() - started), 1, "one second slept")
end)

add("timer", "step", function()
	assert(type(love.timer.step()) == "number")
end)

add("system", "getClipboardText", function()
	love.system.setClipboardText("helloworld")
	equal(love.system.getClipboardText(), "helloworld", "clipboard text")
end)

add("system", "getOS", function()
	local allowed = {Windows = true, ["OS X"] = true, Linux = true, Android = true, iOS = true}
	assert(allowed[love.system.getOS()])
end)

add("system", "getPowerInfo", function()
	local allowed = {unknown = true, battery = true, nobattery = true, charging = true, charged = true}
	local state, percent, seconds = love.system.getPowerInfo()
	assert(allowed[state])
	if percent ~= nil then assert(percent >= 0 and percent <= 100) end
	if seconds ~= nil then assert(type(seconds) == "number") end
end)

add("system", "getProcessorCount", function()
	assert(love.system.getProcessorCount() >= 1)
end)

add("system", "hasBackgroundMusic", function()
	assert(type(love.system.hasBackgroundMusic()) == "boolean")
end)

skip("system", "openURL", "upstream test skips because external handler success cannot be asserted")

add("system", "setClipboardText", function()
	love.system.setClipboardText("helloworld")
	equal(love.system.getClipboardText(), "helloworld", "set clipboard text")
end)

skip("system", "vibrate", "upstream test skips because physical vibration cannot be asserted")

add("filesystem", "File", function()
	local file = love.filesystem.newFile("official-file.txt")
	assert(file:open("w"))
	assert(file:write("helloworld"))
	assert(file:close())
	assert(file:open("r"))
	equal(file:getMode(), "r", "File read mode")
	local contents, size = file:read()
	equal(contents, "helloworld", "File contents")
	equal(size, 10, "File size")
	equal(file:getSize(), 10, "File getSize")
	equal(file:getFilename(), "official-file.txt", "File filename")
	assert(file:seek(5) and file:tell() == 5)
	assert(file:close())
	assert(love.filesystem.remove("official-file.txt"))
end)

add("filesystem", "FileData", function()
	local data = love.filesystem.newFileData("helloworld", "test.txt")
	equal(data:getFilename(), "test.txt", "FileData filename")
	equal(data:getExtension(), "txt", "FileData extension")
	equal(data:getString(), "helloworld", "FileData string")
	equal(data:getSize(), 10, "FileData size")
	local clone = data:clone()
	assert(clone ~= data)
	equal(clone:getString(), "helloworld", "FileData clone")
end)

add("filesystem", "append", function()
	assert(love.filesystem.write("official-append.txt", "foo"))
	assert(love.filesystem.append("official-append.txt", "bar"))
	local contents, size = love.filesystem.read("official-append.txt")
	equal(contents, "foobar", "append contents")
	equal(size, 6, "append size")
	assert(love.filesystem.append("official-append.txt", "foobarfoobarfoo", 6))
	contents, size = love.filesystem.read("official-append.txt")
	equal(contents, "foobarfoobar", "partial append contents")
	equal(size, 12, "partial append size")
	assert(love.filesystem.remove("official-append.txt"))
end)

skip("filesystem", "areSymlinksEnabled",
	"embedded Content-only mode does not expose the host symlink switch")

add("filesystem", "createDirectory", function()
	assert(love.filesystem.createDirectory("official-dir/nested"))
	assert(love.filesystem.getInfo("official-dir", "directory"))
	assert(love.filesystem.getInfo("official-dir/nested", "directory"))
	assert(love.filesystem.remove("official-dir/nested"))
	assert(love.filesystem.remove("official-dir"))
end)

add("filesystem", "getAppdataDirectory", function()
	assert(#love.filesystem.getAppdataDirectory() > 0)
end)

skip("filesystem", "getCRequirePath",
	"native Lua modules are intentionally unavailable in the isolated Lua 5.5 state")

add("filesystem", "getDirectoryItems", function()
	assert(love.filesystem.createDirectory("official-items/nested"))
	assert(love.filesystem.write("official-items/file.txt", "file"))
	local foundFile, foundDirectory = false, false
	for _, item in ipairs(love.filesystem.getDirectoryItems("official-items")) do
		local info = love.filesystem.getInfo("official-items/" .. item)
		if item == "file.txt" and info.type == "file" then foundFile = true end
		if item == "nested" and info.type == "directory" then foundDirectory = true end
	end
	assert(foundFile and foundDirectory)
	assert(love.filesystem.remove("official-items/file.txt"))
	assert(love.filesystem.remove("official-items/nested"))
	assert(love.filesystem.remove("official-items"))
end)

add("filesystem", "getExecutablePath", function()
	assert(type(love.filesystem.getExecutablePath()) == "string")
	assert(#love.filesystem.getExecutablePath() > 0)
end)

add("filesystem", "getIdentity", function()
	assert(type(love.filesystem.getIdentity()) == "string")
end)

add("filesystem", "getRealDirectory", function()
	assert(love.filesystem.write("official-real.txt", "test"))
	equal(love.filesystem.getRealDirectory("official-real.txt"),
		love.filesystem.getSaveDirectory(), "real directory")
	assert(love.filesystem.remove("official-real.txt"))
end)

add("filesystem", "getRequirePath", function()
	equal(love.filesystem.getRequirePath(), "?.lua;?/init.lua", "default require path")
end)

skip("filesystem", "getSource", "upstream test marks getSource as internally established")

add("filesystem", "getSourceBaseDirectory", function()
	assert(#love.filesystem.getSourceBaseDirectory() > 0)
end)

add("filesystem", "getUserDirectory", function()
	assert(#love.filesystem.getUserDirectory() > 0)
end)

add("filesystem", "getWorkingDirectory", function()
	equal(love.filesystem.getWorkingDirectory(), love.filesystem.getSource(), "working directory")
end)

add("filesystem", "getSaveDirectory", function()
	assert(#love.filesystem.getSaveDirectory() > 0)
end)

add("filesystem", "getInfo", function()
	assert(love.filesystem.createDirectory("official-info"))
	assert(love.filesystem.write("official-info/file.txt", "file2"))
	assert(love.filesystem.getInfo("official-info/file.txt", "directory") == nil)
	local info = love.filesystem.getInfo("official-info/file.txt", "file")
	assert(info and info.type == "file")
	equal(info.size, 5, "getInfo size")
	assert(love.filesystem.remove("official-info/file.txt"))
	assert(love.filesystem.remove("official-info"))
end)

add("filesystem", "isFused", function()
	equal(love.filesystem.isFused(), false, "embedded runtime is not fused")
end)

add("filesystem", "lines", function()
	assert(love.filesystem.write("official-lines.txt", "line1\nline2\nline3"))
	local lines = {}
	for line in love.filesystem.lines("official-lines.txt") do lines[#lines + 1] = line end
	equal(#lines, 3, "line count")
	for index, line in ipairs(lines) do equal(line, "line" .. index, "line " .. index) end
	assert(love.filesystem.remove("official-lines.txt"))
end)

add("filesystem", "load", function()
	assert(love.filesystem.write("official-valid.lua", "return 1"))
	assert(love.filesystem.write("official-invalid.lua", "local ="))
	local chunk, message = love.filesystem.load("official-missing.lua")
	assert(chunk == nil and type(message) == "string")
	chunk, message = love.filesystem.load("official-valid.lua")
	assert(chunk and message == nil)
	equal(chunk(), 1, "loaded chunk result")
	chunk, message = love.filesystem.load("official-invalid.lua")
	assert(chunk == nil and type(message) == "string")
	assert(love.filesystem.remove("official-valid.lua"))
	assert(love.filesystem.remove("official-invalid.lua"))
end)

add("filesystem", "mount", function()
	assert(love.filesystem.write("official-mount.zip", "inside/test.txt:helloworld"))
	assert(love.filesystem.mount("official-mount.zip", "official-mount"))
	equal(love.filesystem.read("official-mount/inside/test.txt"), "helloworld", "mounted file")
	assert(love.filesystem.unmount("official-mount.zip"))
	assert(love.filesystem.remove("official-mount.zip"))
end)

add("filesystem", "openFile", function()
	local file, message = love.filesystem.openFile("official-open.txt", "w")
	assert(file and message == nil and file:isOpen())
	assert(file:write("opened"))
	assert(file:close())
	file, message = love.filesystem.openFile("official-open.txt", "r")
	assert(file and message == nil and file:read() == "opened")
	assert(file:close())
	file, message = love.filesystem.openFile("official-missing.txt", "r")
	assert(file == nil and type(message) == "string")
	assert(love.filesystem.remove("official-open.txt"))
end)

add("filesystem", "newFileData", function()
	local data = love.filesystem.newFileData("helloworld", "file1")
	equal(data:getString(), "helloworld", "newFileData string")
end)

add("filesystem", "read", function()
	assert(love.filesystem.write("official-read.txt", "helloworld"))
	local content, size = love.filesystem.read("official-read.txt")
	equal(content, "helloworld", "full read")
	equal(size, 10, "full read size")
	content, size = love.filesystem.read("official-read.txt", 5)
	equal(content, "hello", "partial read")
	equal(size, 5, "partial read size")
	assert(love.filesystem.remove("official-read.txt"))
end)

add("filesystem", "remove", function()
	assert(love.filesystem.createDirectory("official-remove/nested"))
	assert(love.filesystem.write("official-remove/nested/file.txt", "helloworld"))
	assert(not love.filesystem.remove("official-remove"))
	assert(not love.filesystem.remove("official-remove/nested"))
	assert(love.filesystem.remove("official-remove/nested/file.txt"))
	assert(love.filesystem.remove("official-remove/nested"))
	assert(love.filesystem.remove("official-remove"))
end)

skip("filesystem", "setCRequirePath",
	"native Lua modules are intentionally unavailable in the isolated Lua 5.5 state")

add("filesystem", "setIdentity", function()
	local original = love.filesystem.getIdentity()
	love.filesystem.setIdentity("official-compat")
	equal(love.filesystem.getIdentity(), "official-compat", "set identity")
	love.filesystem.setIdentity(original)
	equal(love.filesystem.getIdentity(), original, "restore identity")
end)

add("filesystem", "setRequirePath", function()
	love.filesystem.setRequirePath("?.lua;?/start.lua")
	equal(love.filesystem.getRequirePath(), "?.lua;?/start.lua", "set require path")
	love.filesystem.setRequirePath("?.lua;?/init.lua")
end)

skip("filesystem", "setSource", "upstream test marks source configuration as internally established")

add("filesystem", "unmount", function()
	assert(love.filesystem.write("official-unmount.zip", "test.txt:helloworld"))
	assert(love.filesystem.mount("official-unmount.zip", "official-unmount"))
	assert(love.filesystem.getInfo("official-unmount/test.txt", "file"))
	assert(love.filesystem.unmount("official-unmount.zip"))
	assert(love.filesystem.getInfo("official-unmount/test.txt") == nil)
	assert(love.filesystem.remove("official-unmount.zip"))
end)

add("filesystem", "write", function()
	assert(love.filesystem.write("official-write-1.txt", "helloworld"))
	assert(love.filesystem.write("official-write-2.txt", "helloworld", 5))
	equal(love.filesystem.read("official-write-1.txt"), "helloworld", "write full")
	equal(love.filesystem.read("official-write-2.txt"), "hello", "write partial")
	assert(love.filesystem.remove("official-write-1.txt"))
	assert(love.filesystem.remove("official-write-2.txt"))
end)

add("image", "CompressedImageData", function()
	local encoded = love.filesystem.newFileData("compressed-image", "official.dds")
	local data = love.image.newCompressedData(encoded)
	assert(data:type() == "CompressedImageData" and data:typeOf("Data") and data:typeOf("Object"))
	equal(data:getFormat(), "DXT1", "CompressedImageData format")
	equal(data:getMipmapCount(), 3, "CompressedImageData mipmap count")
	local width, height = data:getDimensions()
	equal(width, 4, "CompressedImageData base width")
	equal(height, 4, "CompressedImageData base height")
	width, height = data:getDimensions(2)
	equal(width, 2, "CompressedImageData mip width")
	equal(height, 2, "CompressedImageData mip height")
	equal(data:getSize(), 24, "CompressedImageData byte size")
	local clone = data:clone()
	equal(clone:getString(), data:getString(), "CompressedImageData clone bytes")
end)

add("image", "ImageData", function()
	assert(love.filesystem.write("official-image.mock", "encoded-image"))
	local data = love.image.newImageData("official-image.mock")
	local width, height = data:getDimensions()
	equal(width, 2, "ImageData width")
	equal(height, 1, "ImageData height")
	equal(data:getFormat(), "rgba8", "ImageData format")
	equal(data:getSize(), 8, "ImageData byte size")
	local red, green, blue, alpha = data:getPixel(0, 0)
	equal(red, 1, "decoded red")
	equal(green, 0, "decoded green")
	equal(blue, 0, "decoded blue")
	equal(alpha, 1, "decoded alpha")
	data:mapPixel(function(_, _, r, g, b, a) return 1 - r, 1 - g, 1 - b, a end)
	red, green, blue = data:getPixel(0, 0)
	equal(red + green + blue, 2, "mapped pixel")
	local patch = love.image.newImageData(1, 1, "rgba8")
	patch:setPixel(0, 0, 1, 0, 0, 1)
	data:paste(patch, 1, 0, 0, 0, 1, 1)
	red, green, blue = data:getPixel(1, 0)
	equal(red + green + blue, 1, "pasted pixel")
	local encoded = data:encode("png", "official-encoded.png")
	assert(encoded and love.filesystem.getInfo("official-encoded.png", "file"))
	assert(love.filesystem.remove("official-image.mock"))
	assert(love.filesystem.remove("official-encoded.png"))
end)

add("image", "isCompressed", function()
	assert(love.image.isCompressed(love.filesystem.newFileData("compressed-image", "official.dds")))
	assert(not love.image.isCompressed(love.filesystem.newFileData("encoded-image", "official.png")))
end)

add("image", "newCompressedData", function()
	local data = love.image.newCompressedData(
		love.filesystem.newFileData("compressed-image", "official.dds"))
	assert(data and data:getWidth() == 4 and data:getHeight(2) == 2)
end)

add("image", "newImageData", function()
	local data = love.image.newImageData(16, 16, "rgba8")
	equal(data:getWidth(), 16, "newImageData width")
	equal(data:getHeight(), 16, "newImageData height")
	equal(data:getSize(), 1024, "newImageData size")
end)

add("sound", "Decoder", function()
	local encoded = love.filesystem.newFileData("encoded-sound", "official-sound.wav")
	local decoder = love.sound.newDecoder(encoded, 4)
	equal(decoder:getBitDepth(), 16, "Decoder bit depth")
	equal(decoder:getChannelCount(), 2, "Decoder channels")
	equal(decoder:getSampleRate(), 22050, "Decoder sample rate")
	equal(decoder:getDuration(), 2 / 22050, "Decoder duration")
	local first = decoder:decode()
	assert(first and first:getSampleCount() == 1)
	local clone = decoder:clone()
	local cloneFirst = clone:decode()
	assert(cloneFirst and cloneFirst:getSampleCount() == 1)
end)

add("sound", "SoundData", function()
	local encoded = love.filesystem.newFileData("encoded-sound", "official-sound.wav")
	local data = love.sound.newSoundData(encoded)
	equal(data:getBitDepth(), 16, "SoundData bit depth")
	equal(data:getChannelCount(), 2, "SoundData channels")
	equal(data:getSampleRate(), 22050, "SoundData sample rate")
	equal(data:getSampleCount(), 2, "SoundData sample count")
	equal(data:getSize(), 8, "SoundData size")
	equal(data:getSample(0, 1), 1, "SoundData first sample")
	equal(data:getSample(0, 2), -1, "SoundData second channel")
	local clone = data:clone()
	clone:setSample(0, 1, 0)
	equal(data:getSample(0, 1), 1, "SoundData clone isolation")
end)

add("sound", "newDecoder", function()
	local encoded = love.filesystem.newFileData("encoded-sound", "official-decoder.wav")
	assert(love.sound.newDecoder(encoded))
end)

add("sound", "newSoundData", function()
	local encoded = love.filesystem.newFileData("encoded-sound", "official-data.wav")
	assert(love.sound.newSoundData(encoded))
	local blank = love.sound.newSoundData(math.floor((1 / 32) * 44100), 44100, 16, 1)
	assert(blank and blank:getSampleCount() == math.floor((1 / 32) * 44100))
end)

add("audio", "RecordingDevice", function()
	local device = assert(love.audio.getRecordingDevices()[1])
	equal(device:type(), "RecordingDevice", "recording object type")
	assert(device:typeOf("Object") and not device:isRecording())
	assert(device:start(4, 16000, 8, 2))
	equal(device:getSampleCount(), 4, "captured sample count")
	local data = assert(device:stop())
	equal(data:getSampleCount(), 4, "recorded SoundData samples")
	equal(data:getSampleRate(), 16000, "recorded SoundData rate")
	equal(data:getBitDepth(), 8, "recorded SoundData depth")
	equal(data:getChannelCount(), 2, "recorded SoundData channels")
	assert(not device:isRecording())
end)
skip("audio", "Source",
	"upstream aggregate is not a standalone deterministic test; Source filters and effects are covered independently")
add("audio", "getActiveEffects", function()
	assert(love.audio.setEffect("official-active", {type = "echo", delay = 0.1}))
	local effects = love.audio.getActiveEffects()
	equal(#effects, 1, "active effect count")
	equal(effects[1], "official-active", "active effect name")
	assert(love.audio.setEffect("official-active", false))
end)
add("audio", "getActiveSourceCount", function()
	local first = love.audio.newSource("sound.mock", "static")
	local second = love.audio.newSource("sound.mock", "stream")
	equal(love.audio.getActiveSourceCount(), 0, "inactive Sources are not counted")
	assert(first:play() and second:play())
	equal(love.audio.getActiveSourceCount(), 2, "playing Sources are counted")
	first:pause()
	equal(love.audio.getActiveSourceCount(), 2, "paused Sources remain active")
	second:stop()
	equal(love.audio.getActiveSourceCount(), 1, "stopped Sources are removed")
	first:stop()
	equal(love.audio.getActiveSourceCount(), 0, "all Sources stopped")
end)
add("audio", "getSourceCount", function()
	local source = love.audio.newSource("sound.mock", "static")
	equal(love.audio.getSourceCount(), 0, "deprecated count excludes inactive Sources")
	assert(source:play())
	equal(love.audio.getSourceCount(), 1, "deprecated count includes active Sources")
	source:stop()
	equal(love.audio.getSourceCount(), 0, "deprecated count excludes stopped Sources")
end)
add("audio", "getDistanceModel", function()
	love.audio.setDistanceModel("linearclamped")
	equal(love.audio.getDistanceModel(), "linearclamped", "application-global distance model")
end)
add("audio", "getDopplerScale", function()
	love.audio.setDopplerScale(2.5)
	equal(love.audio.getDopplerScale(), 2.5, "application-global Doppler scale")
end)
add("audio", "getEffect", function()
	assert(love.audio.setEffect("official-get", {type = "reverb", decaytime = 2, highlimit = true}))
	local target = {marker = true}
	local result = love.audio.getEffect("official-get", target)
	assert(result == target and result.marker and result.type == "reverb" and result.highlimit)
	equal(result.decaytime, 2, "effect setting round-trip")
	assert(love.audio.setEffect("official-get", false))
	assert(love.audio.getEffect("official-get") == nil)
end)
add("audio", "getMaxSceneEffects", function()
	equal(love.audio.getMaxSceneEffects(), 64, "Dora LoveNode named effect limit")
end)
add("audio", "getMaxSourceEffects", function()
	equal(love.audio.getMaxSourceEffects(), 3, "SoLoud per-Source effect slot limit")
end)
add("audio", "getOrientation", function()
	love.audio.setOrientation(1, 2, 3, 4, 5, 6)
	local fx, fy, fz, ux, uy, uz = love.audio.getOrientation()
	equal(fx, 1); equal(fy, 2); equal(fz, 3); equal(ux, 4); equal(uy, 5); equal(uz, 6)
end)
add("audio", "getPosition", function()
	love.audio.setPosition(1, 2, 3)
	local x, y, z = love.audio.getPosition()
	equal(x, 1); equal(y, 2); equal(z, 3)
end)
add("audio", "getRecordingDevices", function()
	local devices = love.audio.getRecordingDevices()
	equal(#devices, 2, "recording device count")
	equal(devices[1]:getName(), "Default Microphone", "default recording device")
	assert(devices[1] == love.audio.getRecordingDevices()[1])
end)
add("audio", "getVelocity", function()
	love.audio.setVelocity(4, 5, 6)
	local x, y, z = love.audio.getVelocity()
	equal(x, 4); equal(y, 5); equal(z, 6)
end)

add("audio", "getVolume", function()
	love.audio.setVolume(0.5)
	equal(love.audio.getVolume(), 0.5, "instance audio volume")
end)

add("audio", "isEffectsSupported", function()
	assert(love.audio.isEffectsSupported())
end)
add("audio", "newQueueableSource", function()
	local source = love.audio.newQueueableSource(8000, 16, 1, 2)
	local pcm = love.sound.newSoundData(4, 8000, 16, 1)
	equal(source:getType(), "queue", "queueable Source type")
	equal(source:getFreeBufferCount(), 2, "queue buffer capacity")
	assert(source:queue(pcm))
	equal(source:getFreeBufferCount(), 1, "queued buffer consumes one slot")
	equal(source:getDuration("samples"), 4, "queued sample duration")
	local clone = source:clone()
	equal(clone:getType(), "queue", "queue clone type")
	equal(clone:getFreeBufferCount(), 2, "queue clone starts empty")
	equal(clone:getDuration("samples"), 0, "queue clone does not copy PCM")
	source:stop()
	equal(source:getFreeBufferCount(), 2, "stop releases queued buffers")
end)

add("audio", "newSource", function()
	local static = love.audio.newSource("sound.mock", "static")
	local stream = love.audio.newSource("sound.mock", "stream")
	equal(static:getType(), "static", "static Source type")
	equal(stream:getType(), "stream", "stream Source type")
	assert(static ~= stream)
end)

add("audio", "pause", function()
	local first = love.audio.newSource("sound.mock", "static")
	local second = love.audio.newSource("sound.mock", "stream")
	assert(love.audio.play({first, second}))
	local paused = love.audio.pause()
	equal(#paused, 2, "pause-all result count")
	local found = {}
	for _, source in ipairs(paused) do found[source] = true end
	assert(found[first] and found[second])
	assert(first:isPaused() and second:isPaused())
	equal(#love.audio.pause(), 0, "already paused Sources are not returned again")
end)

add("audio", "play", function()
	local source = love.audio.newSource("sound.mock", "static")
	assert(love.audio.play(source))
	assert(source:isPlaying())
	source:pause()
	assert(source:isPaused() and not source:isPlaying())
end)

add("audio", "setDistanceModel", function()
	local models = {"none", "inverse", "inverseclamped", "linear", "linearclamped", "exponent", "exponentclamped"}
	for _, model in ipairs(models) do
		love.audio.setDistanceModel(model)
		equal(love.audio.getDistanceModel(), model, "distance model round-trip")
	end
end)
add("audio", "setDopplerScale", function()
	love.audio.setDopplerScale(0)
	equal(love.audio.getDopplerScale(), 0, "zero disables Doppler")
	love.audio.setDopplerScale(-1)
	equal(love.audio.getDopplerScale(), 0, "negative scale is ignored by Love")
end)
add("audio", "setEffect", function()
	assert(love.audio.setEffect("official-set", {type = "distortion", volume = 0.75, edge = 0.5}))
	local settings = assert(love.audio.getEffect("official-set"))
	equal(settings.type, "distortion", "effect type")
	equal(settings.edge, 0.5, "effect parameter")
	assert(love.audio.setEffect("official-set", nil))
end)
add("audio", "setMixWithSystem", function()
	assert(type(love.audio.setMixWithSystem(true)) == "boolean")
	assert(type(love.audio.setMixWithSystem(false)) == "boolean")
end)
add("audio", "setOrientation", function()
	love.audio.setOrientation(-1, 0, 0, 0, 1, 0)
	local fx, fy, fz, ux, uy, uz = love.audio.getOrientation()
	equal(fx, -1); equal(fy, 0); equal(fz, 0); equal(ux, 0); equal(uy, 1); equal(uz, 0)
end)
add("audio", "setPosition", function()
	love.audio.setPosition(7, 8)
	local x, y, z = love.audio.getPosition()
	equal(x, 7); equal(y, 8); equal(z, 0)
end)
add("audio", "setVelocity", function()
	love.audio.setVelocity(9, 10)
	local x, y, z = love.audio.getVelocity()
	equal(x, 9); equal(y, 10); equal(z, 0)
end)

add("audio", "setVolume", function()
	love.audio.setVolume(0.25)
	equal(love.audio.getVolume(), 0.25, "set instance volume")
end)

add("audio", "stop", function()
	local source = love.audio.newSource("sound.mock", "static")
	assert(love.audio.play(source) and source:isPlaying())
	love.audio.stop()
	assert(not source:isPlaying() and not source:isPaused())
end)

add("font", "GlyphData", function()
	local image = love.image.newImageData(3, 1)
	image:setPixel(1, 0, 1, 1, 1, 1)
	local rasterizer = love.font.newImageRasterizer(image, "A")
	local glyph = love.font.newGlyphData(rasterizer, "A")
	assert(glyph:typeOf("GlyphData") and glyph:typeOf("Data"))
	equal(glyph:getGlyph(), 65, "GlyphData codepoint")
	equal(glyph:getGlyphString(), "A", "GlyphData string")
	equal(glyph:getWidth(), 1, "GlyphData width")
end)

add("font", "Rasterizer", function()
	local image = love.image.newImageData(3, 1)
	image:setPixel(1, 0, 1, 1, 1, 1)
	local rasterizer = love.font.newImageRasterizer(image, "A")
	assert(rasterizer:typeOf("Rasterizer") and rasterizer:hasGlyphs("A"))
	equal(rasterizer:getGlyphCount(), 1, "Rasterizer glyph count")
end)
add("font", "newBMFontRasterizer", function()
	local image = love.image.newImageData(2, 1)
	image:setPixel(0, 0, 1, 1, 1, 1)
	local descriptor = table.concat({
		"info size=12 unicode=1",
		"common lineHeight=1 base=1 pages=1",
		"page id=0 file=\"fixture.png\"",
		"char id=65 x=0 y=0 width=1 height=1 xadvance=2 page=0",
	}, "\n")
	local file = love.filesystem.newFileData(descriptor, "fixture.fnt")
	local rasterizer = love.font.newBMFontRasterizer(file, image)
	assert(rasterizer:typeOf("Rasterizer") and rasterizer:hasGlyphs("A"))
	equal(rasterizer:getGlyphData("A"):getAdvance(), 2, "BMFont advance")
end)
add("font", "newGlyphData", function()
	local image = love.image.newImageData(3, 1)
	image:setPixel(1, 0, 1, 1, 1, 1)
	local rasterizer = love.font.newImageRasterizer(image, "A")
	equal(love.font.newGlyphData(rasterizer, 65):getGlyphString(), "A", "numeric glyph")
end)
add("font", "newImageRasterizer", function()
	local image = love.image.newImageData(4, 2)
	image:setPixel(1, 0, 1, 1, 1, 1)
	image:setPixel(1, 1, 1, 1, 1, 1)
	local rasterizer = love.font.newImageRasterizer(image, "A", 2, 1)
	local glyph = rasterizer:getGlyphData("A")
	equal(glyph:getAdvance(), 3, "image-font extra spacing")
	equal(glyph:getSize(), 8, "image-font RGBA bytes")
end)
add("font", "newRasterizer", function()
	local rasterizer = love.font.newRasterizer(14, "none", 1)
	assert(rasterizer:typeOf("Rasterizer") and rasterizer:hasGlyphs("Love"))
end)
add("font", "newTrueTypeRasterizer", function()
	local rasterizer = love.font.newTrueTypeRasterizer(14, "normal", 1)
	local glyph = rasterizer:getGlyphData("A")
	assert(glyph:typeOf("GlyphData") and glyph:getFormat() == "la8")
	assert(glyph:getWidth() > 0 and glyph:getSize() == glyph:getWidth() * glyph:getHeight() * 2)
end)

skip("physics", "Body", "upstream test marks the Body object test as not written")
skip("physics", "Contact", "upstream test marks the Contact object test as not written")
skip("physics", "Fixture", "upstream test marks the Fixture object test as not written")
skip("physics", "Joint", "upstream test marks the Joint object test as not written")
skip("physics", "Shape", "upstream test marks the Shape object test as not written")
skip("physics", "World", "upstream test marks the World object test as not written")
add("physics", "getDistance", function()
	local world = love.physics.newWorld()
	local body1 = love.physics.newBody(world, 0, 0, "static")
	local body2 = love.physics.newBody(world, 10, 0, "static")
	local fixture1 = love.physics.newFixture(body1, love.physics.newCircleShape(2))
	local fixture2 = love.physics.newFixture(body2, love.physics.newCircleShape(3))
	local distance, x1, y1, x2, y2 = love.physics.getDistance(fixture1, fixture2)
	equal(distance, 5, "fixture distance")
	equal(x1, 2, "first fixture closest x")
	equal(y1, 0, "first fixture closest y")
	equal(x2, 7, "second fixture closest x")
	equal(y2, 0, "second fixture closest y")
end)

add("physics", "getMeter", function()
	love.physics.setMeter(30)
	equal(love.physics.getMeter(), 30, "physics meter")
end)

add("physics", "newBody", function()
	local world = love.physics.newWorld(1, 1, true)
	local body = love.physics.newBody(world, 10, 10, "static")
	equal(body:getType(), "static", "Body type")
end)

add("physics", "newChainShape", function()
	local shape = love.physics.newChainShape(true, 0, 0, 1, 0, 1, 1, 0, 1)
	equal(shape:getType(), "chain", "ChainShape type")
end)

add("physics", "newCircleShape", function()
	local shape = love.physics.newCircleShape(10)
	equal(shape:getType(), "circle", "CircleShape type")
end)

local function jointBodies()
	local world = love.physics.newWorld(0, 0, true)
	return world,
		love.physics.newBody(world, 10, 10, "dynamic"),
		love.physics.newBody(world, 20, 20, "dynamic")
end

add("physics", "newDistanceJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newDistanceJoint(first, second, 10, 10, 20, 20, true):getType(),
		"distance", "DistanceJoint type")
end)

add("physics", "newEdgeShape", function()
	equal(love.physics.newEdgeShape(0, 0, 10, 10):getType(), "edge", "EdgeShape type")
end)

add("physics", "newFixture", function()
	local world = love.physics.newWorld(0, 0, true)
	local body = love.physics.newBody(world, 10, 10, "static")
	local fixture = love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
	equal(fixture:getDensity(), 1, "Fixture density")
end)

add("physics", "newFrictionJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newFrictionJoint(first, second, 15, 15, true):getType(),
		"friction", "FrictionJoint type")
end)

add("physics", "newGearJoint", function()
	local world = love.physics.newWorld(0, 0, true)
	local groundA = love.physics.newBody(world, 0, 0, "static")
	local bodyA = love.physics.newBody(world, 10, 0, "dynamic")
	local groundB = love.physics.newBody(world, 20, 0, "static")
	local bodyB = love.physics.newBody(world, 30, 0, "dynamic")
	local revolute = love.physics.newRevoluteJoint(groundA, bodyA, 10, 0, false)
	local prismatic = love.physics.newPrismaticJoint(groundB, bodyB, 30, 0, 1, 0, false)
	equal(love.physics.newGearJoint(revolute, prismatic, 1, true):getType(),
		"gear", "GearJoint type")
end)

add("physics", "newMotorJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newMotorJoint(first, second, 0.3):getType(), "motor", "MotorJoint type")
end)

add("physics", "newMouseJoint", function()
	local world = love.physics.newWorld(0, 0, true)
	local body = love.physics.newBody(world, 10, 10, "dynamic")
	equal(love.physics.newMouseJoint(body, 10, 10):getType(), "mouse", "MouseJoint type")
end)

add("physics", "newPolygonShape", function()
	equal(love.physics.newPolygonShape(0, 0, 2, 0, 2, 2, 0, 2):getType(),
		"polygon", "PolygonShape type")
end)

add("physics", "newPrismaticJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newPrismaticJoint(first, second, 10, 10, 1, 0, true):getType(),
		"prismatic", "PrismaticJoint type")
end)

add("physics", "newPulleyJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newPulleyJoint(first, second, 0, 0, 30, 0, 10, 10, 20, 20, 1, true):getType(),
		"pulley", "PulleyJoint type")
end)

add("physics", "newRectangleShape", function()
	local first = love.physics.newRectangleShape(10, 20)
	local second = love.physics.newRectangleShape(10, 10, 40, 30, 0.1)
	equal(first:getType(), "polygon", "RectangleShape type")
	equal(second:getType(), "polygon", "offset RectangleShape type")
end)

add("physics", "newRevoluteJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newRevoluteJoint(first, second, 10, 10, true):getType(),
		"revolute", "RevoluteJoint type")
end)

add("physics", "newRopeJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newRopeJoint(first, second, 10, 10, 20, 20, 50, true):getType(),
		"rope", "RopeJoint type")
end)

add("physics", "newWeldJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newWeldJoint(first, second, 10, 10, true):getType(),
		"weld", "WeldJoint type")
end)

add("physics", "newWheelJoint", function()
	local _, first, second = jointBodies()
	equal(love.physics.newWheelJoint(first, second, 10, 10, 1, 0, true):getType(),
		"wheel", "WheelJoint type")
end)

add("physics", "newWorld", function()
	local world = love.physics.newWorld(1, 1, true)
	local gx, gy = world:getGravity()
	equal(gx, 1, "World gravity x")
	equal(gy, 1, "World gravity y")
end)

add("physics", "setMeter", function()
	love.physics.setMeter(30)
	local world = love.physics.newWorld(0, 0, true)
	local body = love.physics.newBody(world, 300, 300, "dynamic")
	love.physics.setMeter(10)
	local x, y = body:getPosition()
	equal(x, 100, "meter-scaled Body x")
	equal(y, 100, "meter-scaled Body y")
end)

skip("window", "close", "embedded LoveNode surfaces do not own or close the Dora host window")
skip("window", "maximize", "embedded LoveNode surfaces cannot maximize the Dora host window")
skip("window", "minimize", "embedded LoveNode surfaces cannot minimize the Dora host window")
skip("window", "requestAttention", "upstream test cannot assert the host side effect and LoveNode does not own it")
skip("window", "restore", "embedded LoveNode surfaces cannot restore the Dora host window")
skip("window", "setIcon", "embedded LoveNode surfaces do not own a host window icon")
skip("window", "setPosition", "embedded LoveNode surfaces are positioned by the Dora scene graph")
skip("window", "showMessageBox", "upstream test skips the blocking host dialog side effect")

add("window", "getDesktopDimensions", function()
	assert(love.window.setMode(360, 240))
	local width, height = love.window.getDesktopDimensions()
	equal(width, 360, "virtual desktop width")
	equal(height, 240, "virtual desktop height")
	assert(not pcall(love.window.getDesktopDimensions, 2))
end)

add("window", "getDisplayCount", function()
	equal(love.window.getDisplayCount(), 1, "single virtual display")
end)

add("window", "getDisplayName", function()
	equal(love.window.getDisplayName(1), "Dora LoveNode", "virtual display name")
	assert(not pcall(love.window.getDisplayName, 2))
end)

add("window", "getDisplayOrientation", function()
	equal(love.window.getDisplayOrientation(), "landscape", "virtual display orientation")
end)

add("window", "getFullscreen", function()
	local fullscreen, kind = love.window.getFullscreen()
	assert(not fullscreen)
	equal(kind, "desktop", "embedded fullscreen kind")
end)

add("window", "getFullscreenModes", function()
	equal(#love.window.getFullscreenModes(1), 0, "no host fullscreen modes")
end)

add("window", "setFullscreen", function()
	assert(love.window.setFullscreen(false))
	assert(not love.window.setFullscreen(true, "desktop"))
	assert(not love.window.setFullscreen(true, "exclusive"))
	assert(not pcall(love.window.setFullscreen, true, "invalid"))
end)

add("window", "getIcon", function()
	equal(love.window.getIcon(), nil, "virtual surface icon")
end)

add("window", "getPosition", function()
	local x, y, display = love.window.getPosition()
	equal(x, 0, "virtual position x")
	equal(y, 0, "virtual position y")
	equal(display, 1, "virtual position display")
end)

add("window", "getSafeArea", function()
	local x, y, width, height = love.window.getSafeArea()
	equal(x, 0, "safe area x")
	equal(y, 0, "safe area y")
	equal(width, 360, "safe area width")
	equal(height, 240, "safe area height")
end)

add("window", "getTitle", function()
	equal(love.window.getTitle(), "Untitled", "default virtual title")
end)

add("window", "setTitle", function()
	love.window.setTitle("Official virtual title")
	equal(love.window.getTitle(), "Official virtual title", "changed virtual title")
end)

add("window", "getVSync", function()
	equal(love.window.getVSync(), 1, "default virtual VSync request")
end)

add("window", "setVSync", function()
	love.window.setVSync(false)
	equal(love.window.getVSync(), 0, "disabled virtual VSync request")
	love.window.setVSync(-1)
	equal(love.window.getVSync(), -1, "adaptive virtual VSync request")
	assert(not pcall(love.window.setVSync, 2))
	love.window.setVSync(true)
end)

add("window", "hasFocus", function()
	assert(love.window.hasFocus())
end)

add("window", "hasMouseFocus", function()
	assert(love.window.hasMouseFocus())
end)

add("window", "isDisplaySleepEnabled", function()
	assert(not love.window.isDisplaySleepEnabled())
end)

add("window", "setDisplaySleepEnabled", function()
	love.window.setDisplaySleepEnabled(true)
	assert(love.window.isDisplaySleepEnabled())
	love.window.setDisplaySleepEnabled(false)
	assert(not pcall(love.window.setDisplaySleepEnabled, 1))
end)

add("window", "isMaximized", function()
	assert(not love.window.isMaximized())
end)

add("window", "isMinimized", function()
	assert(not love.window.isMinimized())
end)

add("window", "isOpen", function()
	assert(love.window.isOpen())
end)

add("window", "isVisible", function()
	assert(love.window.isVisible())
end)

add("window", "fromPixels", function()
	equal(love.window.fromPixels(100), 100 / love.window.getDPIScale(), "fromPixels DPI ratio")
end)

add("window", "getDPIScale", function()
	equal(love.window.getDPIScale(), 1, "embedded surface DPI scale")
end)

add("window", "getMode", function()
	assert(love.window.setMode(360, 240, {fullscreen = false, resizable = true}))
	local width, height, flags = love.window.getMode()
	equal(width, 360, "window mode width")
	equal(height, 240, "window mode height")
	equal(flags.fullscreen, false, "window mode fullscreen")
end)

add("window", "setMode", function()
	assert(love.window.setMode(512, 512, {fullscreen = false, resizable = false}))
	local width, height, flags = love.window.getMode()
	equal(width, 512, "setMode width")
	equal(height, 512, "setMode height")
	equal(flags.fullscreen, false, "setMode fullscreen")
	equal(flags.resizable, false, "setMode resizable")
	assert(love.window.setMode(360, 240, {fullscreen = false, resizable = true}))
end)

add("window", "toPixels", function()
	equal(love.window.toPixels(50), 50 * love.window.getDPIScale(), "toPixels DPI ratio")
end)

add("window", "updateMode", function()
	assert(love.window.setMode(360, 240, {fullscreen = false, resizable = true}))
	assert(love.window.updateMode({resizable = false}))
	local width, height, flags = love.window.getMode()
	equal(width, 360, "updateMode retained width")
	equal(height, 240, "updateMode retained height")
	equal(flags.resizable, false, "updateMode partial settings")
	assert(love.window.updateMode(512, 288, {resizable = true}))
	width, height, flags = love.window.getMode()
	equal(width, 512, "updateMode width")
	equal(height, 288, "updateMode height")
	equal(flags.resizable, true, "updateMode resizable")
	assert(love.window.setMode(360, 240, {fullscreen = false, resizable = true}))
end)

skipMany("graphics", {
	"Canvas", "Font", "Image", "Mesh", "ParticleSystem", "Quad", "Shader",
	"SpriteBatch", "Text", "Texture", "Video",
}, "upstream test marks this graphics object test as not written")

skipMany("graphics", {
	"circle", "clear", "draw", "ellipse", "line", "points", "polygon",
	"present", "print", "printf", "rectangle", "captureScreenshot", "origin", "pop",
	"push", "rotate", "scale", "translate",
}, "upstream assertion requires framebuffer pixels or host presentation; retained for the Metal visual suite")

add("graphics", "arc", function()
	love.graphics.arc("fill", "pie", 10, 20, 4, 0, math.pi / 2, 2)
	love.graphics.arc("line", "open", 10, 20, 4, 0, math.pi / 2, 2)
	love.graphics.arc("fill", 10, 20, 4, 0, math.pi / 2, 2)
	assert(not pcall(love.graphics.arc, "fill", "invalid", 0, 0, 1, 0, 1))
end)

add("graphics", "newTextBatch", function()
	local font = love.graphics.newFont(12)
	local batch = love.graphics.newTextBatch(font, "Love")
	assert(batch:typeOf("Text"))
	assert(batch:getWidth() > 0 and batch:getHeight() > 0)
end)

add("graphics", "getStencilMode", function()
	love.graphics.setStencilMode("draw", 4)
	local mode, value = love.graphics.getStencilMode()
	equal(mode, "draw", "stencil draw mode")
	equal(value, 4, "stencil draw value")
	love.graphics.push("all")
	love.graphics.setStencilMode("test", 7)
	mode, value = love.graphics.getStencilMode()
	equal(mode, "test", "stencil test mode")
	equal(value, 7, "stencil test value")
	love.graphics.pop()
	mode, value = love.graphics.getStencilMode()
	equal(mode, "draw", "restored stencil mode")
	equal(value, 4, "restored stencil value")
	love.graphics.setStencilMode()
	equal(love.graphics.getStencilMode(), "off", "disabled stencil mode")
end)

add("graphics", "newVideo", function()
	local video = love.graphics.newVideo("resources/sample.ogv")
	assert(type(video) == "userdata")
	equal(video:getWidth(), 496, "Video width")
	equal(video:getHeight(), 502, "Video height")
	local width, height = video:getDimensions()
	equal(width, 496, "Video dimensions width")
	equal(height, 502, "Video dimensions height")
	local stream = video:getStream()
	local source = video:getSource()
	assert(type(stream) == "userdata" and type(source) == "userdata")
	assert(video:getStream() == stream, "Video must reuse Love's cached VideoStream Proxy")
	assert(video:getSource() == source, "Video must reuse Love's cached Source Proxy")
	video:setFilter("nearest", "nearest", 2)
	local min, mag, anisotropy = video:getFilter()
	equal(min, "nearest", "Video min filter")
	equal(mag, "nearest", "Video mag filter")
	equal(anisotropy, 2, "Video anisotropy")
	stream:play()
	equal(source:isPlaying(), true, "Video stream starts its audio Source")
	stream:seek(0.2)
	equal(source:tell(), 0.2, "Video stream seeks its audio Source")
	for _ = 1, 20 do
		love.timer.sleep(0.005)
		love.graphics.draw(video)
	end
	stream:pause()
	equal(source:isPaused(), true, "Video stream pauses its audio Source")
	video:setSource(nil)
	equal(video:getSource(), nil, "Video Source detach")

	local silent = love.graphics.newVideo("resources/sample-no-audio.ogv")
	equal(silent:getSource(), nil, "Video without an audio track has no Source")
	silent:getStream():play()
	for _ = 1, 10 do
		love.timer.sleep(0.005)
		love.graphics.draw(silent)
	end
	local ok, message = pcall(love.graphics.newVideo,
		"resources/sample-no-audio.ogv", {audio = true})
	assert(not ok and message:find("Video had no audio track", 1, true))
	local muted = love.graphics.newVideo("resources/sample.ogv", {audio = false})
	equal(muted:getSource(), nil, "Video audio=false has no Source")

	local reused_stream = love.video.newVideoStream("resources/sample.ogv")
	local reused = love.graphics.newVideo(reused_stream, {audio = false})
	assert(reused:getStream() == reused_stream,
		"newVideo(VideoStream) must preserve the original Love Proxy identity")

	local scaled = love.graphics.newVideo("resources/sample.ogv",
		{audio = false, dpiscale = 2})
	equal(scaled:getWidth(), 248, "Video dpiscale logical width")
	equal(scaled:getHeight(), 251, "Video dpiscale logical height")
	equal(scaled:getPixelWidth(), 496, "Video dpiscale pixel width")
	equal(scaled:getPixelHeight(), 502, "Video dpiscale pixel height")
end)

add("graphics", "getLineStyle", function()
	equal(love.graphics.getLineStyle(), "smooth", "default line style")
end)

add("graphics", "setLineStyle", function()
	love.graphics.setLineStyle("rough")
	equal(love.graphics.getLineStyle(), "rough", "changed line style")
	assert(not pcall(love.graphics.setLineStyle, "invalid"))
	love.graphics.setLineStyle("smooth")
end)

add("graphics", "getLineJoin", function()
	equal(love.graphics.getLineJoin(), "miter", "default line join")
end)

add("graphics", "setLineJoin", function()
	love.graphics.setLineJoin("bevel")
	equal(love.graphics.getLineJoin(), "bevel", "changed line join")
	love.graphics.setLineJoin("none")
	equal(love.graphics.getLineJoin(), "none", "disconnected line join")
	assert(not pcall(love.graphics.setLineJoin, "invalid"))
	love.graphics.setLineJoin("miter")
end)

add("graphics", "isWireframe", function()
	assert(not love.graphics.isWireframe())
end)

add("graphics", "setWireframe", function()
	love.graphics.setWireframe(true)
	assert(love.graphics.isWireframe())
	love.graphics.push("all")
	love.graphics.setWireframe(false)
	assert(not love.graphics.isWireframe())
	love.graphics.pop()
	assert(love.graphics.isWireframe())
	love.graphics.setWireframe(false)
	assert(not pcall(love.graphics.setWireframe, 1))
end)

add("graphics", "getTextureFormats", function()
	local images = love.graphics.getTextureFormats({canvas = false})
	assert(images.rgba8 and images.r8)
	assert(not images.depth24 and not images.stencil8)
	local target = {sentinel = true}
	local canvases = love.graphics.getTextureFormats({canvas = true, readable = false}, target)
	assert(canvases == target and canvases.sentinel and canvases.rgba8 and canvases.depth24)
	local compute = love.graphics.getTextureFormats({canvas = false, computewrite = true})
	assert(not compute.rgba8)
	assert(not pcall(love.graphics.getTextureFormats, {}))
end)

add("graphics", "getStats", function()
	local target = {sentinel = true}
	local stats = love.graphics.getStats(target)
	equal(stats, target, "getStats target table")
	assert(stats.sentinel)
	for _, key in ipairs({"drawcalls", "drawcallsbatched", "canvasswitches",
		"shaderswitches", "canvases", "images", "fonts", "texturememory"}) do
		assert(type(stats[key]) == "number" and stats[key] >= 0, key .. " stat")
	end
end)

add("graphics", "discard", function()
	-- This is a performance hint: retained attachment contents are a valid result.
	love.graphics.discard()
	love.graphics.discard(false, false)
	love.graphics.discard({true, false}, true)
end)

add("graphics", "drawLayer", function()
	local red = love.image.newImageData(2, 2)
	local green = love.image.newImageData(2, 2)
	red:mapPixel(function() return 1, 0, 0, 1 end)
	green:mapPixel(function() return 0, 1, 0, 1 end)
	local texture = love.graphics.newArrayImage({red, green}, {mipmaps = false})
	love.graphics.drawLayer(texture, 2, 3, 4)
	assert(not pcall(love.graphics.drawLayer, texture, 0))
	assert(not pcall(love.graphics.drawLayer, love.graphics.newImage(red), 1))
end)

add("graphics", "flushBatch", function()
	-- LoveNode records ordered Dora commands and therefore has no pending Love stream batch.
	love.graphics.flushBatch()
end)

add("graphics", "getSupported", function()
	local target = {sentinel = true}
	local supported = love.graphics.getSupported(target)
	equal(supported, target, "getSupported target table")
	equal(supported.sentinel, true, "getSupported preserves target fields")
	equal(type(supported.multicanvasformats), "boolean", "multi Canvas format capability")
	equal(type(supported.clampzero), "boolean", "clampzero capability")
	equal(type(supported.lighten), "boolean", "lighten capability")
	equal(type(supported.fullnpot), "boolean", "full NPOT capability")
	equal(type(supported.pixelshaderhighp), "boolean", "pixel shader highp capability")
	equal(type(supported.shaderderivatives), "boolean", "shader derivative capability")
	equal(type(supported.glsl3), "boolean", "GLSL3 capability")
	equal(type(supported.instancing), "boolean", "instancing capability")
end)

add("graphics", "getTextureTypes", function()
	local target = {sentinel = true}
	local types = love.graphics.getTextureTypes(target)
	equal(types, target, "getTextureTypes target table")
	equal(types.sentinel, true, "getTextureTypes preserves target fields")
	equal(type(types["2d"]), "boolean", "2D texture capability")
	equal(type(types.array), "boolean", "array texture capability")
	equal(type(types.cube), "boolean", "cube texture capability")
	equal(type(types.volume), "boolean", "volume texture capability")
end)

add("graphics", "getRendererInfo", function()
	local name, version, vendor, device = love.graphics.getRendererInfo()
	equal(type(name), "string", "renderer name")
	equal(type(version), "string", "renderer version")
	equal(type(vendor), "string", "renderer vendor")
	equal(type(device), "string", "renderer device")
	assert(#name > 0 and #version > 0 and #vendor > 0 and #device > 0)
end)

add("graphics", "getBackgroundColor", function()
	local r, g, b, a = love.graphics.getBackgroundColor()
	equal(r, 0, "default background red")
	equal(g, 0, "default background green")
	equal(b, 0, "default background blue")
	equal(a, 1, "default background alpha")
end)

add("graphics", "setBackgroundColor", function()
	love.graphics.setBackgroundColor({0.125, 0.25, 0.5, 0.75})
	local r, g, b, a = love.graphics.getBackgroundColor()
	equal(r, 0.125, "background red")
	equal(g, 0.25, "background green")
	equal(b, 0.5, "background blue")
	equal(a, 0.75, "background alpha")
	love.graphics.setBackgroundColor(0, 0, 0, 1)
end)

add("graphics", "getDefaultFilter", function()
	local min, mag, anisotropy = love.graphics.getDefaultFilter()
	equal(min, "linear", "default minification filter")
	equal(mag, "linear", "default magnification filter")
	equal(anisotropy, 1, "default anisotropy")
end)

add("graphics", "setDefaultFilter", function()
	love.graphics.setDefaultFilter("nearest", "nearest", 2)
	local min, mag, anisotropy = love.graphics.getDefaultFilter()
	equal(min, "nearest", "changed minification filter")
	equal(mag, "nearest", "changed magnification filter")
	equal(anisotropy, 2, "changed anisotropy")
	local image = love.graphics.newImage(love.image.newImageData(1, 1))
	local canvas = love.graphics.newCanvas(1, 1)
	local imageMin, imageMag, imageAnisotropy = image:getFilter()
	equal(imageMin, "nearest", "new Image default minification filter")
	equal(imageMag, "nearest", "new Image default magnification filter")
	equal(imageAnisotropy, 2, "new Image default anisotropy")
	local canvasMin, canvasMag, canvasAnisotropy = canvas:getFilter()
	equal(canvasMin, "nearest", "new Canvas default minification filter")
	equal(canvasMag, "nearest", "new Canvas default magnification filter")
	equal(canvasAnisotropy, 2, "new Canvas default anisotropy")
	assert(not pcall(love.graphics.setDefaultFilter, "nearest", "linear"))
	love.graphics.setDefaultFilter("linear")
end)

add("graphics", "getStackDepth", function()
	local depth = love.graphics.getStackDepth()
	love.graphics.push()
	equal(love.graphics.getStackDepth(), depth + 1, "pushed stack depth")
	love.graphics.pop()
	equal(love.graphics.getStackDepth(), depth, "popped stack depth")
end)

add("graphics", "intersectScissor", function()
	love.graphics.setScissor(10, 20, 30, 40)
	love.graphics.intersectScissor(20, 10, 30, 30)
	local x, y, width, height = love.graphics.getScissor()
	equal(x, 20, "intersected scissor x")
	equal(y, 20, "intersected scissor y")
	equal(width, 20, "intersected scissor width")
	equal(height, 20, "intersected scissor height")
	love.graphics.setScissor()
	love.graphics.intersectScissor(1, 2, 3, 4)
	x, y, width, height = love.graphics.getScissor()
	equal(x, 1, "fresh intersect scissor x")
	equal(y, 2, "fresh intersect scissor y")
	equal(width, 3, "fresh intersect scissor width")
	equal(height, 4, "fresh intersect scissor height")
	love.graphics.setScissor()
end)

add("graphics", "isActive", function()
	equal(love.graphics.isActive(), true, "attached Dora graphics backend")
end)

add("graphics", "isGammaCorrect", function()
	equal(love.graphics.isGammaCorrect(), false, "Dora embedded graphics gamma mode")
end)

add("graphics", "applyTransform", function()
	love.graphics.origin()
	love.graphics.translate(2, 3)
	love.graphics.applyTransform(love.math.newTransform(4, 5, 0, 2, 3))
	local x, y = love.graphics.transformPoint(1, 1)
	equal(x, 8, "applied transform x")
	equal(y, 11, "applied transform y")
	love.graphics.origin()
end)

add("graphics", "replaceTransform", function()
	love.graphics.translate(100, 100)
	love.graphics.replaceTransform(love.math.newTransform(4, 5, 0, 2, 3))
	local x, y = love.graphics.transformPoint(1, 1)
	equal(x, 6, "replaced transform x")
	equal(y, 8, "replaced transform y")
	love.graphics.origin()
end)

add("graphics", "shear", function()
	love.graphics.origin()
	love.graphics.shear(2, 3)
	local x, y = love.graphics.transformPoint(4, 5)
	equal(x, 14, "sheared point x")
	equal(y, 17, "sheared point y")
	love.graphics.origin()
end)

add("graphics", "transformPoint", function()
	love.graphics.origin()
	love.graphics.translate(10, 20)
	love.graphics.scale(2, 3)
	local x, y = love.graphics.transformPoint(4, 5)
	equal(x, 18, "transformed point x")
	equal(y, 35, "transformed point y")
	love.graphics.origin()
end)

add("graphics", "inverseTransformPoint", function()
	love.graphics.origin()
	love.graphics.translate(10, 20)
	love.graphics.scale(2, 3)
	local x, y = love.graphics.inverseTransformPoint(18, 35)
	equal(x, 4, "inverse transformed point x")
	equal(y, 5, "inverse transformed point y")
	love.graphics.scale(0)
	assert(not pcall(love.graphics.inverseTransformPoint, 0, 0))
	love.graphics.origin()
end)

add("graphics", "reset", function()
	love.graphics.push()
	love.graphics.setColor(0.1, 0.2, 0.3, 0.4)
	love.graphics.setBackgroundColor(0.5, 0.6, 0.7, 0.8)
	love.graphics.setDefaultFilter("nearest")
	love.graphics.setLineWidth(7)
	love.graphics.setLineStyle("rough")
	love.graphics.setLineJoin("bevel")
	love.graphics.setPointSize(4)
	love.graphics.setBlendMode("add", "premultiplied")
	love.graphics.setScissor(1, 2, 3, 4)
	love.graphics.setColorMask(false, false, false, false)
	love.graphics.setDepthMode("less", true)
	love.graphics.setMeshCullMode("back")
	love.graphics.setFrontFaceWinding("cw")
	love.graphics.setWireframe(true)
	love.graphics.setStencilTest("greater", 2)
	love.graphics.setCanvas(love.graphics.newCanvas(2, 2))
	love.graphics.translate(9, 10)
	love.graphics.reset()
	equal(love.graphics.getStackDepth(), 1, "reset preserves stack")
	local r, g, b, a = love.graphics.getColor()
	equal(r + g + b + a, 4, "reset color")
	r, g, b, a = love.graphics.getBackgroundColor()
	equal(r + g + b, 0, "reset background color")
	equal(a, 1, "reset background alpha")
	local min, mag, anisotropy = love.graphics.getDefaultFilter()
	equal(min, "linear", "reset minification filter")
	equal(mag, "linear", "reset magnification filter")
	equal(anisotropy, 1, "reset anisotropy")
	equal(love.graphics.getLineWidth(), 1, "reset line width")
	equal(love.graphics.getLineStyle(), "smooth", "reset line style")
	equal(love.graphics.getLineJoin(), "miter", "reset line join")
	assert(not love.graphics.isWireframe())
	equal(love.graphics.getPointSize(), 1, "reset point size")
	equal(love.graphics.getScissor(), nil, "reset scissor")
	equal(love.graphics.getCanvas(), nil, "reset Canvas")
	equal(love.graphics.getShader(), nil, "reset Shader")
	equal(love.graphics.getStencilTest(), "always", "reset stencil test")
	local x, y = love.graphics.transformPoint(3, 4)
	equal(x, 3, "reset transform x")
	equal(y, 4, "reset transform y")
	love.graphics.pop()
end)

add("graphics", "drawInstanced", function()
	local mesh = love.graphics.newMesh({{0, 0}, {8, 0}, {0, 8}}, "triangles")
	local colors = love.graphics.newMesh({
		{"InstanceColor", "float", 4},
	}, {{1, 0, 0, 1}, {0, 1, 0, 1}}, "points")
	mesh:attachAttribute("VertexColor", colors, "perinstance", "InstanceColor")
	love.graphics.drawInstanced(mesh, 0)
	love.graphics.drawInstanced(mesh, -1)
	assert(pcall(love.graphics.drawInstanced, mesh, 2, 0, 0, 0, 1, 1, 0, 0, 0.25, 0.5))
	assert(not pcall(love.graphics.drawInstanced, mesh, 3))
end)

add("graphics", "getColorMask", function()
	local red, green, blue, alpha = love.graphics.getColorMask()
	equal(red, true, "default red color mask")
	equal(green, true, "default green color mask")
	equal(blue, true, "default blue color mask")
	equal(alpha, true, "default alpha color mask")
end)

add("graphics", "setColorMask", function()
	love.graphics.setColorMask(true, false, true, false)
	local red, green, blue, alpha = love.graphics.getColorMask()
	equal(red, true, "changed red color mask")
	equal(green, false, "changed green color mask")
	equal(blue, true, "changed blue color mask")
	equal(alpha, false, "changed alpha color mask")
	love.graphics.setColorMask()
end)

add("graphics", "getBlendMode", function()
	local mode, alphaMode = love.graphics.getBlendMode()
	equal(mode, "alpha", "default blend mode")
	equal(alphaMode, "alphamultiply", "default alpha mode")
	love.graphics.setBlendMode("add", "premultiplied")
	mode, alphaMode = love.graphics.getBlendMode()
	equal(mode, "add", "changed blend mode")
	equal(alphaMode, "premultiplied", "changed alpha mode")
	love.graphics.setBlendMode("alpha", "alphamultiply")
end)

add("graphics", "getSystemLimits", function()
	local target = {sentinel = true}
	local limits = love.graphics.getSystemLimits(target)
	equal(limits, target, "getSystemLimits target table")
	equal(limits.sentinel, true, "getSystemLimits preserves target fields")
	for _, name in ipairs({"pointsize", "texturesize", "volumetexturesize", "cubetexturesize",
		"texturelayers", "multicanvas", "canvasmsaa", "anisotropy"}) do
		assert(type(limits[name]) == "number" and limits[name] >= 0, "invalid system limit: " .. name)
	end
	assert(limits.texturesize > 0, "texture size must be positive")
end)

add("graphics", "getCanvas", function()
	equal(love.graphics.getCanvas(), nil, "default Canvas")
	local canvas = love.graphics.newCanvas(16, 16)
	love.graphics.setCanvas(canvas)
	equal(love.graphics.getCanvas(), canvas, "selected Canvas")
	love.graphics.setCanvas()
end)

add("graphics", "getColor", function()
	local r, g, b, a = love.graphics.getColor()
	equal(r + g + b + a, 4, "default graphics color")
	love.graphics.setColor(0, 0.25, 0.5, 0.75)
	r, g, b, a = love.graphics.getColor()
	equal(r, 0, "changed color r")
	equal(g, 0.25, "changed color g")
	equal(b, 0.5, "changed color b")
	equal(a, 0.75, "changed color a")
	love.graphics.setColor(1, 1, 1, 1)
end)

add("graphics", "getDepthMode", function()
	local compare, write = love.graphics.getDepthMode()
	equal(compare, "always", "default depth compare")
	equal(write, false, "default depth write")
	love.graphics.setDepthMode("less", true)
	compare, write = love.graphics.getDepthMode()
	equal(compare, "less", "changed depth compare")
	equal(write, true, "changed depth write")
	love.graphics.setDepthMode("always", false)
end)

add("graphics", "getFont", function()
	local font = love.graphics.getFont()
	assert(font and font:getHeight() > 0)
end)

add("graphics", "getFrontFaceWinding", function()
	equal(love.graphics.getFrontFaceWinding(), "ccw", "default front face winding")
	love.graphics.setFrontFaceWinding("cw")
	equal(love.graphics.getFrontFaceWinding(), "cw", "changed front face winding")
	love.graphics.setFrontFaceWinding("ccw")
end)

add("graphics", "getLineWidth", function()
	equal(love.graphics.getLineWidth(), 1, "default line width")
	love.graphics.setLineWidth(10)
	equal(love.graphics.getLineWidth(), 10, "changed line width")
	love.graphics.setLineWidth(1)
end)

add("graphics", "getMeshCullMode", function()
	equal(love.graphics.getMeshCullMode(), "none", "default mesh cull mode")
	love.graphics.setMeshCullMode("front")
	equal(love.graphics.getMeshCullMode(), "front", "changed mesh cull mode")
	love.graphics.setMeshCullMode("none")
end)

add("graphics", "getPointSize", function()
	equal(love.graphics.getPointSize(), 1, "default point size")
	love.graphics.setPointSize(10)
	equal(love.graphics.getPointSize(), 10, "changed point size")
	love.graphics.setPointSize(1)
end)

add("graphics", "getScissor", function()
	equal(love.graphics.getScissor(), nil, "default scissor")
	love.graphics.setScissor(0, 0, 16, 16)
	local x, y, width, height = love.graphics.getScissor()
	equal(x, 0, "scissor x")
	equal(y, 0, "scissor y")
	equal(width, 16, "scissor width")
	equal(height, 16, "scissor height")
	love.graphics.setScissor()
end)

add("graphics", "getShader", function()
	equal(love.graphics.getShader(), nil, "default Shader")
end)

add("graphics", "setBlendMode", function()
	love.graphics.setBlendMode("add", "premultiplied")
	local mode, alphaMode = love.graphics.getBlendMode()
	equal(mode, "add", "setBlendMode mode")
	equal(alphaMode, "premultiplied", "setBlendMode alpha mode")
	love.graphics.setBlendMode("subtract", "premultiplied")
	mode, alphaMode = love.graphics.getBlendMode()
	equal(mode, "subtract", "setBlendMode subtract mode")
	equal(alphaMode, "premultiplied", "setBlendMode subtract alpha mode")
	love.graphics.setBlendMode("alpha", "alphamultiply")
end)

add("graphics", "setCanvas", function()
	local first = love.graphics.newCanvas(8, 8)
	local second = love.graphics.newCanvas(8, 8)
	love.graphics.setCanvas(first)
	equal(love.graphics.getCanvas(), first, "first selected Canvas")
	love.graphics.setCanvas(second)
	equal(love.graphics.getCanvas(), second, "second selected Canvas")
	love.graphics.setCanvas()
	equal(love.graphics.getCanvas(), nil, "cleared Canvas")
end)

add("graphics", "setColor", function()
	love.graphics.setColor(1, 0, 0, 0.5)
	local r, g, b, a = love.graphics.getColor()
	equal(r, 1, "setColor r")
	equal(g, 0, "setColor g")
	equal(b, 0, "setColor b")
	equal(a, 0.5, "setColor a")
	love.graphics.setColor(1, 1, 1, 1)
end)

add("graphics", "setDepthMode", function()
	for _, mode in ipairs({"equal", "notequal", "less", "lequal", "gequal", "greater", "never", "always"}) do
		love.graphics.setDepthMode(mode, true)
		local actual, write = love.graphics.getDepthMode()
		equal(actual, mode, "setDepthMode " .. mode)
		equal(write, true, "setDepthMode write")
	end
	love.graphics.setDepthMode("always", false)
end)

add("graphics", "setFont", function()
	local font = love.graphics.newFont(14)
	love.graphics.setFont(font)
	equal(love.graphics.getFont(), font, "selected Font")
end)

add("graphics", "setFrontFaceWinding", function()
	for _, winding in ipairs({"cw", "ccw"}) do
		love.graphics.setFrontFaceWinding(winding)
		equal(love.graphics.getFrontFaceWinding(), winding, "setFrontFaceWinding")
	end
end)

add("graphics", "setLineWidth", function()
	love.graphics.setLineWidth(3)
	equal(love.graphics.getLineWidth(), 3, "setLineWidth")
	love.graphics.setLineWidth(1)
end)

add("graphics", "setMeshCullMode", function()
	for _, mode in ipairs({"back", "front", "none"}) do
		love.graphics.setMeshCullMode(mode)
		equal(love.graphics.getMeshCullMode(), mode, "setMeshCullMode")
	end
end)

add("graphics", "setScissor", function()
	love.graphics.setScissor(1, 2, 3, 4)
	local x, y, width, height = love.graphics.getScissor()
	equal(x, 1, "setScissor x")
	equal(y, 2, "setScissor y")
	equal(width, 3, "setScissor width")
	equal(height, 4, "setScissor height")
	love.graphics.setScissor()
end)

local officialPixelShader = [[
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	return color;
}
]]

add("graphics", "setShader", function()
	local shader = love.graphics.newShader(officialPixelShader)
	love.graphics.setShader(shader)
	equal(love.graphics.getShader(), shader, "selected Shader")
	love.graphics.setShader()
	equal(love.graphics.getShader(), nil, "cleared Shader")
end)

add("graphics", "setStencilTest", function()
	love.graphics.setStencilTest("greater", 2)
	local compare, value = love.graphics.getStencilTest()
	equal(compare, "greater", "stencil compare")
	equal(value, 2, "stencil value")
	love.graphics.setStencilTest()
	equal(love.graphics.getStencilTest(), "always", "cleared stencil test")
	love.graphics.setStencilTest("always", 0)
	compare, value = love.graphics.getStencilTest()
	equal(compare, "always", "explicit always stencil test")
	equal(value, 0, "explicit always stencil value")
	love.graphics.setStencilTest()
end)

add("graphics", "getDPIScale", function()
	equal(love.graphics.getDPIScale(), 1, "graphics DPI scale")
end)

add("graphics", "getDimensions", function()
	local width, height = love.graphics.getDimensions()
	local windowWidth, windowHeight = love.window.getMode()
	equal(width, windowWidth, "graphics dimensions width")
	equal(height, windowHeight, "graphics dimensions height")
end)

add("graphics", "getHeight", function()
	local _, windowHeight = love.window.getMode()
	equal(love.graphics.getHeight(), windowHeight, "graphics height")
end)

add("graphics", "getPixelDimensions", function()
	local width, height = love.graphics.getPixelDimensions()
	local windowWidth, windowHeight = love.window.getMode()
	equal(width / love.graphics.getDPIScale(), windowWidth, "pixel dimensions width")
	equal(height / love.graphics.getDPIScale(), windowHeight, "pixel dimensions height")
end)

add("graphics", "getPixelHeight", function()
	local _, windowHeight = love.window.getMode()
	equal(love.graphics.getPixelHeight() / love.graphics.getDPIScale(), windowHeight, "pixel height")
end)

add("graphics", "getPixelWidth", function()
	local windowWidth = love.window.getMode()
	equal(love.graphics.getPixelWidth() / love.graphics.getDPIScale(), windowWidth, "pixel width")
end)

add("graphics", "getWidth", function()
	local windowWidth = love.window.getMode()
	equal(love.graphics.getWidth(), windowWidth, "graphics width")
end)

add("graphics", "newArrayImage", function()
	local first = love.image.newImageData(2, 2)
	local second = love.image.newImageData(2, 2)
	local image = love.graphics.newArrayImage({first, second}, {mipmaps = false})
	equal(image:getTextureType(), "array", "ArrayImage texture type")
	equal(image:getLayerCount(), 2, "ArrayImage layer count")
	local replacement = love.image.newImageData(1, 1)
	replacement:setPixel(0, 0, 1, 0, 1, 1)
	image:replacePixels(replacement, 2, 1, 1, 1)
	assert(not pcall(image.replacePixels, image, replacement, 3, 1, 0, 0))
end)

add("graphics", "newCanvas", function()
	local canvas = love.graphics.newCanvas(16, 16, {
		type = "2d", format = "normal", readable = true, msaa = 0, dpiscale = 1, mipmaps = "none",
	})
	local width, height = canvas:getDimensions()
	equal(width, 16, "Canvas width")
	equal(height, 16, "Canvas height")
end)

add("graphics", "newCubeImage", function()
	local face = love.image.newImageData(2, 2)
	local image = love.graphics.newCubeImage({face, face, face, face, face, face}, {mipmaps = false})
	equal(image:getTextureType(), "cube", "CubeImage texture type")
end)

add("graphics", "newFont", function()
	local font = love.graphics.newFont(8)
	assert(font:getHeight() > 0)
end)

add("graphics", "newImageFont", function()
	local atlas = love.image.newImageData(6, 2)
	atlas:mapPixel(function() return 1, 0, 1, 1 end)
	for y = 0, 1 do
		for x = 1, 2 do atlas:setPixel(x, y, 1, 0, 0, 1) end
		for x = 4, 4 do atlas:setPixel(x, y, 0, 1, 0, 1) end
	end
	local font = love.graphics.newImageFont(atlas, "AB", 1, 1)
	equal(font:getWidth("AB"), 5, "ImageFont variable glyph width and spacing")
	equal(font:getHeight(), 2, "ImageFont height")
	assert(font:hasGlyphs("AB") and not font:hasGlyphs("C"))
end)

add("graphics", "newImage", function()
	local image = love.graphics.newImage(love.image.newImageData(32, 16))
	local width, height = image:getDimensions()
	equal(width, 32, "Image width")
	equal(height, 16, "Image height")
	local fileImage = love.graphics.newImage(
		love.filesystem.newFileData("encoded-image", "official@2x.png"),
		{mipmaps = false, linear = false})
	equal(fileImage:getPixelWidth(), 2, "FileData Image pixel width")
	equal(fileImage:getWidth(), 1, "FileData Image DPI width")
	equal(fileImage:getDPIScale(), 2, "FileData Image automatic DPI scale")
	assert(not fileImage:isFormatLinear())
	local compressed = love.image.newCompressedData(
		love.filesystem.newFileData("compressed-image", "official.dds"))
	local compressedImage = love.graphics.newImage(compressed, {mipmaps = true})
	width, height = compressedImage:getDimensions()
	equal(width, 4, "compressed Image width")
	equal(height, 4, "compressed Image height")
end)

add("graphics", "newMesh", function()
	local mesh = love.graphics.newMesh({{1, 1, 0, 0, 1, 1, 1, 1}}, "fan", "dynamic")
	equal(mesh:getVertexCount(), 1, "Mesh vertex count")
	equal(mesh:getDrawMode(), "fan", "Mesh draw mode")
end)

add("graphics", "newParticleSystem", function()
	local image = love.graphics.newImage(love.image.newImageData(16, 16))
	local particles = love.graphics.newParticleSystem(image, 1000)
	equal(particles:getBufferSize(), 1000, "ParticleSystem buffer size")
end)

add("graphics", "newQuad", function()
	local image = love.graphics.newImage(love.image.newImageData(16, 16))
	local quad = love.graphics.newQuad(0, 0, 16, 16, image)
	local x, y, width, height = quad:getViewport()
	equal(x + y, 0, "Quad viewport origin")
	equal(width, 16, "Quad viewport width")
	equal(height, 16, "Quad viewport height")
end)

add("graphics", "newShader", function()
	local shader = love.graphics.newShader(officialPixelShader)
	assert(type(shader:getWarnings()) == "string")
end)

add("graphics", "newSpriteBatch", function()
	local image = love.graphics.newImage(love.image.newImageData(16, 16))
	local batch = love.graphics.newSpriteBatch(image, 1000)
	equal(batch:getBufferSize(), 1000, "SpriteBatch buffer size")
	equal(batch:add(0, 0), 1, "SpriteBatch first index")
	local attributes = love.graphics.newMesh({{"Extra", "float", 1}}, {{1}, {2}, {3}, {4}}, "points")
	batch:attachAttribute("Extra", attributes)
	local tooShort = love.graphics.newMesh({{"Extra", "float", 1}}, {{1}, {2}, {3}}, "points")
	assert(not pcall(batch.attachAttribute, batch, "Missing", attributes))
	assert(not pcall(batch.attachAttribute, batch, "Extra", tooShort))
	attributes = nil
	collectgarbage("collect")
	local layer = love.image.newImageData(2, 2)
	local array = love.graphics.newArrayImage({layer, layer}, {mipmaps = false})
	local arrayBatch = love.graphics.newSpriteBatch(array, 2)
	local quad = love.graphics.newQuad(0, 0, 2, 2, 2, 2)
	quad:setLayer(2)
	equal(arrayBatch:add(quad), 1, "ArrayImage SpriteBatch Quad layer add")
	equal(arrayBatch:addLayer(1), 2, "ArrayImage SpriteBatch explicit layer add")
	arrayBatch:setLayer(2, 2)
	equal(arrayBatch:getCount(), 2, "ArrayImage SpriteBatch setLayer count")
	assert(not pcall(batch.addLayer, batch, 1))
	assert(not pcall(arrayBatch.addLayer, arrayBatch, 3))
end)

add("graphics", "newVolumeImage", function()
	local first = love.image.newImageData(2, 2)
	local second = love.image.newImageData(2, 2)
	local image = love.graphics.newVolumeImage({first, second}, {mipmaps = false})
	equal(image:getTextureType(), "volume", "VolumeImage texture type")
	equal(image:getDepth(), 2, "VolumeImage depth")
end)

add("graphics", "validateShader", function()
	local valid, message = love.graphics.validateShader(false, "vec4 effect() { compile_error }")
	equal(valid, false, "invalid Shader status")
	assert(type(message) == "string")
	valid, message = love.graphics.validateShader(false, officialPixelShader)
	equal(valid, true, "valid Shader status")
	equal(message, nil, "valid Shader message")
end)

add("thread", "Channel", function()
	local channel = love.thread.getChannel("test")
	assert(type(channel) == "userdata")
	local thread1 = love.thread.newThread([[
		require("love.timer")
		love.timer.sleep(0.1)
		love.thread.getChannel("test"):push("hello world")
		love.timer.sleep(0.1)
		love.thread.getChannel("test"):push("me again")
	]])
	thread1:start()
	equal(channel:demand(), "hello world", "first thread message")
	thread1:wait()
	equal(channel:getCount(), 1, "second message pending")
	equal(channel:peek(), "me again", "second message peek")
	equal(channel:pop(), "me again", "second thread message")
	channel:clear()
	local thread2 = love.thread.newThread([[
		local function setChannel(channel, value)
			channel:clear()
			return channel:push(value)
		end
		local channel = love.thread.getChannel("test")
		local waiting, sent = true, nil
		while waiting do
			if sent == nil then sent = channel:performAtomic(setChannel, "ping") end
			if channel:hasRead(sent) then
				local message = channel:demand()
				if message == "pong" then channel:push(message); waiting = false end
			end
		end
	]])
	thread2:start()
	equal(channel:demand(), "ping", "atomic ping")
	assert(channel:supply("pong", 1))
	thread2:wait()
	equal(channel:pop(), "pong", "atomic pong")
	equal(channel:getCount(), 0, "channel empty")
end)

add("thread", "Thread", function()
	local thread = love.thread.newThread([[
		local total = 0
		for value = 1, 100000 do total = total + value end
	]])
	assert(type(thread) == "userdata")
	assert(thread:start())
	equal(thread:isRunning(), true, "thread started")
	thread:wait()
	equal(thread:isRunning(), false, "thread finished")
	equal(thread:getError(), nil, "thread has no error")
	local bad = love.thread.newThread([[local value = 0
return value + "string" .. 10]])
	bad:start()
	bad:wait()
	assert(bad:getError() ~= nil)
end)

add("thread", "getChannel", function()
	assert(type(love.thread.getChannel("test")) == "userdata")
end)

add("thread", "newChannel", function()
	assert(type(love.thread.newChannel()) == "userdata")
end)

add("thread", "newThread", function()
	assert(type(love.thread.newThread("classes/TestSuite.lua")) == "userdata")
end)

add("video", "VideoStream", function()
	local video = love.video.newVideoStream("resources/sample.ogv")
	assert(type(video) == "userdata")
	equal(video:getFilename(), "resources/sample.ogv", "VideoStream filename")
	equal(video:isPlaying(), false, "VideoStream starts paused")
	video:play()
	equal(video:isPlaying(), true, "VideoStream play")
	video:seek(0.3)
	equal(math.floor(video:tell() * 10), 3, "VideoStream seek/tell")
	video:rewind()
	equal(video:tell(), 0, "VideoStream rewind")
	video:pause()
	equal(video:isPlaying(), false, "VideoStream pause")
end)

add("video", "newVideoStream", function()
	assert(type(love.video.newVideoStream("resources/sample.ogv")) == "userdata")
end)

official_passed = 0
official_failed = {}
official_skipped = {}
official_modules = {
	data = {passed = 0, failed = 0, skipped = 0},
	math = {passed = 0, failed = 0, skipped = 0},
	event = {passed = 0, failed = 0, skipped = 0},
	timer = {passed = 0, failed = 0, skipped = 0},
	system = {passed = 0, failed = 0, skipped = 0},
	filesystem = {passed = 0, failed = 0, skipped = 0},
	image = {passed = 0, failed = 0, skipped = 0},
	sound = {passed = 0, failed = 0, skipped = 0},
	audio = {passed = 0, failed = 0, skipped = 0},
	font = {passed = 0, failed = 0, skipped = 0},
	physics = {passed = 0, failed = 0, skipped = 0},
	window = {passed = 0, failed = 0, skipped = 0},
	graphics = {passed = 0, failed = 0, skipped = 0},
	thread = {passed = 0, failed = 0, skipped = 0},
	video = {passed = 0, failed = 0, skipped = 0},
}

for _, item in ipairs(cases) do
	if item.skip then
		official_modules[item.module].skipped = official_modules[item.module].skipped + 1
		official_skipped[#official_skipped + 1] = item.module .. "." .. item.name .. ": " .. item.skip
	else
		local ok, message = pcall(item.test)
		if ok then
			official_passed = official_passed + 1
			official_modules[item.module].passed = official_modules[item.module].passed + 1
		else
			official_modules[item.module].failed = official_modules[item.module].failed + 1
			official_failed[#official_failed + 1] = item.module .. "." .. item.name .. ": " .. tostring(message)
		end
	end
end

print(("LOVE_OFFICIAL_COMPAT_DATA %d %d %d"):format(
	official_modules.data.passed, official_modules.data.failed, official_modules.data.skipped))
print(("LOVE_OFFICIAL_COMPAT_MATH %d %d %d"):format(
	official_modules.math.passed, official_modules.math.failed, official_modules.math.skipped))
print(("LOVE_OFFICIAL_COMPAT_EVENT %d %d %d"):format(
	official_modules.event.passed, official_modules.event.failed, official_modules.event.skipped))
print(("LOVE_OFFICIAL_COMPAT_TIMER %d %d %d"):format(
	official_modules.timer.passed, official_modules.timer.failed, official_modules.timer.skipped))
print(("LOVE_OFFICIAL_COMPAT_SYSTEM %d %d %d"):format(
	official_modules.system.passed, official_modules.system.failed, official_modules.system.skipped))
print(("LOVE_OFFICIAL_COMPAT_FILESYSTEM %d %d %d"):format(
	official_modules.filesystem.passed, official_modules.filesystem.failed, official_modules.filesystem.skipped))
print(("LOVE_OFFICIAL_COMPAT_IMAGE %d %d %d"):format(
	official_modules.image.passed, official_modules.image.failed, official_modules.image.skipped))
print(("LOVE_OFFICIAL_COMPAT_SOUND %d %d %d"):format(
	official_modules.sound.passed, official_modules.sound.failed, official_modules.sound.skipped))
print(("LOVE_OFFICIAL_COMPAT_AUDIO %d %d %d"):format(
	official_modules.audio.passed, official_modules.audio.failed, official_modules.audio.skipped))
print(("LOVE_OFFICIAL_COMPAT_FONT %d %d %d"):format(
	official_modules.font.passed, official_modules.font.failed, official_modules.font.skipped))
print(("LOVE_OFFICIAL_COMPAT_PHYSICS %d %d %d"):format(
	official_modules.physics.passed, official_modules.physics.failed, official_modules.physics.skipped))
print(("LOVE_OFFICIAL_COMPAT_WINDOW %d %d %d"):format(
	official_modules.window.passed, official_modules.window.failed, official_modules.window.skipped))
print(("LOVE_OFFICIAL_COMPAT_GRAPHICS %d %d %d"):format(
	official_modules.graphics.passed, official_modules.graphics.failed, official_modules.graphics.skipped))
print(("LOVE_OFFICIAL_COMPAT_THREAD %d %d %d"):format(
	official_modules.thread.passed, official_modules.thread.failed, official_modules.thread.skipped))
print(("LOVE_OFFICIAL_COMPAT_VIDEO %d %d %d"):format(
	official_modules.video.passed, official_modules.video.failed, official_modules.video.skipped))
for _, failure in ipairs(official_failed) do
	print("LOVE_OFFICIAL_COMPAT_FAILURE " .. failure)
end
for _, skipped in ipairs(official_skipped) do
	print("LOVE_OFFICIAL_COMPAT_SKIP " .. skipped)
end
