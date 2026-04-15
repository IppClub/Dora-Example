-- [yue]: Example/Camera.yue
local _ENV = Dora -- 2
local Node <const> = Node -- 3
local Model <const> = Model -- 3
local Sprite <const> = Sprite -- 3
local Vec2 <const> = Vec2 -- 3
local once <const> = once -- 3
local Director <const> = Director -- 3
local cycle <const> = cycle -- 3
local Ease <const> = Ease -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
do -- 5
	local _with_0 = Node() -- 5
	_with_0:addChild((function() -- 6
		local _with_1 = Model("Model/xiaoli.model") -- 6
		_with_1.look = "happy" -- 7
		_with_1:play("idle", true) -- 8
		return _with_1 -- 6
	end)()) -- 6
	_with_0:addChild((function() -- 10
		local _with_1 = Sprite("Image/logo.png") -- 10
		_with_1.scaleX = 0.4 -- 11
		_with_1.scaleY = 0.4 -- 12
		_with_1.position = Vec2(200, -100) -- 13
		_with_1.angleY = 45 -- 14
		_with_1.z = -300 -- 15
		return _with_1 -- 10
	end)()) -- 10
	_with_0:schedule(once(function() -- 17
		local _with_1 = Director.currentCamera -- 17
		cycle(1.5, function(dt) -- 18
			_with_1.position = Vec2(200 * Ease:func(Ease.InOutQuad, dt), 0) -- 18
		end) -- 18
		cycle(0.1, function(dt) -- 19
			_with_1.rotation = 25 * Ease:func(Ease.OutSine, dt) -- 19
		end) -- 19
		cycle(0.2, function(dt) -- 20
			_with_1.rotation = 25 - 50 * Ease:func(Ease.InOutQuad, dt) -- 20
		end) -- 20
		cycle(0.1, function(dt) -- 21
			_with_1.rotation = -25 + 25 * Ease:func(Ease.OutSine, dt) -- 21
		end) -- 21
		cycle(1.5, function(dt) -- 22
			_with_1.position = Vec2(200 * Ease:func(Ease.InOutQuad, 1 - dt), 0) -- 22
		end) -- 22
		local zoom = _with_1.zoom -- 23
		cycle(2.5, function(dt) -- 24
			_with_1.zoom = zoom + Ease:func(Ease.InOutQuad, dt) -- 24
		end) -- 24
		return _with_1 -- 17
	end)) -- 17
end -- 5
local windowFlags = { -- 29
	"NoDecoration", -- 29
	"AlwaysAutoResize", -- 29
	"NoSavedSettings", -- 29
	"NoFocusOnAppearing", -- 29
	"NoNav", -- 29
	"NoMove" -- 29
} -- 29
return threadLoop(function() -- 37
	local width -- 38
	width = App.visualSize.width -- 38
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 39
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 40
	return ImGui.Begin("Camera", windowFlags, function() -- 41
		ImGui.Text("Camera (YueScript)") -- 42
		ImGui.Separator() -- 43
		return ImGui.TextWrapped("View camera motions, use 3D camera as default!") -- 44
	end) -- 41
end) -- 37
