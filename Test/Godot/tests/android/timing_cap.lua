local D = require("Dora")
D.App.devMode = false
local C, P = D.Content, D.Path
local work = P(C.writablePath, "godot-release")
local buffers = assert(tonumber(C:load(P(work, "buffers.txt"))))
assert(buffers >= 2 and buffers <= 4)
local project = P(work, "project")
assert(C:copy("GodotTimingCap", project))
assert(C:mkdir(P(project, ".godot")))
assert(C:save(P(project, ".godot/global_script_class_cache.cfg"), "list=[]\n"))
assert(C:save(P(project, "dora-output-path.txt"), project))
local game = assert(D.GodotNode(project, "res://android_timing_cap.tscn", 640, 360, buffers))
game:addTo(D.Director.ui)
local scale = math.min(D.View.size.width / 800, D.View.size.height / 450) * 0.65
game.scaleX, game.scaleY = scale, scale
local control = D.Node()
control:addTo(D.Director.ui)
local elapsed, resized, closing = 0, false, 0
local metadata
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 45, "Android readback timeout")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if not resized and C:exist(P(project, "clock-a.png")) then
  assert(game:resizeViewport(800, 450))
  resized = true
 end
 if not metadata and C:exist(P(project, "result.json")) then
  assert(resized)
  for _, name in ipairs({"clock-a.png", "clock-b.png"}) do
   assert(C:copy(P(project, name), P(work, name)))
  end
  metadata = assert(C:load(P(project, "result.json")))
  assert(metadata:sub(-1) == "}")
  game:removeFromParent()
  game = nil
 end
 if metadata then
  closing = closing + 1
  if closing == 30 then
   print("TIMING_CAP host complete")
   local result = metadata:sub(1, -2) .. string.format(',"complete":true,"full":false,"buffers":%d}', buffers)
   assert(C:save(P(work, "result.json"), result))
   return true
  end
 end
 return false
end)
