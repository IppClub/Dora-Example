-- Capture the same physical pixels before/after rebuilding the native engine.
local D = require("Dora")
D.thread(function()
	local size, hidden, root = D.App.winSize, {}, nil
	local ok, err = xpcall(function()
	D.Director.systemUI:eachChild(function(n)
		if n.visible then hidden[#hidden+1]=n; n.visible=false end
		return false
	end)
	D.App.winSize=D.Size(640,480); D.sleep(0.2)
	root=D.Node(); root.scaleX=D.App.devicePixelRatio; root.scaleY=D.App.devicePixelRatio
	root.position=D.Vec2(-D.App.visualSize.width * D.App.devicePixelRatio / 2,-D.App.visualSize.height * D.App.devicePixelRatio / 2)
	root:addTo(D.Director.systemUI)
	local bg=D.DrawNode(); bg:drawPolygon({D.Vec2(0,0),D.Vec2(640,0),D.Vec2(640,480),D.Vec2(0,480)},D.Color(0xff151922)); bg:addTo(root)
	local y=450
	for _,fontSize in ipairs({10,12,14,18,24}) do
		for _,phase in ipairs({0,0.25,0.5}) do
			local label=D.Label("sarasa-mono-sc-regular",fontSize,true)
			label.text=fontSize .. "  项目名称 刷新中 新建作品  TypeScript Remix  Il1 Hmn 012345"
			label.anchor=D.Vec2(0,0.5); label.position=D.Vec2(20+phase,y)
			label:addTo(root); y=y-26
		end
	end
	D.sleep(0.2)
	D.App:saveScreenshot("/tmp/dora-sdf-preview")
	D.sleep(0.2)
	end, debug.traceback)
	if root then root:removeFromParent(true) end
	D.App.winSize=size
	for _,n in ipairs(hidden) do n.visible=true end
	D.Content:save("/tmp/dora-sdf-preview.result",ok and "passed" or tostring(err))
end)
