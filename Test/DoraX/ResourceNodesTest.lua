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
local reference = ____DoraX.reference -- 3
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
local spriteRef = reference() -- 20
local spriteChildRef = reference() -- 21
local spriteLabelRef = reference() -- 22
local spriteRemovedRef = reference() -- 23
local spriteAddedRef = reference() -- 24
local gridRef = reference() -- 25
local tileRef = reference() -- 26
local modelRef = reference() -- 27
local animModelRef = reference() -- 28
local audioRef = reference() -- 29
local playAudioRef = reference() -- 30
root:render(React.createElement( -- 32
	"node", -- 32
	nil, -- 32
	React.createElement( -- 32
		"sprite", -- 32
		{ -- 32
			key = "sprite", -- 32
			ref = spriteRef, -- 32
			file = "Image/logo.png", -- 32
			width = 80, -- 32
			height = 80 -- 32
		}, -- 32
		React.createElement("node", {key = "sprite-child", ref = spriteChildRef, tag = "child"}), -- 32
		React.createElement("label", { -- 32
			key = "sprite-label", -- 32
			ref = spriteLabelRef, -- 32
			fontName = "sarasa-mono-sc-regular", -- 32
			fontSize = 12, -- 32
			text = "child" -- 32
		}), -- 32
		React.createElement("node", {key = "sprite-removed", ref = spriteRemovedRef, tag = "removed"}) -- 32
	), -- 32
	React.createElement("grid", { -- 32
		key = "grid", -- 32
		ref = gridRef, -- 32
		file = "Image/logo.png", -- 32
		gridX = 2, -- 32
		gridY = 2 -- 32
	}), -- 32
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/demo.tmx"}), -- 32
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidW.model"}), -- 32
	React.createElement("model", { -- 32
		key = "anim-model", -- 32
		ref = animModelRef, -- 32
		file = "Model/xiaoli.model", -- 32
		play = "walk", -- 32
		loop = true -- 32
	}), -- 32
	React.createElement("audio-source", { -- 32
		key = "audio", -- 32
		ref = audioRef, -- 32
		file = "Audio/di.wav", -- 32
		autoRemove = false, -- 32
		volume = 0.2 -- 32
	}), -- 32
	React.createElement("audio-source", { -- 32
		key = "play-audio", -- 32
		ref = playAudioRef, -- 32
		file = "Audio/di.wav", -- 32
		autoRemove = false, -- 32
		playMode = "normal" -- 32
	}) -- 32
)) -- 32
local sprite = spriteRef.current -- 48
local spriteChild = spriteChildRef.current -- 49
local spriteLabel = spriteLabelRef.current -- 50
local spriteRemoved = spriteRemovedRef.current -- 51
local grid = gridRef.current -- 52
local tile = tileRef.current -- 53
local model = modelRef.current -- 54
local animModel = animModelRef.current -- 55
local audio = audioRef.current -- 56
local playAudio = playAudioRef.current -- 57
expect(sprite ~= nil, "sprite resource node was not mounted") -- 58
expect(spriteChild ~= nil, "sprite child was not mounted") -- 59
expect(spriteChild.parent == sprite, "sprite child parent was not set") -- 60
expect(spriteLabel ~= nil, "sprite label child was not mounted") -- 61
expect(spriteLabel.parent == sprite, "sprite label child parent was not set") -- 62
expect(spriteRemoved ~= nil, "sprite removed child was not mounted") -- 63
expect(spriteRemoved.parent == sprite, "sprite removed child parent was not set") -- 64
expect(grid ~= nil, "grid resource node was not mounted") -- 65
expect(tile ~= nil, "tile-node resource node was not mounted") -- 66
expect(model ~= nil, "model resource node was not mounted") -- 67
expect(animModel ~= nil, "animated model node was not mounted") -- 68
expect(audio ~= nil, "audio-source resource node was not mounted") -- 69
expect(playAudio ~= nil, "play audio-source node was not mounted") -- 70
expect(animModel.current == "walk", "initial model play helper did not run") -- 71
root:render(React.createElement( -- 73
	"node", -- 73
	nil, -- 73
	React.createElement( -- 73
		"sprite", -- 73
		{ -- 73
			key = "sprite", -- 73
			ref = spriteRef, -- 73
			file = "Image/icon.png", -- 73
			width = 64, -- 73
			height = 64 -- 73
		}, -- 73
		React.createElement("node", {key = "sprite-child", ref = spriteChildRef, tag = "child"}), -- 73
		React.createElement("label", { -- 73
			key = "sprite-label", -- 73
			ref = spriteLabelRef, -- 73
			fontName = "sarasa-mono-sc-regular", -- 73
			fontSize = 14, -- 73
			text = "child" -- 73
		}), -- 73
		React.createElement("node", {key = "sprite-added", ref = spriteAddedRef, tag = "added"}) -- 73
	), -- 73
	React.createElement("grid", { -- 73
		key = "grid", -- 73
		ref = gridRef, -- 73
		file = "Image/icon.png", -- 73
		gridX = 3, -- 73
		gridY = 3 -- 73
	}), -- 73
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/platform.tmx"}), -- 73
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidM.model"}), -- 73
	React.createElement("model", { -- 73
		key = "anim-model", -- 73
		ref = animModelRef, -- 73
		file = "Model/xiaoli.model", -- 73
		play = "idle", -- 73
		loop = true -- 73
	}), -- 73
	React.createElement("audio-source", { -- 73
		key = "audio", -- 73
		ref = audioRef, -- 73
		file = "Audio/select.wav", -- 73
		autoRemove = false, -- 73
		volume = 0.3 -- 73
	}), -- 73
	React.createElement("audio-source", { -- 73
		key = "play-audio", -- 73
		ref = playAudioRef, -- 73
		file = "Audio/di.wav", -- 73
		autoRemove = false, -- 73
		playMode = "background" -- 73
	}) -- 73
)) -- 73
expect(spriteRef.current ~= sprite, "sprite should recreate when file changes") -- 89
expect(spriteChildRef.current == spriteChild, "sprite child should move to recreated sprite") -- 90
expect(spriteChildRef.current.parent == spriteRef.current, "sprite child parent should update to recreated sprite") -- 91
expect(spriteLabelRef.current ~= spriteLabel, "sprite label child should recreate when its construction props change") -- 92
expect(spriteLabelRef.current.parent == spriteRef.current, "recreated sprite label parent should be recreated sprite") -- 93
expect(spriteRemovedRef.current == nil, "removed sprite child ref should clear during parent recreation") -- 94
expect(spriteAddedRef.current ~= nil, "added sprite child should mount during parent recreation") -- 95
expect(spriteAddedRef.current.parent == spriteRef.current, "added sprite child parent should be recreated sprite") -- 96
expect(gridRef.current ~= grid, "grid should recreate when file or grid size changes") -- 97
expect(tileRef.current ~= tile, "tile-node should recreate when file changes") -- 98
expect(modelRef.current ~= model, "model should recreate when file changes") -- 99
expect(animModelRef.current == animModel, "model play change should patch without recreating") -- 100
expect(animModelRef.current.current == "idle", "model play helper was not called during patch") -- 101
expect(audioRef.current ~= audio, "audio-source should recreate when file changes") -- 102
expect(playAudioRef.current == playAudio, "audio playMode change should patch without recreating") -- 103
root:unmount() -- 105
expect(not host.hasChildren, "resource nodes unmount did not clear host") -- 106
host:removeFromParent(true) -- 107
Content:save(resultFile, "passed") -- 108
Log("Info", "[DoraXResourceNodesTest] passed") -- 109
return ____exports -- 109