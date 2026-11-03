-- A present Godot runtime must not be started by an incompatible Dora renderer.
local D = Dora
D.App.devMode = false
assert(D.GodotNode.getUnsupportedReason() == @UNSUPPORTED_REASON@)
assert(D.Director:beginGameCapture())
local ordinary = D.DrawNode()
ordinary:drawPolygon({D.Vec2(-40,-40),D.Vec2(40,-40),D.Vec2(40,40),D.Vec2(-40,40)},D.Color(0xff00ff00))
ordinary.x = -220
ordinary:addTo(D.Director.ui, 100)
assert(D.GodotNode(@PROJECT@, "res://main.tscn", 640, 360, 3) == nil)
print("GODOT_ORDINARY unsupported_backend_rejected=1")
local control = D.Node()
control:addTo(D.Director.ui)
local elapsed, phase, captured = 0, 0, 0
control:schedule(function(dt)
    elapsed = elapsed + dt
    if elapsed > 20 then error("Ordinary backend fallback timed out") end
    if phase < 2 and captured == phase and elapsed > (phase == 0 and 1 or 2) then
        phase = phase + 1
        ordinary.x = phase == 1 and -220 or 220
        local name = "frame-" .. phase .. ".png"
        assert(D.Director:captureGameAsync(@OUTPUT@ .. "/" .. name, function(ok)
            assert(ok)
            captured = captured + 1
            print("GODOT_ORDINARY capture=" .. name)
        end))
    end
    if captured == 2 and elapsed > 4 then
        print("GODOT_ORDINARY complete=1")
        D.Director:endGameCapture()
        D.App:shutdown()
        return true
    end
    return false
end)
