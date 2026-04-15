-- [yue]: Example/Gesture.yue
local _ENV = Dora -- 2
local nvg <const> = nvg -- 3
local Sprite <const> = Sprite -- 3
local Vec2 <const> = Vec2 -- 3
local View <const> = View -- 3
local Node <const> = Node -- 3
local threadLoop <const> = threadLoop -- 3
local App <const> = App -- 3
local ImGui <const> = ImGui -- 3
local texture = nvg.GetDoraSSR() -- 5
local sprite = Sprite(texture) -- 6
local length = Vec2(View.size).length -- 7
local width, height = sprite.width, sprite.height -- 8
local size = Vec2(width, height).length -- 9
local scaledSize = size -- 10
do -- 12
	local _with_0 = Node() -- 12
	_with_0:addChild(sprite) -- 13
	_with_0:onGesture(function(center, _numTouches, delta, angle) -- 14
		sprite.position = center -- 18
		sprite.angle = sprite.angle + angle -- 19
		scaledSize = scaledSize + (delta * length) -- 20
		sprite.scaleX = scaledSize / size -- 21
		sprite.scaleY = scaledSize / size -- 22
	end) -- 14
end -- 12
local windowFlags = { -- 27
	"NoDecoration", -- 27
	"AlwaysAutoResize", -- 27
	"NoSavedSettings", -- 27
	"NoFocusOnAppearing", -- 27
	"NoNav", -- 27
	"NoMove" -- 27
} -- 27
return threadLoop(function() -- 35
	local width -- 36
	width = App.visualSize.width -- 36
	ImGui.SetNextWindowBgAlpha(0.35) -- 37
	ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 38
	ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 39
	return ImGui.Begin("Gesture", windowFlags, function() -- 40
		ImGui.Text("Gesture (YueScript)") -- 41
		ImGui.Separator() -- 42
		return ImGui.TextWrapped("Interact with multi-touches!") -- 43
	end) -- 40
end) -- 35
