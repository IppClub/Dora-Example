local Dora = require("Dora")
local Color <const> = Dora.Color
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local Path <const> = Dora.Path
local RenderTarget <const> = Dora.RenderTarget
local Vec2 <const> = Dora.Vec2
local VideoNode <const> = Dora.VideoNode
local thread <const> = Dora.thread

local workflow = {}

function workflow.run(statusFile, outputRoot)
	if Content:exist(outputRoot) then
		assert(Content:isdir(outputRoot), "VideoNode output root must be a directory")
	else
		assert(Content:mkdir(outputRoot))
	end

	local video = assert(VideoNode("sample.ogv", true),
		"failed to create Ogg/Theora VideoNode through Content")
	local target = RenderTarget(256, 256)
	video.position = Vec2(128, 128)
	video.scaleX = 0.5
	video.scaleY = 0.5
	video:pause()
	Director.entry:addChild(video)

	local phase = "initial-pause"
	local elapsed = 0
	local captureDone = false
	local captureError
	local pausedA
	local pausedB
	local loopScreenshots = {}
	local function capture(path)
		captureDone = false
		captureError = nil
		target:renderWithClear(video, Color(0xff000000))
		thread(function()
			if not target:saveAsync(path) then
				captureError = "failed to save VideoNode RenderTarget through Content"
			end
			captureDone = true
		end)
	end
	Director.systemScheduler:schedule(function(deltaTime)
		elapsed = elapsed + deltaTime
		if phase == "initial-pause" then
			if elapsed < 0.2 then return false end
			assert(video.paused, "VideoNode did not retain initial pause state")
			assert(video.texture == nil, "paused VideoNode uploaded a frame before resume")
			video:resume()
			assert(not video.paused, "VideoNode did not resume")
			phase = "wait-first-frame"
			elapsed = 0
			return false
		end

		if phase == "wait-first-frame" then
			if video.texture == nil and elapsed < 15 then return false end
			assert(video.texture ~= nil, "VideoNode did not upload a decoded frame")
			assert(video.texture.width == 496 and video.texture.height == 502,
				"VideoNode texture dimensions do not match the Theora stream")
			video:pause()
			pausedA = Path(outputRoot, "paused-a.png")
			capture(pausedA)
			phase = "paused-a-capture"
			return false
		end

		if phase == "paused-a-capture" then
			if not captureDone then return false end
			assert(captureError == nil, captureError)
			phase = "paused-gap"
			elapsed = 0
			return false
		end

		if phase == "paused-gap" then
			if elapsed < 0.2 then return false end
			pausedB = Path(outputRoot, "paused-b.png")
			capture(pausedB)
			phase = "paused-b-capture"
			return false
		end

		if phase == "paused-b-capture" then
			if not captureDone then return false end
			assert(captureError == nil, captureError)
			video:resume()
			phase = "cross-loop"
			elapsed = 0
			return false
		end

		if phase == "cross-loop" then
			if elapsed < 1.05 then return false end
			loopScreenshots[1] = Path(outputRoot, "loop-1.png")
			capture(loopScreenshots[1])
			phase = "loop-capture"
			return false
		end

		if phase == "loop-gap" then
			if elapsed < 0.2 then return false end
			local index = #loopScreenshots + 1
			loopScreenshots[index] = Path(outputRoot, ("loop-%d.png"):format(index))
			capture(loopScreenshots[index])
			phase = "loop-capture"
			return false
		end

		if phase == "loop-capture" then
			if not captureDone then return false end
			assert(captureError == nil, captureError)
			if #loopScreenshots < 4 then
				phase = "loop-gap"
				elapsed = 0
				return false
			end
			phase = "verify"
		end

		local pausedPixelsA = assert(Content:load(pausedA), "failed to read first paused screenshot through Content")
		local pausedPixelsB = assert(Content:load(pausedB), "failed to read second paused screenshot through Content")
		local loopPixels = {}
		for index, path in ipairs(loopScreenshots) do
			loopPixels[index] = assert(Content:load(path), "failed to read loop screenshot through Content")
		end
		assert(#pausedPixelsA > 0 and #pausedPixelsB > 0 and #loopPixels[1] > 0,
			"VideoNode screenshots were empty")
		assert(pausedPixelsA == pausedPixelsB, "paused VideoNode changed rendered pixels")
		-- The fixed upstream sample contains long runs of identical frames. Compare
		-- the post-EOF samples with the paused initial frame as well as each other,
		-- so this proves loop progress without assuming every 0.2 s window changes.
		local loopChanged = loopPixels[1] ~= pausedPixelsA
		for index = 2, #loopPixels do
			if loopPixels[index] ~= loopPixels[1] then
				loopChanged = true
				break
			end
		end
		assert(loopChanged, "looping VideoNode froze after crossing the first stream duration")
		video:removeFromParent(true)
		assert(Content:save(statusFile,
			"content=pass dimensions=496x502 pause=pixel-stable loop=pixel-changing cleanup=pass"))
		package.loaded.host = nil
		print("DORA_VIDEO_NODE_WORKFLOW_PASS", #loopScreenshots)
		return true
	end)
end

return workflow
