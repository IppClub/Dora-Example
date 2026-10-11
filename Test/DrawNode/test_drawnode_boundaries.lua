-- Run in an isolated native engine with a screenshot path supplied by init.lua.
return function(screenshotPath)
	local D = require('Dora')
	local V, C = D.Vec2, D.Color
	local draw = D.DrawNode()
	draw:drawRect(D.Rect(-630, -330, 1260, 660), C(0xffeeeeee))
	-- Collapsed insets and merged ring borders must have one coverage layer.
	draw:drawRoundedRect(D.Rect(-560, 130, 300, 90), 24, C(0), 60, C(0x805030d0))
	draw:drawRing(V(0, 160), 50, 60, C(0), 8, C(0x805030d0))
	draw:drawRoundedRect(D.Rect(160, 70, 280, 180), 45, C(0), 8, C(0x805030d0))
	draw:drawSector(V(280, 0), 40, 0, 359, C(0), 12, C(0x805030d0))
	draw:drawSector(V(-130, 0), 30, 0, 90, C(0), 20, C(0x805030d0))
	-- Magnify tiny geometry to expose lost curvature and fixed-epsilon failures.
	local small = D.DrawNode()
	small:drawRoundedRect(D.Rect(0, 0, .001, .0006), .0003, C(0xff58c7d8))
	small:drawSector(V(.0017, .0003), .0003, 0, 270, C(0xffffb060))
	small:drawQuadraticBezier(V(.0023, 0), V(.0028, .001), V(.0033, 0), .00004, C(0x806030d0))
	small.scaleX, small.scaleY = 300000, 300000
	small.position = V(-550, -230)
	small:addTo(draw)
	-- Cancel a large local-coordinate translation in the node transform.
	local large = D.DrawNode()
	large:drawSector(V(10000000, 10000000), 100, 0, 270, C(0xffb0d878))
	large.position = V(-10000000 + 510, -10000000 - 100)
	large:addTo(draw)
	draw:addTo(D.Director.entry)
	local frames = 0
	draw:schedule(function()
		frames = frames + 1
		if frames == 4 then D.App:saveScreenshot(screenshotPath)
		elseif frames == 12 then D.App:shutdown(); return true end
		return false
	end)
end
