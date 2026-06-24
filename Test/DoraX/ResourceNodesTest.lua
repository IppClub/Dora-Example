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
local audioRef = useRef() -- 24
root:render(React.createElement( -- 26
	"node", -- 26
	nil, -- 26
	React.createElement("sprite", { -- 26
		key = "sprite", -- 26
		ref = spriteRef, -- 26
		file = "Image/logo.png", -- 26
		width = 80, -- 26
		height = 80 -- 26
	}), -- 26
	React.createElement("grid", { -- 26
		key = "grid", -- 26
		ref = gridRef, -- 26
		file = "Image/logo.png", -- 26
		gridX = 2, -- 26
		gridY = 2 -- 26
	}), -- 26
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/demo.tmx"}), -- 26
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidW.model"}), -- 26
	React.createElement("audio-source", { -- 26
		key = "audio", -- 26
		ref = audioRef, -- 26
		file = "Audio/di.wav", -- 26
		autoRemove = false, -- 26
		volume = 0.2 -- 26
	}) -- 26
)) -- 26
local sprite = spriteRef.current -- 36
local grid = gridRef.current -- 37
local tile = tileRef.current -- 38
local model = modelRef.current -- 39
local audio = audioRef.current -- 40
expect(sprite ~= nil, "sprite resource node was not mounted") -- 41
expect(grid ~= nil, "grid resource node was not mounted") -- 42
expect(tile ~= nil, "tile-node resource node was not mounted") -- 43
expect(model ~= nil, "model resource node was not mounted") -- 44
expect(audio ~= nil, "audio-source resource node was not mounted") -- 45
root:render(React.createElement( -- 47
	"node", -- 47
	nil, -- 47
	React.createElement("sprite", { -- 47
		key = "sprite", -- 47
		ref = spriteRef, -- 47
		file = "Image/icon.png", -- 47
		width = 64, -- 47
		height = 64 -- 47
	}), -- 47
	React.createElement("grid", { -- 47
		key = "grid", -- 47
		ref = gridRef, -- 47
		file = "Image/icon.png", -- 47
		gridX = 3, -- 47
		gridY = 3 -- 47
	}), -- 47
	React.createElement("tile-node", {key = "tile", ref = tileRef, file = "TMX/platform.tmx"}), -- 47
	React.createElement("model", {key = "model", ref = modelRef, file = "Model/KidM.model"}), -- 47
	React.createElement("audio-source", { -- 47
		key = "audio", -- 47
		ref = audioRef, -- 47
		file = "Audio/select.wav", -- 47
		autoRemove = false, -- 47
		volume = 0.3 -- 47
	}) -- 47
)) -- 47
expect(spriteRef.current ~= sprite, "sprite should recreate when file changes") -- 57
expect(gridRef.current ~= grid, "grid should recreate when file or grid size changes") -- 58
expect(tileRef.current ~= tile, "tile-node should recreate when file changes") -- 59
expect(modelRef.current ~= model, "model should recreate when file changes") -- 60
expect(audioRef.current ~= audio, "audio-source should recreate when file changes") -- 61
root:unmount() -- 63
expect(not host.hasChildren, "resource nodes unmount did not clear host") -- 64
host:removeFromParent(true) -- 65
Content:save(resultFile, "passed") -- 66
Log("Info", "[DoraXResourceNodesTest] passed") -- 67
return ____exports -- 67