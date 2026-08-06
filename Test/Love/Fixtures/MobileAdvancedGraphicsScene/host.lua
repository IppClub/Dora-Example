local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local Path <const> = Dora.Path
local App <const> = Dora.App

local workflow = {}

function workflow.run(statusFile)
	local entries = {
		{"ShaderMRT/main.lua", "mrt"},
		{"ShaderGLSL3/main.lua", "glsl3"},
		{"ShaderInterpolation/main.lua", "shader-interpolation"},
		{"ShaderCustomAttribute/main.lua", "shader-custom-attribute"},
		{"MeshDepth/main.lua", "mesh-depth"},
		{"CanvasReadback/main.lua", "canvas-readback"},
		{"CompressedImage/main.lua", "compressed-image"},
		{"SpriteBatch/main.lua", "sprite-batch", "dora-love-spritebatch", "spritebatch.png"},
		{"ParticleSystem/main.lua", "particle-system", "dora-love-particles", "particles.png"},
		{"TextBatch/main.lua", "text-batch", "dora-love-text-batch", "text-batch.png"},
		{"ImageFont/main.lua", "image-font", "love-image-font"},
		{"ArrayImageLayer/main.lua", "array-image-layer", "love-array-image-layer"},
		{"WindowSettings/main.lua", "window-settings"},
	}
	local index = 0
	local current
	local currentLabel
	local currentSaveRoot
	local currentScreenshot
	local frames = 0
	local sceneFrames = 0
	local stoppedFrames = 0
	local seenRunning = false
	local failed = false
	local function cleanupSaveRoot()
		if currentSaveRoot and Content:exist(currentSaveRoot) then
			assert(Content:remove(currentSaveRoot))
		end
	end
	local function startNext()
		index = index + 1
		if index > #entries then return false end
		local entry = entries[index]
		currentLabel = entry[2]
		currentSaveRoot = entry[3] and Path(Content.writablePath, "Love", entry[3]) or nil
		currentScreenshot = entry[4]
		cleanupSaveRoot()
		print("HOST_LOVE_MOBILE_ADVANCED_GRAPHICS_SCENE", index, currentLabel)
		current = LoveNode(entry[1])
		if not current then
			assert(Content:save(statusFile, "failed=" .. currentLabel .. " error=create"))
			failed = true
			return false
		end
		Director.entry:addChild(current)
		sceneFrames = 0
		stoppedFrames = 0
		seenRunning = false
		return true
	end
	if not startNext() then
		package.loaded.host = nil
		return
	end

	Director.systemScheduler:schedule(function()
		frames = frames + 1
		sceneFrames = sceneFrames + 1
		if current.lastError ~= "" then
			assert(Content:save(statusFile,
				"failed=" .. currentLabel .. " error=" .. current.lastError:gsub("[\r\n]+", " ")))
			current:removeFromParent(true)
			cleanupSaveRoot()
			package.loaded.host = nil
			return true
		end
		if current.running then seenRunning = true end
		-- LoveNode boot is scheduled asynchronously. A freshly-created node can
		-- still report running=false before its isolated state has entered boot;
		-- never treat that pre-start state as a completed scene.
		if not seenRunning and sceneFrames < 600 then return false end
		if not seenRunning then
			assert(Content:save(statusFile, "failed=" .. currentLabel .. " error=never-started"))
			current:removeFromParent(true)
			cleanupSaveRoot()
			package.loaded.host = nil
			return true
		end
		if current.running and sceneFrames < 600 then return false end
		if current.running then
			assert(Content:save(statusFile, "failed=" .. currentLabel .. " error=timeout"))
			current:removeFromParent(true)
			cleanupSaveRoot()
			package.loaded.host = nil
			return true
		end
		stoppedFrames = stoppedFrames + 1
		-- LoveNode can stop during its update after this scheduler has already
		-- observed an empty lastError. Wait one full scheduler turn so a late
		-- load/update failure cannot be mistaken for a successful scene.
		if stoppedFrames < 2 then return false end
		if currentScreenshot then
			local screenshot = Path(currentSaveRoot, currentScreenshot)
			if not Content:exist(screenshot) and stoppedFrames < 120 then return false end
			if not Content:exist(screenshot) then
				assert(Content:save(statusFile,
					"failed=" .. currentLabel .. " error=missing-" .. currentScreenshot))
				current:removeFromParent(true)
				cleanupSaveRoot()
				package.loaded.host = nil
				return true
			end
		end
		current:removeFromParent(true)
		cleanupSaveRoot()
		if startNext() then return false end
		if failed then
			package.loaded.host = nil
			return true
		end
		local platform = string.lower(App.platform)
		local renderer = App.platform == "iOS" and "metal"
			or App.platform == "Windows" and "direct3d" or "opengles"
		assert(Content:save(statusFile,
			("platform=%s renderer=%s shaders=glsl3-interpolation-layout-matrix mrt=2 depth=pass mesh=pass msaa=4 formats=pass compressed=dxt1-layered-capability batch=sprite-array-particle text=retained-imagefont array=maintex-layers window=virtual-queries pixels=pass scenes=13 content=pass")
				:format(platform, renderer)))
		package.loaded.host = nil
		print("HOST_LOVE_MOBILE_ADVANCED_GRAPHICS_PASS", frames)
		return true
	end)
end

return workflow
