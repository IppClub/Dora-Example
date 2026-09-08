-- Capture separate frames: Label's shared effect must not mix smoothing presets.
local D=require("Dora")
D.thread(function()
	local size, hidden, root=D.App.winSize,{},nil
	local ok,err=xpcall(function()
		D.Director.systemUI:eachChild(function(n) if n.visible then hidden[#hidden+1]=n; n.visible=false end; return false end)
		D.App.winSize=D.Size(800,520); D.sleep(0.2)
		root=D.Node(); local ratio=D.App.devicePixelRatio
		root.scaleX=ratio; root.scaleY=ratio; root.position=D.Vec2(-400*ratio,-260*ratio); root:addTo(D.Director.systemUI)
		local bg=D.DrawNode(); bg:drawPolygon({D.Vec2(0,0),D.Vec2(800,0),D.Vec2(800,520),D.Vec2(0,520)},D.Color(0xff151922)); bg:addTo(root)
		for _,old in ipairs({true,false}) do
		local group=D.Node(); group:addTo(root)
		local function label(text,size,x,y)
			local n=D.Label("sarasa-mono-sc-regular",size,true); n.text=text; n.anchor=D.Vec2(0,0.5); n.position=D.Vec2(x,y)
			if old then local s=math.max(0.006,math.min(0.08,0.012/(size/64*ratio))); n.smooth=D.Vec2(0.69-s,0.69+s) end
			n:addTo(group)
		end
		label(old and "Before" or "After",16,24,486)
		local y=438
		for _,sz in ipairs({10,12,18,28,44,64}) do
			local text=sz>=44 and "字体 Aa" or "新建项目 Remix 0123"
			label(text,sz,24.25,y)
			y=y-(sz>=28 and 90 or 56)
		end
		D.sleep(0.2); D.App:saveScreenshot("/tmp/dora-sdf-weight-" .. (old and "before" or "after")); D.sleep(0.2)
		group:removeFromParent(true)
		end
	end,debug.traceback)
	if root then root:removeFromParent(true) end
	D.App.winSize=size; for _,n in ipairs(hidden) do n.visible=true end
	D.Content:save("/tmp/dora-sdf-weight.result",ok and "passed" or tostring(err))
end)
