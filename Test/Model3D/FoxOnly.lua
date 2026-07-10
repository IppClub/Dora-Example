-- [ts]: FoxOnly.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Camera3D = ____Dora.Camera3D -- 2
local Director = ____Dora.Director -- 2
local Model3D = ____Dora.Model3D -- 2
local Vec2 = ____Dora.Vec2 -- 2
local Vec3 = ____Dora.Vec3 -- 2
local threadLoop = ____Dora.threadLoop -- 2
local ImGui = require("ImGui") -- 4
local camera = Camera3D() -- 6
camera:lookAt( -- 7
	Vec3(0, 0.75, 3.2), -- 7
	Vec3(0, 0.45, 0) -- 7
) -- 7
Director:pushCamera(camera) -- 8
local view = Director.entry -- 10
view:setEnvironmentMap("Test/Model3D/Assets/Env/studio.png") -- 12
view:setEnvironmentIntensity(1, 1.8, 1.2) -- 13
local fox = Model3D("Test/Model3D/Assets/Model/Fox.glb") -- 15
view:addChild(fox) -- 16
fox.scaleX = 0.015 -- 17
fox.scaleY = 0.015 -- 18
fox.scaleZ = 0.015 -- 19
fox.speed = 1 -- 20
fox:play("Run", true) -- 21
local elapsed = 0 -- 23
local speed = 1 -- 24
threadLoop(function() -- 26
	elapsed = elapsed + App.deltaTime -- 27
	fox.angleY = elapsed * 22.5 -- 28
	local ____App_visualSize_0 = App.visualSize -- 30
	local width = ____App_visualSize_0.width -- 30
	ImGui.SetNextWindowPos( -- 31
		Vec2(width - 10, 10), -- 31
		"FirstUseEver", -- 31
		Vec2(1, 0) -- 31
	) -- 31
	ImGui.SetNextWindowSize( -- 32
		Vec2(280, 0), -- 32
		"FirstUseEver" -- 32
	) -- 32
	ImGui.SetNextWindowBgAlpha(0.42) -- 33
	ImGui.Begin( -- 34
		"Fox Normal", -- 34
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 34
		function() -- 34
			ImGui.Text("Fox Animation") -- 35
			ImGui.Text("Env: Studio") -- 36
			ImGui.Text("Playing: " .. (fox.playing and "true" or "false")) -- 37
			ImGui.Text("Paused: " .. (fox.paused and "true" or "false")) -- 38
			ImGui.Text((("Time: " .. __TS__NumberToFixed(fox.elapsed, 2)) .. " / ") .. __TS__NumberToFixed(fox.duration, 2)) -- 39
			local changed = false -- 40
			ImGui.PushItemWidth( -- 41
				-80, -- 41
				function() -- 41
					changed, speed = ImGui.DragFloat( -- 42
						"Speed", -- 42
						speed, -- 42
						0.05, -- 42
						0, -- 42
						3, -- 42
						"%.2f" -- 42
					) -- 42
				end -- 41
			) -- 41
			if changed then -- 41
				fox.speed = speed -- 45
			end -- 45
			if ImGui.Button( -- 45
				fox.paused and "Resume" or "Pause", -- 47
				Vec2(90, 28) -- 47
			) then -- 47
				if fox.paused then -- 47
					fox:resume() -- 49
				else -- 49
					fox:pause() -- 51
				end -- 51
			end -- 51
			ImGui.SameLine() -- 54
			if ImGui.Button( -- 54
				"Stop", -- 55
				Vec2(80, 28) -- 55
			) then -- 55
				fox:stop() -- 56
			end -- 56
			ImGui.SameLine() -- 58
			if ImGui.Button( -- 58
				"Play", -- 59
				Vec2(80, 28) -- 59
			) then -- 59
				fox:play("Run", true) -- 60
			end -- 60
		end -- 34
	) -- 34
	return false -- 64
end) -- 26
return ____exports -- 26