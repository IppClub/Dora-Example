-- [yue]: Example/RenderTarget.yue
local _ENV = Dora -- 2
local Node <const> = Node -- 3
local Model <const> = Model -- 3
local Sequence <const> = Sequence -- 3
local X <const> = X -- 3
local Event <const> = Event -- 3
local RenderTarget <const> = RenderTarget -- 3
local Color <const> = Color -- 3
local Sprite <const> = Sprite -- 3
local Line <const> = Line -- 3
local Vec2 <const> = Vec2 -- 3
local App <const> = App -- 3
local threadLoop <const> = threadLoop -- 3
local ImGui <const> = ImGui -- 3
local node -- 5
do -- 5
	local _with_0 = Node() -- 5
	_with_0.order = 2 -- 6
	_with_0:addChild((function() -- 7
		local _with_1 = Model("Model/xiaoli.model") -- 7
		_with_1.y = -80 -- 8
		_with_1.fliped = true -- 9
		_with_1.look = "happy" -- 10
		_with_1:play("walk", true) -- 11
		_with_1:runAction(Sequence(X(2, -150, 250), Event("Turn"), X(2, 250, -150), Event("Turn")), true) -- 12
		_with_1:slot("Turn", function() -- 18
			_with_1.fliped = not _with_1.fliped -- 18
		end) -- 18
		return _with_1 -- 7
	end)()) -- 7
	node = _with_0 -- 5
end -- 5
local renderTarget -- 20
do -- 20
	local _with_0 = RenderTarget(300, 400) -- 20
	_with_0:renderWithClear(Color(0xff8a8a8a)) -- 21
	renderTarget = _with_0 -- 20
end -- 20
do -- 23
	local surface = Sprite(renderTarget.texture) -- 23
	surface.order = 1 -- 24
	surface.z = 300 -- 25
	surface.angleY = 25 -- 26
	surface:addChild(Line({ -- 28
		Vec2.zero, -- 28
		Vec2(300, 0), -- 29
		Vec2(300, 400), -- 30
		Vec2(0, 400), -- 31
		Vec2.zero -- 32
	}, App.themeColor)) -- 27
	surface:schedule(function() -- 34
		node.y = 200 -- 35
		renderTarget:renderWithClear(node, Color(0xff8a8a8a)) -- 36
		node.y = 0 -- 37
	end) -- 34
end -- 23
local windowFlags = { -- 42
	"NoDecoration", -- 42
	"AlwaysAutoResize", -- 42
	"NoSavedSettings", -- 42
	"NoFocusOnAppearing", -- 42
	"NoNav", -- 42
	"NoMove" -- 42
} -- 42
return threadLoop(function() -- 50
	local width -- 51
	width = App.visualSize.width -- 51
	ImGui.SetNextWindowBgAlpha(0.35) -- 52
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 53
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 54
	return ImGui.Begin("Render Target", windowFlags, function() -- 55
		ImGui.Text("Render Target (YueScript)") -- 56
		ImGui.Separator() -- 57
		return ImGui.TextWrapped("Use render target node as a mirror!") -- 58
	end) -- 55
end) -- 50
