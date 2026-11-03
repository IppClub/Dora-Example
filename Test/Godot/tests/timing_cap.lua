local D = Dora
local engineReadback = @ENGINE_READBACK@
D.App.devMode = false
-- captureGameAsync downsizes buffers larger than 1280 pixels. Keep the
-- clock barcode on the native pixel grid instead of testing resampling.
local priorWinSize
if not engineReadback then
 priorWinSize = D.App.winSize
 D.App.winSize = D.Size(640, 480)
end
local game = assert(D.GodotNode(@PROJECT@, "", 640, 360, @BUFFERS@))
game:addTo(D.Director.ui)
local control = D.Node()
control:addTo(D.Director.ui)
assert(D.Director:beginGameCapture())
local elapsed = 0
local captured, pending = {}, false
local resized = false
control:schedule(function(dt)
 elapsed = elapsed + dt
 assert(elapsed < 45, "Clock contract timeout")
 assert(game == nil or game.lastError == "", game and game.lastError)
 if pending then return false end
 if engineReadback and @RESIZE@ and not resized and D.Content:exist(@OUTPUT@ .. "/clock-a.png") then
  assert(game:resizeViewport(800, 450), "Clock readback resize")
  resized = true
 end
 for _, name in ipairs({"clock-a", "clock-b"}) do
  local marker = @OUTPUT@ .. "/" .. name .. ".ready"
  if not captured[name] and D.Content:exist(marker) then
   pending = true
   assert(D.Director:captureGameAsync(@OUTPUT@ .. "/" .. name .. ".png", function(ok, capturedAt, sourceSize)
    assert(ok, "Clock contract screenshot")
    assert(sourceSize.width > 0 and sourceSize.height > 0 and math.max(sourceSize.width, sourceSize.height) <= 1280, "Clock contract capture must not downscale")
    assert(D.Content:save(@OUTPUT@ .. "/" .. name .. ".source.json", string.format('{"width":%d,"height":%d,"captured_at":%.9f}', sourceSize.width, sourceSize.height, capturedAt)))
    captured[name] = true
    assert(D.Content:save(@OUTPUT@ .. "/" .. name .. ".ack", "captured"))
    pending = false
   end))
   return false
  end
 end
 if (engineReadback or captured["clock-b"]) and D.Content:exist(@RESULT@) then
  if game then game:removeFromParent();game=nil end
  if priorWinSize then D.App.winSize = priorWinSize end
  print("TIMING_CAP host complete")
  D.App:shutdown()
  return true
 end
 return false
end)
