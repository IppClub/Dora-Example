-- Extreme translucent strokes. Compare screenshots before and after changes
-- to the clipping implementation; tessellation must retain the same coverage.
return function(screenshotPath)
	local D = require('Dora')
	local V, C = D.Vec2, D.Color
	local root = D.DrawNode()
	root:drawRect(D.Rect(-630, -330, 1260, 660), C(0xffeeeeee))
	for column, sweep in ipairs({30, 270, 359, -270}) do
		for row, width in ipairs({6000, 12000}) do
			local draw = D.DrawNode()
			draw:drawSector(V(0, 0), 10000, 0, sweep, C(0), width, C(0x805030d0))
			draw.scaleX, draw.scaleY = .005, .005
			draw.position = V(-440 + (column - 1) * 280, 180 - (row - 1) * 320)
			draw:addTo(root)
		end
	end
	root:addTo(D.Director.entry)
	local frames = 0
	root:schedule(function()
		frames = frames + 1
		if frames == 4 then D.App:saveScreenshot(screenshotPath)
		elseif frames == 12 then D.App:shutdown(); return true end
		return false
	end)
end
