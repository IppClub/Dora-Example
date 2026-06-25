-- [tsx]: ResourceNodesTest.tsx
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local Content = ____Dora.Content -- 1
local Director = ____Dora.Director -- 1
local Log = ____Dora.Log -- 1
local DNode = ____Dora.Node -- 1
local Path = ____Dora.Path -- 1
local ____DoraX = require("DoraX") -- 3
local React = ____DoraX.React -- 3
local createRoot = ____DoraX.createRoot -- 3
local useRef = ____DoraX.useRef -- 3
local resultFile = Path(Content.writablePath, "DoraXResourceNodesTest.result") -- 5
Content:save(resultFile, "running") -- 6
local function fail(message) -- 8
	error("[DoraXResourceNodesTest] " .. message) -- 9
end -- 8
local function expect(condition, message) -- 12
	if not condition then -- 12
		fail(message) -- 13
	end -- 13
end -- 12
local host = DNode() -- 16
Director.entry:addChild(host) -- 17
local root = createRoot(host) -- 19
local spriteRef = useRef() -- 20
local gridRef = useRef() -- 21
local tileRef = useRef() -- 22
local modelRef = useRef() -- 23
local animModelRef = useRef() -- 24
local audioRef = useRef() -- 25
local playAudioRef = useRef() -- 26
root:render(React.createElement( -- 28
	"node", -- 28
	nil, -- 28
	React.createElement("sprite", { -- 28
		key = "sprite", -- 28
		ref = spriteRef, -- 28
		file = "Image/logo.png", -- 28
		width = 80, -- 28
		height = 80 -- 28
	}), -- 28
	React.createElement("grid", { -- 28
		key = "grid", -- 28
		ref = gridRef, -- 28
		file = "Image/logo.png", -- 28
		gridX = 2, -- 28
		gridY = 2 -- 28
	}), -- 28
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/demo.tmx"}), -- 28
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidW.model"}), -- 28
	React.createElement("model", { -- 28
		key = "anim-model", -- 28
		ref = animModelRef, -- 28
		file = "Model/xiaoli.model", -- 28
		play = "walk", -- 28
		loop = true -- 28
	}), -- 28
	React.createElement("audio-source", { -- 28
		key = "audio", -- 28
		ref = audioRef, -- 28
		file = "Audio/di.wav", -- 28
		autoRemove = false, -- 28
		volume = 0.2 -- 28
	}), -- 28
	React.createElement("audio-source", { -- 28
		key = "play-audio", -- 28
		ref = playAudioRef, -- 28
		file = "Audio/di.wav", -- 28
		autoRemove = false, -- 28
		playMode = "normal" -- 28
	}) -- 28
)) -- 28
local sprite = spriteRef.current -- 40
local grid = gridRef.current -- 41
local tile = tileRef.current -- 42
local model = modelRef.current -- 43
local animModel = animModelRef.current -- 44
local audio = audioRef.current -- 45
local playAudio = playAudioRef.current -- 46
expect(sprite ~= nil, "sprite resource node was not mounted") -- 47
expect(grid ~= nil, "grid resource node was not mounted") -- 48
expect(tile ~= nil, "tile-node resource node was not mounted") -- 49
expect(model ~= nil, "model resource node was not mounted") -- 50
expect(animModel ~= nil, "animated model node was not mounted") -- 51
expect(audio ~= nil, "audio-source resource node was not mounted") -- 52
expect(playAudio ~= nil, "play audio-source node was not mounted") -- 53
expect(animModel.current == "walk", "initial model play helper did not run") -- 54
root:render(React.createElement( -- 56
	"node", -- 56
	nil, -- 56
	React.createElement("sprite", { -- 56
		key = "sprite", -- 56
		ref = spriteRef, -- 56
		file = "Image/icon.png", -- 56
		width = 64, -- 56
		height = 64 -- 56
	}), -- 56
	React.createElement("grid", { -- 56
		key = "grid", -- 56
		ref = gridRef, -- 56
		file = "Image/icon.png", -- 56
		gridX = 3, -- 56
		gridY = 3 -- 56
	}), -- 56
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/platform.tmx"}), -- 56
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidM.model"}), -- 56
	React.createElement("model", { -- 56
		key = "anim-model", -- 56
		ref = animModelRef, -- 56
		file = "Model/xiaoli.model", -- 56
		play = "idle", -- 56
		loop = true -- 56
	}), -- 56
	React.createElement("audio-source", { -- 56
		key = "audio", -- 56
		ref = audioRef, -- 56
		file = "Audio/select.wav", -- 56
		autoRemove = false, -- 56
		volume = 0.3 -- 56
	}), -- 56
	React.createElement("audio-source", { -- 56
		key = "play-audio", -- 56
		ref = playAudioRef, -- 56
		file = "Audio/di.wav", -- 56
		autoRemove = false, -- 56
		playMode = "background" -- 56
	}) -- 56
)) -- 56
expect(spriteRef.current ~= sprite, "sprite should recreate when file changes") -- 68
expect(gridRef.current ~= grid, "grid should recreate when file or grid size changes") -- 69
expect(tileRef.current ~= tile, "tile-node should recreate when file changes") -- 70
expect(modelRef.current ~= model, "model should recreate when file changes") -- 71
expect(animModelRef.current == animModel, "model play change should patch without recreating") -- 72
expect(animModelRef.current.current == "idle", "model play helper was not called during patch") -- 73
expect(audioRef.current ~= audio, "audio-source should recreate when file changes") -- 74
expect(playAudioRef.current == playAudio, "audio playMode change should patch without recreating") -- 75
root:unmount() -- 77
expect(not host.hasChildren, "resource nodes unmount did not clear host") -- 78
host:removeFromParent(true) -- 79
Content:save(resultFile, "passed") -- 80
Log("Info", "[DoraXResourceNodesTest] passed") -- 81
return ____exports -- 81