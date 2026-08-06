local Dora = require("Dora")
local ImGui = require("ImGui")
local nvg = require("nvg")
local Camera3D <const> = Dora.Camera3D
local Color <const> = Dora.Color
local Content <const> = Dora.Content
local Director <const> = Dora.Director
local DirectionalLight3D <const> = Dora.DirectionalLight3D
local DrawNode <const> = Dora.DrawNode
local LoveNode <const> = Dora.LoveNode
local Model3D <const> = Dora.Model3D
local Node <const> = Dora.Node
local Node3D <const> = Dora.Node3D
local Path <const> = Dora.Path
local TIC80Node <const> = Dora.TIC80Node
local Vec2 <const> = Dora.Vec2
local Vec3 <const> = Dora.Vec3
local VGNode <const> = Dora.VGNode
local View3D <const> = Dora.View3D

local workflow = {}

function workflow.run(statusFile)
	local root = Node()
	local draw = DrawNode()
	draw:drawDot(Vec2(8, 12), 4, Color(0xff40a0ff))
	draw:drawSegment(Vec2(0, 0), Vec2(16, 8), 2, Color(0xffff8040))
	root:addChild(draw)

	local view3D = View3D()
	local sceneNode = Node3D()
	sceneNode.position = Vec3(1, 2, 3)
	local model = assert(Model3D("triangle.gltf"), "failed to load regression glTF")
	model.position = Vec3(-1, -2, -3)
	local light = DirectionalLight3D()
	light.intensity = 2
	sceneNode:addChild(model)
	sceneNode:addChild(light)
	view3D:addChild(sceneNode)
	root:addChild(view3D)
	local camera = Camera3D()
	camera:lookAt(Vec3(0, 0, 4), Vec3(0, 0, 0))
	Director:pushCamera(camera)

	local vg = VGNode(64, 64, 1, 1)
	local nvgRendered = false
	vg:render(function()
		nvg.BeginPath()
		nvg.Rect(4, 4, 56, 56)
		nvg.FillColor(Color(0xff20c080))
		nvg.Fill()
		nvgRendered = true
	end)
	assert(nvgRendered, "NanoVG render callback did not complete")
	assert(vg.surface ~= nil and vg.surface.texture ~= nil,
		"NanoVG surface texture was not created")
	root:addChild(vg)

	local cart = Path(Content.assetPath, "www", "tic80", "cart.tic")
	local tic = assert(TIC80Node(cart), "failed to create TIC80Node from packaged cart")
	assert(tic.texture ~= nil and tic.width == 240 and tic.height == 136)
	assert(tic.keyboardEnabled and tic.controllerEnabled and tic.touchEnabled)
	root:addChild(tic)
	local loveNode = assert(LoveNode("love.lua"), "failed to create coexistence LoveNode")
	root:addChild(loveNode)

	Director.entry:addChild(root)
	assert(draw.parent == root)
	assert(sceneNode.parent == view3D.scene and light.parent == sceneNode)
	local position = sceneNode.position
	assert(position.x == 1 and position.y == 2 and position.z == 3)
	local frames = 0
	root:schedule(function()
		frames = frames + 1
		ImGui.Begin("Love Dora Regression", {"NoSavedSettings", "NoInputs"}, function()
			ImGui.Text("ImGui and Love render passes coexist")
		end)
		if frames < 8 or loveNode.running then
			return false
		end
		assert(loveNode.lastError == "", loveNode.lastError)
		assert(tic.texture ~= nil and tic.keyboardEnabled
			and tic.controllerEnabled and tic.touchEnabled)
		assert(vg.surface.texture ~= nil, "NanoVG surface texture was released early")
		local stats = view3D.stats
		print("DORA_3D_REGRESSION_STATS", stats.modelCount, stats.visibleVisuals,
			stats.culledVisuals, stats.drawCalls, stats.triangles)
		assert(stats.modelCount >= 1 and stats.visibleVisuals >= 1
			and stats.drawCalls >= 1 and stats.triangles >= 1,
			"3D model did not reach the renderer")
		local drawCalls, triangles = stats.drawCalls, stats.triangles
		assert(Content:save(statusFile, "2d=1 3d=1 tic80=1 nvg=1 imgui=1 love=1"))
		Director:popCamera()
		root:removeFromParent(true)
		package.loaded.host = nil
		print("DORA_EXISTING_FEATURE_REGRESSION_PASS", 1, 1, 1, 1, 1, 1,
			drawCalls, triangles, frames)
		return true
	end)
end

return workflow
