-- [yue]: Example/Gesture.yue
local nvg = Dora.nvg -- 1
local Sprite = Dora.Sprite -- 1
local Vec2 = Dora.Vec2 -- 1
local View = Dora.View -- 1
local Node = Dora.Node -- 1
local threadLoop = Dora.threadLoop -- 1
local App = Dora.App -- 1
local ImGui = Dora.ImGui -- 1
local texture = nvg.GetDoraSSR() -- 4
local sprite = Sprite(texture) -- 5
local length = Vec2(View.size).length -- 6
local width, height = sprite.width, sprite.height -- 7
local size = Vec2(width, height).length -- 8
local scaledSize = size -- 9
do -- 11
	local _with_0 = Node() -- 11
	_with_0:addChild(sprite) -- 12
	_with_0:onGesture(function(center, _numTouches, delta, angle) -- 13
		sprite.position = center -- 17
		sprite.angle = sprite.angle + angle -- 18
		scaledSize = scaledSize + (delta * length) -- 19
		sprite.scaleX = scaledSize / size -- 20
		sprite.scaleY = scaledSize / size -- 21
	end) -- 13
end -- 11
local windowFlags = { -- 26
	"NoDecoration", -- 26
	"AlwaysAutoResize", -- 26
	"NoSavedSettings", -- 26
	"NoFocusOnAppearing", -- 26
	"NoNav", -- 26
	"NoMove" -- 26
} -- 26
return threadLoop(function() -- 34
	local width -- 35
	width = App.visualSize.width -- 35
	ImGui.SetNextWindowBgAlpha(0.35) -- 36
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 37
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 38
	return ImGui.Begin("Gesture", windowFlags, function() -- 39
		ImGui.Text("Gesture (YueScript)") -- 40
		ImGui.Separator() -- 41
		return ImGui.TextWrapped("Interact with multi-touches!") -- 42
	end) -- 42
end) -- 42
