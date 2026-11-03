local D = require("Dora")
D.App.devMode = false
local C, P = D.Content, D.Path
local project = P(C.writablePath, "godot-await-cleanup-v1")
assert(not C:exist(project), "Use fresh test data")
assert(C:copy("GodotAwaitCleanup", project))
local cache = P(project, ".godot")
assert(C:mkdir(cache))
assert(C:save(P(cache, "global_script_class_cache.cfg"), "list=[]\n"))
local game = assert(D.GodotNode(project, "", 320, 240, 3))
game:addTo(D.Director.ui)
local control = D.Node()
control:addTo(D.Director.ui)
local ticks, elapsed = 0, 0
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 40, "Android await cleanup timed out")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if game and not game.running then return false end
 ticks = ticks + 1
 if ticks == 120 then game:removeFromParent(); game = nil end
 if ticks == 150 then
  print("AWAIT_CLEANUP host complete")
  local work = P(C.writablePath, "godot-release")
  if not C:exist(work) then assert(C:mkdir(work)) end
  assert(C:save(P(work, "result.json"), '{"complete":true,"full":false,"await":true}'))
  D.App:shutdown()
  return true
 end
 return false
end)
