local Dora = require("Dora")
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local LoveNode <const> = Dora.LoveNode
local App <const> = Dora.App

local workflow = {}

function workflow.run(statusFile)
	local node = LoveNode("main.lua")
	if not node then
		assert(Content:save(statusFile, "error=failed to create compressed-image LoveNode"))
		package.loaded.host = nil
		return
	end
	Director.entry:addChild(node)
	local frames = 0
	Director.systemScheduler:schedule(function()
		frames = frames + 1
		if node.running and frames < 120 then
			return false
		end
		assert(not node.running, "compressed-image LoveNode did not quit within 120 frames")
		if node.lastError ~= "" then
			assert(Content:save(statusFile, "error=" .. node.lastError))
			node:removeFromParent(true)
			package.loaded.host = nil
			return true
		end
		local layeredStatus = (App.platform == "macOS" or App.platform == "iOS")
			and "layered-metal-reject" or "layered-nonmetal-pass"
		local readbackStatus = "pixels"
		local astcStatus = App.platform == "macOS" and "all14-pass" or "capability"
		local etc2Status = App.platform == "macOS"
			and "ktx+pvr-rgb+rgba-pass+rgba1-emulation-reject" or "capability"
		local pvrtcStatus = (App.platform == "macOS" or App.platform == "Linux")
			and "ktx+pvr-rgb4+rgba4-pass+2bpp-reject" or "capability"
		local eacStatus = (App.platform == "macOS" or App.platform == "iOS"
			or App.platform == "Android" or App.platform == "Linux")
			and "ktx+pvr-all4-pass" or "capability"
		assert(Content:save(statusFile, "formats=DDS-DXT1+DXT3+DXT5+KTX-DXT1+ASTC4x4+PVR-DXT1+KTX-ETC1+PVR-ETC1+KTX-ETC2rgb+ETC2rgba+ETC2rgba1+PVR-ETC2rgb+ETC2rgba+ETC2rgba1+KTX/PVR-PVRTC1-rgb2+rgb4+rgba2+rgba4+KTX-ASTC5x4+5x5+6x5+6x6+8x5+8x6+8x8+10x5+10x6+10x8+10x10+12x10+12x12+KTX/PVR-EACr+EACrs+EACrg+EACrgs width=4 height=4 bytes=24+48+48+24+48+24+24+24+24+48+24+24+48+24+4x192+4x128+4x48+9x64+4x24+4x48 astc-gpu="
			.. astcStatus .. " etc2-gpu=" .. etc2Status .. " pvrtc-gpu=" .. pvrtcStatus
			.. " eac-gpu=" .. eacStatus .. " gpu=pass mipmaps=3 "
			.. layeredStatus .. "=pass auto-mips=pass non2d-mip=pass cube-volume-replace=pass readback="
			.. readbackStatus))
		node:removeFromParent(true)
		package.loaded.host = nil
		print("HOST_LOVE_COMPRESSED_IMAGE_PASS", frames)
		return true
	end)
end

return workflow
