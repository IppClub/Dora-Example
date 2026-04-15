-- [yue]: Example/Contact.yue
local _ENV = Dora -- 2
local Vec2 <const> = Vec2 -- 3
local PhysicsWorld <const> = PhysicsWorld -- 3
local Label <const> = Label -- 3
local BodyDef <const> = BodyDef -- 3
local math <const> = math -- 3
local Body <const> = Body -- 3
local Line <const> = Line -- 3
local App <const> = App -- 3
local string <const> = string -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local gravity = Vec2(0, -10) -- 5
local world -- 7
do -- 7
	local _with_0 = PhysicsWorld() -- 7
	_with_0:setShouldContact(0, 0, true) -- 8
	_with_0.showDebug = true -- 9
	world = _with_0 -- 7
end -- 7
local label -- 11
do -- 11
	local _with_0 = Label("sarasa-mono-sc-regular", 30) -- 11
	_with_0:addTo(world) -- 12
	label = _with_0 -- 11
end -- 11
local terrainDef -- 14
do -- 14
	local _with_0 = BodyDef() -- 14
	local count = 50 -- 15
	local radius = 300 -- 16
	local vertices -- 17
	do -- 17
		local _accum_0 = { } -- 17
		local _len_0 = 1 -- 17
		for i = 1, count + 1 do -- 17
			local angle = 2 * math.pi * i / count -- 18
			_accum_0[_len_0] = Vec2(radius * math.cos(angle), radius * math.sin(angle)) -- 19
			_len_0 = _len_0 + 1 -- 18
		end -- 17
		vertices = _accum_0 -- 17
	end -- 17
	_with_0:attachChain(vertices, 0.4, 0) -- 20
	_with_0:attachDisk(Vec2(0, -270), 30, 1, 0, 1.0) -- 21
	_with_0:attachPolygon(Vec2(0, 80), 120, 30, 0, 1, 0, 1.0) -- 22
	terrainDef = _with_0 -- 14
end -- 14
do -- 24
	local terrain = Body(terrainDef, world) -- 24
	terrain:addTo(world) -- 25
end -- 24
local drawNode -- 27
do -- 27
	local _with_0 = Line({ -- 28
		Vec2(-20, 0), -- 28
		Vec2(20, 0), -- 29
		Vec2.zero, -- 30
		Vec2(0, -20), -- 31
		Vec2(0, 20) -- 32
	}, App.themeColor) -- 27
	_with_0:addTo(world) -- 34
	drawNode = _with_0 -- 27
end -- 27
local diskDef -- 36
do -- 36
	local _with_0 = BodyDef() -- 36
	_with_0.type = "Dynamic" -- 37
	_with_0.linearAcceleration = gravity -- 38
	_with_0:attachDisk(20, 5, 0.8, 1) -- 39
	diskDef = _with_0 -- 36
end -- 36
local disk -- 41
do -- 41
	local _with_0 = Body(diskDef, world, Vec2(100, 200)) -- 41
	_with_0:addTo(world) -- 42
	_with_0.angularRate = -1800 -- 43
	_with_0:onContactStart(function(_target, point, _normal, _enabled) -- 44
		drawNode.position = point -- 45
		label.text = string.format("Contact: [%.0f,%.0f]", point.x, point.y) -- 46
	end) -- 44
	disk = _with_0 -- 41
end -- 41
local windowFlags = { -- 51
	"NoDecoration", -- 51
	"AlwaysAutoResize", -- 51
	"NoSavedSettings", -- 51
	"NoFocusOnAppearing", -- 51
	"NoNav", -- 51
	"NoMove" -- 51
} -- 51
local receivingContact = disk.receivingContact -- 59
return threadLoop(function() -- 60
	local width -- 61
	width = App.visualSize.width -- 61
	ImGui.SetNextWindowBgAlpha(0.35) -- 62
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 63
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 64
	return ImGui.Begin("Contact", windowFlags, function() -- 65
		ImGui.Text("Contact (YueScript)") -- 66
		ImGui.Separator() -- 67
		ImGui.TextWrapped("Receive events when physics bodies contact.") -- 68
		local changed -- 69
		changed, receivingContact = ImGui.Checkbox("Receiving Contact", receivingContact) -- 69
		if changed then -- 69
			disk.receivingContact = receivingContact -- 70
			label.text = "" -- 71
		end -- 69
	end) -- 65
end) -- 60
