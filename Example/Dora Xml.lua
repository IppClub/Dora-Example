-- [xml]: Example/Dora Xml.xml
local Path = require("Path") -- 4
local selfPath = Path(Path:getScriptPath(...), "Dora Xml.xml") -- 5
return function(args) -- 1
local _ENV = Dora(args) -- 1
local root = Node() -- 7
local rotate = Action(Spawn(Sequence(Move(1,Vec2(0,0),Vec2(200,0),Ease.InSine),Move(2,Vec2(200,0),Vec2(0,200),Ease.OutSine),Move(2,Vec2(0,200),Vec2(0,0),Ease.InSine)),Angle(6,0,360,Ease.OutQuad))) -- 9
local scale = Action(Sequence(Scale(0.2,1,1.3,Ease.OutBack),Scale(0.2,1.3,1,Ease.OutQuad))) -- 17
local sprite1 = Sprite("Image/logo.png") -- 22
sprite1.touchEnabled = true -- 22
root:addChild(sprite1) -- 22
sprite1:slot("TapBegan",function() -- 23
sprite1:perform(scale) -- 23
end) -- 23
root:slot("Enter",function() -- 25
root:perform(rotate) -- 25
end) -- 25
do -- 27
	local _ENV = Dora -- 29
	local xmlCodes = Content:load(selfPath) -- 30
	local luaCodes = xml.tolua(xmlCodes) -- 31
	print("[Xml Codes]\n\n" .. tostring(xmlCodes) .. "\n[Compiled Lua Codes]\n\n" .. tostring(luaCodes)) -- 32
	local windowFlags = { -- 34
		"NoDecoration", -- 34
		"AlwaysAutoResize", -- 34
		"NoSavedSettings", -- 34
		"NoFocusOnAppearing", -- 34
		"NoNav", -- 34
		"NoMove" -- 34
	} -- 34
	root:schedule(function() -- 42
		local width = App.visualSize.width -- 43
		ImGui.SetNextWindowBgAlpha(0.35) -- 44
		ImGui.SetNextWindowPos(Vec2(width - 10, 10), "Always", Vec2(1, 0)) -- 45
		ImGui.SetNextWindowSize(Vec2(240, 0), "FirstUseEver") -- 46
		return ImGui.Begin("Dora Xml", windowFlags, function() -- 47
			ImGui.Text("Dora Xml (Xml)") -- 48
			ImGui.Separator() -- 49
			return ImGui.TextWrapped("View related codes in log window!") -- 50
		end) -- 50
	end) -- 42
end -- 50
return root -- 28
end