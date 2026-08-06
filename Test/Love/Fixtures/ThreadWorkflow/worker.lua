-- workflow-result worker loaded through Dora Content.
local channel, generation = ...
local source = assert(love.filesystem.read("worker.lua"))
assert(source:find("workflow%-result"))
channel:push({generation = generation, source = "worker.lua"})
