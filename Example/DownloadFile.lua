-- [ts]: DownloadFile.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local HttpClient = ____Dora.HttpClient -- 2
local Path = ____Dora.Path -- 2
local thread = ____Dora.thread -- 2
local HttpServer = ____Dora.HttpServer -- 2
local Content = ____Dora.Content -- 2
local loop = ____Dora.loop -- 2
local App = ____Dora.App -- 2
local Vec2 = ____Dora.Vec2 -- 2
local Buffer = ____Dora.Buffer -- 2
local Node = ____Dora.Node -- 2
local ImGui = require("ImGui") -- 3
local url = ("http://" .. HttpServer.localIP) .. ":8866/Doc/zh-Hans/welcome.md" -- 6
local targetFile = Path(Content.writablePath, ".download", "testDownloadFile") -- 7
local cancelDownload = false -- 8
local progress = 0 -- 9
local function download() -- 11
	thread(function() -- 12
		progress = 0 -- 13
		Content:mkdir(Path(Content.writablePath, ".download")) -- 14
		local success = HttpClient:downloadAsync( -- 15
			url, -- 16
			targetFile, -- 17
			10, -- 18
			function(current, total) -- 19
				if cancelDownload then -- 19
					return true -- 21
				end -- 21
				if total > 1024 * 1024 then -- 21
					print("file larger than 1MB, canceled") -- 24
					return true -- 25
				end -- 25
				progress = current / total -- 27
				return false -- 28
			end -- 19
		) -- 19
		if success then -- 19
			print("Downloaded: " .. url) -- 32
		else -- 32
			print("Download failed: " .. url) -- 34
		end -- 34
		if Content:remove(targetFile) then -- 34
			print(targetFile .. " is deleted") -- 37
		end -- 37
	end) -- 12
end -- 11
download() -- 42
local downloadFlags = { -- 44
	"NoResize", -- 45
	"NoSavedSettings", -- 46
	"NoTitleBar", -- 47
	"NoMove", -- 48
	"AlwaysAutoResize" -- 49
} -- 49
local buffer = Buffer(256) -- 51
local node = Node() -- 52
node:onCleanup(function() -- 53
	cancelDownload = true -- 54
	if Content:remove(targetFile) then -- 54
		print(targetFile .. " is deleted") -- 56
	end -- 56
end) -- 53
node:schedule(loop(function() -- 59
	local ____App_visualSize_0 = App.visualSize -- 60
	local width = ____App_visualSize_0.width -- 60
	local height = ____App_visualSize_0.height -- 60
	ImGui.SetNextWindowPos(Vec2(width / 2 - 180, height / 2 - 100)) -- 61
	ImGui.SetNextWindowSize( -- 62
		Vec2(300, 100), -- 62
		"FirstUseEver" -- 62
	) -- 62
	ImGui.Begin( -- 63
		"Download", -- 63
		downloadFlags, -- 63
		function() -- 63
			ImGui.SameLine() -- 64
			ImGui.TextWrapped(url) -- 65
			ImGui.ProgressBar( -- 66
				progress, -- 66
				Vec2(-1, 30) -- 66
			) -- 66
			ImGui.Separator() -- 67
			ImGui.Text("URL to download") -- 68
			ImGui.InputText("URL", buffer) -- 69
			if ImGui.Button("Download") then -- 69
				url = buffer.text -- 71
				download() -- 72
			end -- 72
		end -- 63
	) -- 63
	return false -- 75
end)) -- 59
return ____exports -- 59