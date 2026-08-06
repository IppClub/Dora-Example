local channel, value = ...
assert(require("love.thread") == love.thread)
assert(require("love.filesystem") == love.filesystem)
assert(love.filesystem.getInfo("thread-worker.lua", "file"))
channel:push({value = value, worker = true})
