local love = require("love")
love.filesystem.setIdentity("love-thread-workflow")

local generation
local resultChannel
local worker
local badWorker
local result
local sawThreadError = false

local function readGeneration()
	if not love.filesystem.getInfo("generation.txt", "file") then return 0 end
	return tonumber(love.filesystem.read("generation.txt") or "0") or 0
end

generation = readGeneration() + 1
assert(love.filesystem.write("generation.txt", tostring(generation)))

function love.load()
	resultChannel = love.thread.getChannel("workflow-result")
	assert(resultChannel:getCount() == 0, "named Channel survived a LoveNode generation")
	worker = love.thread.newThread(love.filesystem.newFile("worker.lua"))
	assert(worker:start(resultChannel, generation))
	badWorker = love.thread.newThread("\nerror('workflow thread boom')\n")
	assert(badWorker:start())
end

function love.threaderror(thread, message)
	assert(thread == badWorker)
	assert(message:find("workflow thread boom", 1, true))
	sawThreadError = true
end

function love.update()
	result = result or resultChannel:pop()
	if not result or not sawThreadError then return end
	worker:wait()
	badWorker:wait()
	assert(worker:getError() == nil)
	assert(badWorker:getError():find("workflow thread boom", 1, true))
	assert(result.generation == generation and result.source == "worker.lua")
	assert(love.filesystem.write("status.txt",
		("thread=pass generation=%d source=content error=pass isolation=pass"):format(generation)))
	love.event.quit()
end
