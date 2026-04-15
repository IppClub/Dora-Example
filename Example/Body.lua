-- [yue]: Example/Body.yue
local _ENV = Dora -- 2
local Vec2 <const> = Vec2 -- 3
local BodyDef <const> = BodyDef -- 3
local PhysicsWorld <const> = PhysicsWorld -- 3
local Body <const> = Body -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local gravity <const> = Vec2(0, -10) -- 5
local groupZero <const> = 0 -- 7
local groupOne <const> = 1 -- 8
local groupTwo <const> = 2 -- 9
local terrainDef -- 11
do -- 11
	local _with_0 = BodyDef() -- 11
	_with_0.type = "Static" -- 12
	_with_0:attachPolygon(800, 10, 1, 0.8, 0.2) -- 13
	terrainDef = _with_0 -- 11
end -- 11
local polygonDef -- 15
do -- 15
	local _with_0 = BodyDef() -- 15
	_with_0.type = "Dynamic" -- 16
	_with_0.linearAcceleration = gravity -- 17
	_with_0:attachPolygon({ -- 19
		Vec2(60, 0), -- 19
		Vec2(30, -30), -- 20
		Vec2(-30, -30), -- 21
		Vec2(-60, 0), -- 22
		Vec2(-30, 30), -- 23
		Vec2(30, 30) -- 24
	}, 1, 0.4, 0.4) -- 18
	polygonDef = _with_0 -- 15
end -- 15
local diskDef -- 27
do -- 27
	local _with_0 = BodyDef() -- 27
	_with_0.type = "Dynamic" -- 28
	_with_0.linearAcceleration = gravity -- 29
	_with_0:attachDisk(60, 1, 0.4, 0.4) -- 30
	diskDef = _with_0 -- 27
end -- 27
do -- 32
	local world = PhysicsWorld() -- 32
	world.y = -200 -- 33
	world.showDebug = true -- 34
	world:setShouldContact(groupZero, groupOne, false) -- 36
	world:setShouldContact(groupZero, groupTwo, true) -- 37
	world:setShouldContact(groupOne, groupTwo, true) -- 38
	world:addChild((function() -- 40
		local _with_0 = Body(terrainDef, world, Vec2.zero) -- 40
		_with_0.group = groupTwo -- 41
		return _with_0 -- 40
	end)()) -- 40
	world:addChild((function() -- 43
		local _with_0 = Body(polygonDef, world, Vec2(0, 500), 15) -- 43
		_with_0.group = groupOne -- 44
		return _with_0 -- 43
	end)()) -- 43
	world:addChild((function() -- 46
		local _with_0 = Body(diskDef, world, Vec2(50, 800)) -- 46
		_with_0.group = groupZero -- 47
		_with_0.angularRate = 90 -- 48
		return _with_0 -- 46
	end)()) -- 46
end -- 32
local windowFlags = { -- 53
	"NoDecoration", -- 53
	"AlwaysAutoResize", -- 53
	"NoSavedSettings", -- 53
	"NoFocusOnAppearing", -- 53
	"NoNav", -- 53
	"NoMove" -- 53
} -- 53
return threadLoop(function() -- 61
	local width -- 62
	width = App.visualSize.width -- 62
	ImGui.SetNextWindowBgAlpha(0.35) -- 63
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 64
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 65
	return ImGui.Begin("Body", windowFlags, function() -- 66
		ImGui.Text("Body (Yuescript)") -- 67
		ImGui.Separator() -- 68
		return ImGui.TextWrapped("Basic usage to create physics bodies!") -- 69
	end) -- 66
end) -- 61
