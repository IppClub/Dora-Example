-- [yue]: Example/Camera.yue
local Node = Dora.Node -- 1
local Model = Dora.Model -- 1
local Sprite = Dora.Sprite -- 1
local Vec2 = Dora.Vec2 -- 1
local once = Dora.once -- 1
local Director = Dora.Director -- 1
local cycle = Dora.cycle -- 1
local Ease = Dora.Ease -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
do -- 4
	local _with_0 = Node() -- 4
	_with_0:addChild((function() -- 5
		local _with_1 = Model("Model/xiaoli.model") -- 5
		_with_1.look = "happy" -- 6
		_with_1:play("idle", true) -- 7
		return _with_1 -- 5
	end)()) -- 5
	_with_0:addChild((function() -- 9
		local _with_1 = Sprite("Image/logo.png") -- 9
		_with_1.scaleX = 0.4 -- 10
		_with_1.scaleY = 0.4 -- 11
		_with_1.position = Vec2(200, -100) -- 12
		_with_1.angleY = 45 -- 13
		_with_1.z = -300 -- 14
		return _with_1 -- 9
	end)()) -- 9
	_with_0:schedule(once(function() -- 16
		local _with_1 = Director.currentCamera -- 16
		cycle(1.5, function(dt) -- 17
			_with_1.position = Vec2(200 * Ease:func(Ease.InOutQuad, dt), 0) -- 17
		end) -- 17
		cycle(0.1, function(dt) -- 18
			_with_1.rotation = 25 * Ease:func(Ease.OutSine, dt) -- 18
		end) -- 18
		cycle(0.2, function(dt) -- 19
			_with_1.rotation = 25 - 50 * Ease:func(Ease.InOutQuad, dt) -- 19
		end) -- 19
		cycle(0.1, function(dt) -- 20
			_with_1.rotation = -25 + 25 * Ease:func(Ease.OutSine, dt) -- 20
		end) -- 20
		cycle(1.5, function(dt) -- 21
			_with_1.position = Vec2(200 * Ease:func(Ease.InOutQuad, 1 - dt), 0) -- 21
		end) -- 21
		local zoom = _with_1.zoom -- 22
		cycle(2.5, function(dt) -- 23
			_with_1.zoom = zoom + Ease:func(Ease.InOutQuad, dt) -- 23
		end) -- 23
		return _with_1 -- 16
	end)) -- 16
end -- 4
local windowFlags = { -- 28
	"NoDecoration", -- 28
	"AlwaysAutoResize", -- 28
	"NoSavedSettings", -- 28
	"NoFocusOnAppearing", -- 28
	"NoNav", -- 28
	"NoMove" -- 28
} -- 28
return threadLoop(function() -- 36
	local width -- 37
	width = App.visualSize.width -- 37
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 38
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 39
	return ImGui.Begin("Camera", windowFlags, function() -- 40
		ImGui.Text("Camera (YueScript)") -- 41
		ImGui.Separator() -- 42
		return ImGui.TextWrapped("View camera motions, use 3D camera as default!") -- 43
	end) -- 43
end) -- 43
