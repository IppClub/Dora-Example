local requested = false

function love.draw()
	love.graphics.clear(0, 0, 1, 1)
	if not requested then
		requested = true
		love.graphics.captureScreenshot(function()
			error("stale screenshot callback ran after instance stop")
		end)
		love.event.quit()
		print("LOVE_SCREENSHOT_CANCEL_QUEUED")
	end
end
