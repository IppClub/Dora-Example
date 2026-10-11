-- Run in an isolated native engine with a screenshot path supplied by init.lua.
return function(screenshotPath)
	local D = require('Dora')
	local V, C = D.Vec2, D.Color
	local draw = D.DrawNode()
	for _, name in ipairs({'drawRoundedRect', 'drawRing', 'drawSector', 'drawQuadraticBezier', 'drawCubicBezier'}) do
		assert(type(draw[name]) == 'function', 'Missing Lua binding: ' .. name)
	end
	draw:drawRect(D.Rect(-630, -330, 1260, 660), C(0xffeeeeee))
	draw:drawRoundedRect(D.Rect(-560, 80, 290, 190), 45, C(0xff58c7d8), 5, C(0xff24536a))
	draw:drawRing(V(-40, 180), 48, 100, C(0xff8f7cff), 4, C(0xff483870))
	draw:drawSector(V(270, 175), 110, 35, 305, C(0xffffb060), 4, C(0xff805020))
	-- Full-circle sector border: no line through its center.
	draw:drawSector(V(500, 165), 65, 0, -720, C(0xffb0d878), 3, C(0xff486038))
	draw:drawQuadraticBezier(V(-550, -210), V(-390, 120), V(-230, -210), 9, C(0x806030d0))
	draw:drawCubicBezier(V(-150, -100), V(-80, 170), V(80, -350), V(190, -100), 9, C(0x80309070))
	-- Coincident endpoints form a loop rather than disappearing.
	draw:drawCubicBezier(V(330, -210), V(180, 60), V(600, 60), V(330, -210), 7, C(0x80df6878))
	-- Optional color and border defaults are exercised through real Lua bindings.
	draw:drawRoundedRect(D.Rect(490, -230, 60, 60), 50)
	draw:drawRing(V(510, -80), 15, 30)
	draw:addTo(D.Director.entry)
	local frames = 0
	draw:schedule(function()
		frames = frames + 1
		if frames == 4 then D.App:saveScreenshot(screenshotPath)
		elseif frames == 12 then D.App:shutdown(); return true end
		return false
	end)
end
