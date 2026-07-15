-- [ts]: Surface3DRegression.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 1
local App = ____Dora.App -- 2
local ClipNode = ____Dora.ClipNode -- 4
local Color = ____Dora.Color -- 5
local Content = ____Dora.Content -- 6
local Director = ____Dora.Director -- 7
local DrawNode = ____Dora.DrawNode -- 8
local Node = ____Dora.Node -- 9
local Size = ____Dora.Size -- 10
local Surface3D = ____Dora.Surface3D -- 11
local Vec2 = ____Dora.Vec2 -- 12
local sleep = ____Dora.sleep -- 13
local thread = ____Dora.thread -- 14
local resultPath = "/tmp/dora-3d-surface-result.txt" -- 17
local results = {} -- 18
local function emit(message) -- 20
	print(message) -- 21
	results[#results + 1] = message -- 22
end -- 20
local function finish(status, reason) -- 25
	if reason == nil then -- 25
		reason = "" -- 25
	end -- 25
	emit(("SURFACE_3D_SUMMARY status=" .. status) .. (reason == "" and "" or " reason=" .. reason)) -- 26
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
local function makeDot(radius, color) -- 39
	local draw = DrawNode() -- 40
	draw:drawDot( -- 41
		Vec2(32, 32), -- 41
		radius, -- 41
		Color(color) -- 41
	) -- 41
	return draw -- 42
end -- 39
Content:remove(resultPath) -- 45
local content = Node() -- 47
content.size = Size(64, 64) -- 48
content:addChild(makeDot(24, 4283222512)) -- 49
local surface = Surface3D( -- 51
	content, -- 51
	Size(2, 2), -- 51
	Size(64, 64) -- 51
) -- 51
if surface == nil then -- 51
	finish("FAIL", "surface_create_failed") -- 53
	error("surface_create_failed") -- 54
end -- 54
Director.entry:addChild(surface) -- 57
thread(function() -- 59
	sleep() -- 61
	expect(not surface.usingTexture, "simple_subtree_did_not_use_direct_mode") -- 62
	local stencil = makeDot(20, 4294967295) -- 66
	local clip = ClipNode(stencil) -- 67
	clip:addChild(makeDot(28, 4294950411)) -- 68
	content:addChild(clip) -- 69
	sleep() -- 70
	expect(surface.usingTexture, "dynamic_clipnode_did_not_use_texture") -- 71
	content:removeChild(clip, true) -- 74
	sleep() -- 75
	expect(not surface.usingTexture, "removed_clipnode_did_not_restore_direct_mode") -- 76
	local isolatedSubtree = Node() -- 80
	isolatedSubtree:addChild(makeDot(12, 4294387077)) -- 81
	content:addChild(isolatedSubtree) -- 82
	sleep() -- 83
	expect(surface.usingTexture, "generic_2d_subtree_did_not_use_texture") -- 84
	content:removeChild(isolatedSubtree, true) -- 86
	sleep() -- 87
	expect(not surface.usingTexture, "removed_generic_subtree_did_not_restore_direct_mode") -- 88
	content:grab(true) -- 91
	sleep() -- 92
	expect(surface.usingTexture, "grabber_did_not_use_texture") -- 93
	surface.billboard = "Screen" -- 95
	expect(surface.billboard == "Screen", "screen_billboard_roundtrip_failed") -- 96
	surface.billboard = "YAxis" -- 97
	expect(surface.billboard == "YAxis", "y_axis_billboard_roundtrip_failed") -- 98
	surface.billboard = "None" -- 99
	expect(surface.billboard == "None", "billboard_disable_roundtrip_failed") -- 100
	emit("SURFACE_3D_RESULT direct=PASS clip=PASS dynamic=PASS fallback=PASS grabber=PASS billboard=PASS") -- 102
	finish("PASS") -- 103
end) -- 59
return ____exports -- 59