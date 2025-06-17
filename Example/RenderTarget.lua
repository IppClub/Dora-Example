-- [yue]: Example/RenderTarget.yue
local Node = Dora.Node -- 1
local Model = Dora.Model -- 1
local Sequence = Dora.Sequence -- 1
local X = Dora.X -- 1
local Event = Dora.Event -- 1
local RenderTarget = Dora.RenderTarget -- 1
local Color = Dora.Color -- 1
local Sprite = Dora.Sprite -- 1
local Line = Dora.Line -- 1
local Vec2 = Dora.Vec2 -- 1
local App = Dora.App -- 1
local threadLoop = Dora.threadLoop -- 1
local ImGui = Dora.ImGui -- 1
local node -- 4
do -- 4
	local _with_0 = Node() -- 4
	_with_0.order = 2 -- 5
	_with_0:addChild((function() -- 6
		local _with_1 = Model("Model/xiaoli.model") -- 6
		_with_1.y = -80 -- 7
		_with_1.fliped = true -- 8
		_with_1.look = "happy" -- 9
		_with_1:play("walk", true) -- 10
		_with_1:runAction(Sequence(X(2, -150, 250), Event("Turn"), X(2, 250, -150), Event("Turn")), true) -- 11
		_with_1:slot("Turn", function() -- 17
			_with_1.fliped = not _with_1.fliped -- 17
		end) -- 17
		return _with_1 -- 6
	end)()) -- 6
	node = _with_0 -- 4
end -- 4
local renderTarget -- 19
do -- 19
	local _with_0 = RenderTarget(300, 400) -- 19
	_with_0:renderWithClear(Color(0xff8a8a8a)) -- 20
	renderTarget = _with_0 -- 19
end -- 19
do -- 22
	local surface = Sprite(renderTarget.texture) -- 22
	surface.order = 1 -- 23
	surface.z = 300 -- 24
	surface.angleY = 25 -- 25
	surface:addChild(Line({ -- 27
		Vec2.zero, -- 27
		Vec2(300, 0), -- 28
		Vec2(300, 400), -- 29
		Vec2(0, 400), -- 30
		Vec2.zero -- 31
	}, App.themeColor)) -- 26
	surface:schedule(function() -- 33
		node.y = 200 -- 34
		renderTarget:renderWithClear(node, Color(0xff8a8a8a)) -- 35
		node.y = 0 -- 36
	end) -- 33
end -- 22
local windowFlags = { -- 41
	"NoDecoration", -- 41
	"AlwaysAutoResize", -- 41
	"NoSavedSettings", -- 41
	"NoFocusOnAppearing", -- 41
	"NoNav", -- 41
	"NoMove" -- 41
} -- 41
return threadLoop(function() -- 49
	local width -- 50
	width = App.visualSize.width -- 50
	ImGui.SetNextWindowBgAlpha(0.35) -- 51
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 52
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 53
	return ImGui.Begin("Render Target", windowFlags, function() -- 54
		ImGui.Text("Render Target (YueScript)") -- 55
		ImGui.Separator() -- 56
		return ImGui.TextWrapped("Use render target node as a mirror!") -- 57
	end) -- 57
end) -- 57
