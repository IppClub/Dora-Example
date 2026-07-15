-- [ts]: AutoManaged3DRegression.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 2
local Body3D = ____Dora.Body3D -- 3
local BodyDef3D = ____Dora.BodyDef3D -- 4
local Content = ____Dora.Content -- 5
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 6
local Director = ____Dora.Director -- 7
local FixtureDef3D = ____Dora.FixtureDef3D -- 8
local Model3D = ____Dora.Model3D -- 9
local Node3D = ____Dora.Node3D -- 10
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 11
local Vec3 = ____Dora.Vec3 -- 12
local sleep = ____Dora.sleep -- 13
local thread = ____Dora.thread -- 14
local resultPath = "/tmp/dora-3d-auto-managed-result.txt" -- 17
local results = {} -- 18
local function emit(message) -- 20
	print(message) -- 21
	results[#results + 1] = message -- 22
end -- 20
local function finish(status, reason) -- 25
	if reason == nil then -- 25
		reason = "" -- 25
	end -- 25
	emit(("AUTO_MANAGED_3D_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 26
	Content:save( -- 27
		resultPath, -- 27
		table.concat(results, "\n") .. "\n" -- 27
	) -- 27
	App.devMode = false -- 28
	App:shutdown() -- 29
end -- 25
local function expect(condition, reason) -- 32
	if not condition then -- 32
		finish("FAIL", reason) -- 34
		error(reason) -- 35
	end -- 35
end -- 32
Content:remove(resultPath) -- 39
local view = Director.entry -- 41
local scene = view.scene -- 42
local automaticNode = Node3D() -- 44
automaticNode.tag = "automatic-node" -- 45
local explicitRoot = Node3D() -- 47
explicitRoot.tag = "explicit-root" -- 48
local explicitChild = Node3D() -- 49
explicitChild.tag = "explicit-child" -- 50
explicitRoot:addChild(explicitChild) -- 51
local automaticModel = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 53
automaticModel.tag = "automatic-model" -- 54
local automaticLight = DirectionalLight3D() -- 56
automaticLight.tag = "automatic-light" -- 57
local world = PhysicsWorld3D() -- 59
local bodyDef = BodyDef3D() -- 60
bodyDef.type = PhysicsWorld3D.Static -- 61
bodyDef:attach(FixtureDef3D:box(Vec3(0.5, 0.5, 0.5))) -- 62
local automaticBody = Body3D( -- 63
	bodyDef, -- 63
	world, -- 63
	Vec3(0, -2, 0) -- 63
) -- 63
automaticBody.tag = "automatic-body" -- 64
local cleanedNode = Node3D() -- 66
cleanedNode:cleanup() -- 67
thread(function() -- 69
	sleep() -- 70
	expect(scene.parent == nil, "scene_root_was_auto_attached") -- 71
	expect(automaticNode.parent == scene, "node3d_not_auto_attached") -- 72
	expect(explicitRoot.parent == scene, "explicit_root_not_auto_attached") -- 73
	expect(explicitChild.parent == explicitRoot, "explicit_child_was_reparented") -- 74
	expect(automaticModel.parent == scene, "model3d_not_auto_attached") -- 75
	expect(automaticLight.parent == scene, "light3d_not_auto_attached") -- 76
	expect(automaticBody.parent == scene, "body3d_not_auto_attached") -- 77
	expect(cleanedNode.parent == nil, "cleaned_node_was_auto_attached") -- 78
	emit("AUTO_MANAGED_3D_RESULT node=PASS explicit=PASS model=PASS light=PASS body=PASS cleanup=PASS") -- 80
	finish("PASS") -- 81
end) -- 69
return ____exports -- 69