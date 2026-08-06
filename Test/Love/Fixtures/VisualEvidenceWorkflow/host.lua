local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path

local workflow = {}

function workflow.run(statusFile, fixturesRoot, outputRoot)
	local entries = {
		{"CanvasScene", "love-canvas-visual-evidence", "canvas-postprocess.png", "love2d-p5-canvas-postprocess-macos.png"},
		{"StencilScene", "love-stencil-visual-evidence", "stencil.png", "love2d-p5-stencil-macos.png"},
		{"MeshDepthScene", "love-mesh-depth-visual-evidence", "mesh-depth-shader.png", "love2d-p5-mesh-depth-shader-macos.png"},
	}
	local index = 0
	local node
	local sceneRoot
	local saveRoot
	local frames = 0
	local seenRunning = false
	local cleanupFrames = 0
	local pendingNext = false

	if Content:exist(outputRoot) then
		assert(Content:isdir(outputRoot), "visual evidence output must be a directory")
	else
		assert(Content:mkdir(outputRoot))
	end

	local function cleanupScene()
		if node then
			node:removeFromParent(true)
			node = nil
		end
		if sceneRoot then
			Content:removeSearchPath(sceneRoot)
			sceneRoot = nil
		end
		if saveRoot and Content:exist(saveRoot) then
			assert(Content:remove(saveRoot))
		end
		saveRoot = nil
	end

	local function startNext()
		index = index + 1
		if index > #entries then return false end
		local entry = entries[index]
		sceneRoot = Path(fixturesRoot, entry[1])
		saveRoot = Path(Content.writablePath, "Love", entry[2])
		if Content:exist(saveRoot) then assert(Content:remove(saveRoot)) end
		Content:insertSearchPath(1, sceneRoot)
		node = assert(LoveNode("main.lua"), "failed to create " .. entry[1])
		Director.entry:addChild(node)
		frames = 0
		seenRunning = false
		cleanupFrames = 0
		pendingNext = false
		print("HOST_LOVE_VISUAL_EVIDENCE_SCENE", index, entry[1])
		return true
	end

	assert(startNext())
	Director.systemScheduler:schedule(function()
		if pendingNext then
			cleanupFrames = cleanupFrames + 1
			if cleanupFrames < 120 then return false end
			pendingNext = false
			if startNext() then return false end
			assert(Content:save(statusFile, "visual=canvas,stencil,mesh screenshots=3 renderer=metal content=pass cleanup=pass"))
			package.loaded.host = nil
			print("HOST_LOVE_VISUAL_EVIDENCE_PASS", #entries)
			return true
		end
		frames = frames + 1
		if node.lastError ~= "" then
			local message = node.lastError:gsub("[\r\n]+", " ")
			cleanupScene()
			assert(Content:save(statusFile, "failed=" .. entries[index][1] .. " error=" .. message))
			package.loaded.host = nil
			return true
		end
		if node.running then seenRunning = true end
		if not seenRunning and frames < 300 then return false end
		if not seenRunning then
			cleanupScene()
			assert(Content:save(statusFile, "failed=" .. entries[index][1] .. " error=never-started"))
			package.loaded.host = nil
			return true
		end
		if node.running and frames < 600 then return false end
		if node.running then
			cleanupScene()
			assert(Content:save(statusFile, "failed=" .. entries[index][1] .. " error=timeout"))
			package.loaded.host = nil
			return true
		end

		local entry = entries[index]
		local source = Path(saveRoot, entry[3])
		local target = Path(outputRoot, entry[4])
		if not Content:exist(source) then
			cleanupScene()
			assert(Content:save(statusFile, "failed=" .. entry[1] .. " error=missing-screenshot"))
			package.loaded.host = nil
			return true
		end
		if Content:exist(target) then assert(Content:remove(target)) end
		assert(Content:copy(source, target), "failed to publish " .. entry[4])
		assert(Content:exist(target), "published screenshot is missing")
		cleanupScene()
		pendingNext = true
		cleanupFrames = 0
		return false
	end)
end

return workflow
