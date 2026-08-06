local filesystem = require("love.filesystem")

local frame = 0

function love.load()
	assert(filesystem.isFused() == false)
	assert(filesystem.getRequirePath() == "?.lua;?/init.lua")
	assert(filesystem.getWorkingDirectory() == filesystem.getSource())
	assert(#filesystem.getUserDirectory() > 0)
	assert(#filesystem.getAppdataDirectory() > 0)
	assert(#filesystem.getSourceBaseDirectory() > 0)
	assert(filesystem.getRealDirectory("archive-a.zip") == filesystem.getSource())
	assert(filesystem.mount("archive-a.zip", "mods"))
	assert(filesystem.getRealDirectory("mods/asset.txt"):find("LoveMounts", 1, true))
	assert(not filesystem.mount("archive-a.zip", "duplicate"))
	assert(filesystem.read("mods/asset.txt") == "archive-a\n")
	assert(filesystem.getInfo("mods", "directory").type == "directory")
	filesystem.setRequirePath("mods/custom/?.lua")
	assert(filesystem.getRequirePath() == "mods/custom/?.lua")
	assert(require("alternate").owner == "archive-custom")
	filesystem.setRequirePath("?.lua;?/init.lua")
	assert(require("mods.helper").owner == "archive-a")

	local memory = filesystem.newFileData("archive-b.zip")
	assert(filesystem.mount(memory, "memory"))
	assert(filesystem.read("memory/nested/value.txt") == "archive-b\n")
	collectgarbage("collect")
	assert(filesystem.unmount(memory))
	assert(filesystem.read("memory/nested/value.txt") == nil)

	assert(filesystem.unmount("archive-a.zip"))
	filesystem.setRequirePath("mods/custom/?.lua")
	package.loaded.alternate = nil
	assert(not pcall(require, "alternate"))
	filesystem.setRequirePath("?.lua;?/init.lua")
	assert(filesystem.read("mods/asset.txt") == nil)
	assert(filesystem.getRealDirectory("mods/asset.txt") == nil)
	assert(not filesystem.mount("corrupt.zip", "bad"))
	assert(not filesystem.mount("unsafe.zip", "unsafe"))
	assert(not filesystem.mount("archive-a.zip", "../escape"))

	-- Leave one archive mounted. LoveRuntime close must release its retained
	-- Data and ask LoveNode to remove the instance staging root.
	assert(filesystem.mount("archive-a.zip", "mounted-at-close"))
	print("LOVE_MOUNT_LOAD_PASS")
end

function love.update()
	frame = frame + 1
	if frame == 2 then
		print("LOVE_MOUNT_CYCLE_PASS")
		love.event.quit()
	end
end
