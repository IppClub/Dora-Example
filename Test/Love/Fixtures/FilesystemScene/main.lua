local filesystem = require("love.filesystem")
assert(filesystem.getIdentity() == "dora-love-filesystem-scene")
local executablePath = filesystem.getExecutablePath()
assert(type(executablePath) == "string" and #executablePath > 0)
assert(executablePath ~= filesystem.getSource())
assert(filesystem.createDirectory("shared"))
assert(filesystem.write("shared/module.lua", "return {owner = 'save'}\n"))
assert(filesystem.write("state.txt", "content-backend"))

package.loaded["shared.module"] = nil
assert(require("shared.module").owner == "save")
local state, size = filesystem.read("state.txt")
assert(state == "content-backend" and size == #state)
assert(filesystem.exists("state.txt") and filesystem.isFile("state.txt"))
assert(not filesystem.isDirectory("state.txt") and not filesystem.isSymlink("state.txt"))
assert(filesystem.isDirectory("shared") and filesystem.getSize("state.txt") == #state)
local modified, modifiedError = filesystem.getLastModified("state.txt")
assert(modified == nil and modifiedError:find("Could not determine", 1, true))

local file = assert(filesystem.newFile("state-object.txt", "w"))
local payload = filesystem.newFileData("filedata", "state-object.txt")
assert(file:write(payload) and file:tell() == payload:getSize())
assert(file:seek(4) and file:write("-object-") and file:flush() and file:close())
assert(file:open("a") and file:write("tail") and file:close())
local stored = filesystem.newFileData(file)
assert(stored:getFilename() == "state-object.txt" and stored:getExtension() == "txt")
assert(stored:getString() == "file-object-tail")
local dataRead, dataSize = filesystem.read("data", "state-object.txt")
assert(dataRead:getString() == stored:getString() and dataSize == stored:getSize())

local frames = 0

function love.load()
	print("LOVE_FILESYSTEM_EXECUTABLE_PATH_PASS", executablePath)
	print("LOVE_FILESYSTEM_CONTENT_PASS", filesystem.getIdentity(), filesystem.getSaveDirectory())
	print("LOVE_FILEDATA_CONTENT_PASS", stored:getString(), stored:getSize())
end

function love.update()
	frames = frames + 1
	if frames == 2 then
		love.event.quit()
	end
end

function love.quit()
	assert(filesystem.remove("shared/module.lua"))
	assert(filesystem.remove("shared"))
	assert(filesystem.remove("state.txt"))
	assert(filesystem.remove("state-object.txt"))
	return false
end

function love.draw()
	love.graphics.clear(0.03, 0.12, 0.08, 1)
	love.graphics.setColor(0.2, 1, 0.55, 1)
	love.graphics.rectangle("line", 16, 16, 288, 148)
end
