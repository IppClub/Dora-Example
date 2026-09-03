-- Native render regression: production NanoVG surface + clipped Sprite move
-- every frame. Verify the screenshots with verify_system_ui_frame_sync.py.
local D = require("Dora")
local toNode = require("DoraX").toNode
local Visual = require("Dev.Mobile.Visual")
local prefix = "/tmp/dora-system-ui-frame-sync"

D.thread(function()
	local hidden = {}
	D.Director.systemUI:eachChild(function(node)
		if node.visible then hidden[#hidden + 1] = node; node.visible = false end
		return false
	end)
	local originalSize = D.App.winSize
	local host, backdrop
	local ok, err = xpcall(function()
		D.Content:save(prefix .. ".result", "running\n")
		D.App.winSize = D.Size(640, 480)
		D.sleep(0.2)
		host = D.Node()
		host.scaleX = D.App.devicePixelRatio
		host.scaleY = D.App.devicePixelRatio
		host:addTo(D.Director.systemUI)
		-- Opaque backdrop makes pixel verification independent of the home UI.
		backdrop = D.DrawNode()
		backdrop:drawPolygon({D.Vec2(-320,-240), D.Vec2(320,-240), D.Vec2(320,240), D.Vec2(-320,240)}, D.Color(0xff000000))
		backdrop:addTo(D.Director.ui)
		local card = D.Node()
		card:addTo(host)
		toNode(Visual.RoundedSurface({width=100, height=100, radius=12, fillColor=0xffff0000})):addTo(card)
		local stencil = toNode(Visual.RoundedStencil({width=100, height=100, radius=12}))
		local clip = D.ClipNode(stencil)
		clip:addTo(card)
		local texture = D.RenderTarget(50, 50)
		texture:renderWithClear(D.Color(0xff00ff00))
		local sprite = D.Sprite(texture.texture)
		sprite.position = D.Vec2(50, 50)
		sprite:addTo(clip)
		D.sleep(0.1)
		local frame = 0
		host:onUpdate(function()
			frame = frame + 1
			card.position = D.Vec2(frame % 2 == 0 and 80 or -180, frame % 3 * 40 - 100)
			-- Capture while moving on *every* frame, never after a settling delay.
			if frame <= 12 then
				D.App:saveScreenshot(prefix .. "-" .. frame)
			elseif frame == 13 then
				card.visible = false
				D.App:saveScreenshot(prefix .. "-hidden")
			end
			return frame >= 13
		end)
		D.sleep(0.8)
	end, debug.traceback)
	if backdrop and backdrop.parent then backdrop:removeFromParent(true) end
	if host and host.parent then host:removeFromParent(true) end
	D.App.winSize = originalSize
	for _, node in ipairs(hidden) do if node.parent then node.visible = true end end
	D.Content:save(prefix .. ".result", ok and "captured: run pixel verifier\n" or "failed: " .. tostring(err))
end)
