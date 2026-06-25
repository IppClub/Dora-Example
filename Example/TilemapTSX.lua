-- [tsx]: TilemapTSX.tsx
local ____exports = {} -- 1
local ____DoraX = require("DoraX") -- 2
local React = ____DoraX.React -- 2
local reference = ____DoraX.reference -- 2
local toNode = ____DoraX.toNode -- 2
local ____Dora = require("Dora") -- 3
local App = ____Dora.App -- 3
local Vec2 = ____Dora.Vec2 -- 3
local threadLoop = ____Dora.threadLoop -- 3
local ImGui = require("ImGui") -- 5
local current -- 7
local function TMX(file) -- 9
	if current then -- 9
		current:removeFromParent() -- 11
	end -- 11
	local tileNodeRef = reference() -- 13
	current = toNode(React.createElement( -- 14
		"align-node", -- 14
		{ -- 14
			windowRoot = true, -- 14
			onTapMoved = function(touch) -- 14
				if tileNodeRef.current then -- 14
					tileNodeRef.current.position = tileNodeRef.current.position:add(touch.delta) -- 17
				end -- 17
			end -- 15
		}, -- 15
		React.createElement("tile-node", {ref = tileNodeRef, file = file}) -- 15
	)) -- 15
end -- 9
local files = {"TMX/platform.tmx", "TMX/demo.tmx"} -- 25
TMX(files[1]) -- 30
local currentTest = 1 -- 32
local windowFlags = {"NoDecoration", "NoSavedSettings", "NoFocusOnAppearing", "NoMove"} -- 33
threadLoop(function() -- 39
	local ____App_visualSize_0 = App.visualSize -- 40
	local width = ____App_visualSize_0.width -- 40
	ImGui.SetNextWindowPos( -- 41
		Vec2(width - 10, 10), -- 41
		"Always", -- 41
		Vec2(1, 0) -- 41
	) -- 41
	ImGui.SetNextWindowSize( -- 42
		Vec2(200, 0), -- 42
		"Always" -- 42
	) -- 42
	ImGui.Begin( -- 43
		"Tilemap", -- 43
		windowFlags, -- 43
		function() -- 43
			ImGui.Text("Tilemap (TSX)") -- 44
			ImGui.Separator() -- 45
			ImGui.TextWrapped("Drag to view the whole scene.") -- 46
			local changed = false -- 47
			changed, currentTest = ImGui.Combo("File", currentTest, files) -- 48
			if changed then -- 48
				TMX(files[currentTest]) -- 50
			end -- 50
		end -- 43
	) -- 43
	return false -- 53
end) -- 39
return ____exports -- 39