-- [yue]: Example/Contact.yue
local Vec2 = Dora.Vec2 -- 1
local PhysicsWorld = Dora.PhysicsWorld -- 1
local Label = Dora.Label -- 1
local BodyDef = Dora.BodyDef -- 1
local math = _G.math -- 1
local Body = Dora.Body -- 1
local Line = Dora.Line -- 1
local App = Dora.App -- 1
local string = _G.string -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local gravity = Vec2(0, -10) -- 4
local world -- 6
do -- 6
	local _with_0 = PhysicsWorld() -- 6
	_with_0:setShouldContact(0, 0, true) -- 7
	_with_0.showDebug = true -- 8
	world = _with_0 -- 6
end -- 6
local label -- 10
do -- 10
	local _with_0 = Label("sarasa-mono-sc-regular", 30) -- 10
	_with_0:addTo(world) -- 11
	label = _with_0 -- 10
end -- 10
local terrainDef -- 13
do -- 13
	local _with_0 = BodyDef() -- 13
	local count = 50 -- 14
	local radius = 300 -- 15
	local vertices -- 16
	do -- 16
		local _accum_0 = { } -- 16
		local _len_0 = 1 -- 16
		for i = 1, count + 1 do -- 16
			local angle = 2 * math.pi * i / count -- 17
			_accum_0[_len_0] = Vec2(radius * math.cos(angle), radius * math.sin(angle)) -- 18
			_len_0 = _len_0 + 1 -- 17
		end -- 18
		vertices = _accum_0 -- 16
	end -- 18
	_with_0:attachChain(vertices, 0.4, 0) -- 19
	_with_0:attachDisk(Vec2(0, -270), 30, 1, 0, 1.0) -- 20
	_with_0:attachPolygon(Vec2(0, 80), 120, 30, 0, 1, 0, 1.0) -- 21
	terrainDef = _with_0 -- 13
end -- 13
do -- 23
	local terrain = Body(terrainDef, world) -- 23
	terrain:addTo(world) -- 24
end -- 23
local drawNode -- 26
do -- 26
	local _with_0 = Line({ -- 27
		Vec2(-20, 0), -- 27
		Vec2(20, 0), -- 28
		Vec2.zero, -- 29
		Vec2(0, -20), -- 30
		Vec2(0, 20) -- 31
	}, App.themeColor) -- 26
	_with_0:addTo(world) -- 33
	drawNode = _with_0 -- 26
end -- 26
local diskDef -- 35
do -- 35
	local _with_0 = BodyDef() -- 35
	_with_0.type = "Dynamic" -- 36
	_with_0.linearAcceleration = gravity -- 37
	_with_0:attachDisk(20, 5, 0.8, 1) -- 38
	diskDef = _with_0 -- 35
end -- 35
local disk -- 40
do -- 40
	local _with_0 = Body(diskDef, world, Vec2(100, 200)) -- 40
	_with_0:addTo(world) -- 41
	_with_0.angularRate = -1800 -- 42
	_with_0:onContactStart(function(_target, point, _normal, _enabled) -- 43
		drawNode.position = point -- 44
		label.text = string.format("Contact: [%.0f,%.0f]", point.x, point.y) -- 45
	end) -- 43
	disk = _with_0 -- 40
end -- 40
local windowFlags = { -- 50
	"NoDecoration", -- 50
	"AlwaysAutoResize", -- 50
	"NoSavedSettings", -- 50
	"NoFocusOnAppearing", -- 50
	"NoNav", -- 50
	"NoMove" -- 50
} -- 50
local receivingContact = disk.receivingContact -- 58
return threadLoop(function() -- 59
	local width -- 60
	width = App.visualSize.width -- 60
	ImGui.SetNextWindowBgAlpha(0.35) -- 61
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 62
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 63
	return ImGui.Begin("Contact", windowFlags, function() -- 64
		ImGui.Text("Contact (YueScript)") -- 65
		ImGui.Separator() -- 66
		ImGui.TextWrapped("Receive events when physics bodies contact.") -- 67
		local changed -- 68
		changed, receivingContact = ImGui.Checkbox("Receiving Contact", receivingContact) -- 68
		if changed then -- 68
			disk.receivingContact = receivingContact -- 69
			label.text = "" -- 70
		end -- 68
	end) -- 70
end) -- 70
