-- [ts]: Surface3DNodeMatrixUserTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local AlignNode = ____Dora.AlignNode -- 3
local App = ____Dora.App -- 4
local AudioSource = ____Dora.AudioSource -- 6
local Body = ____Dora.Body -- 7
local BodyDef = ____Dora.BodyDef -- 8
local Camera3D = ____Dora.Camera3D -- 10
local ClipNode = ____Dora.ClipNode -- 11
local Color = ____Dora.Color -- 12
local Color3 = ____Dora.Color3 -- 13
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 14
local Director = ____Dora.Director -- 15
local DragonBone = ____Dora.DragonBone -- 16
local DrawNode = ____Dora.DrawNode -- 17
local EffekNode = ____Dora.EffekNode -- 18
local Grid = ____Dora.Grid -- 19
local Label = ____Dora.Label -- 20
local Line = ____Dora.Line -- 21
local Menu = ____Dora.Menu -- 22
local Model = ____Dora.Model -- 23
local Model3D = ____Dora.Model3D -- 24
local Node = ____Dora.Node -- 25
local Particle = ____Dora.Particle -- 26
local PhysicsWorld3D = ____Dora.PhysicsWorld3D -- 27
local PhysicsWorld = ____Dora.PhysicsWorld -- 28
local Playable = ____Dora.Playable -- 29
local Size = ____Dora.Size -- 30
local Spine = ____Dora.Spine -- 31
local Sprite = ____Dora.Sprite -- 32
local Surface3D = ____Dora.Surface3D -- 33
local TIC80Node = ____Dora.TIC80Node -- 34
local TileNode = ____Dora.TileNode -- 35
local Vec2 = ____Dora.Vec2 -- 36
local Vec3 = ____Dora.Vec3 -- 37
local VGNode = ____Dora.VGNode -- 38
local VideoNode = ____Dora.VideoNode -- 39
local View3D = ____Dora.View3D -- 40
local threadLoop = ____Dora.threadLoop -- 41
local ImGui = require("ImGui") -- 44
local nvg = require("nvg") -- 45
local logicalSize = Size(320, 200) -- 47
local view = Director.entry -- 48
local camera = Camera3D() -- 49
camera:lookAt( -- 50
	Vec3(0, 2.7, 8.8), -- 50
	Vec3(0, 1.25, 0) -- 50
) -- 50
Director:pushCamera(camera) -- 51
view:setEnvironmentMap("") -- 52
view:setEnvironmentIntensity(0.22, 0.05, 1) -- 53
local light = DirectionalLight3D() -- 55
light.color = Color3(16773852) -- 56
light.intensity = 4 -- 57
light.angleX = -38 -- 58
light.angleY = 30 -- 59
view:addChild(light) -- 60
local ground = Model3D("Test/Model3D/Assets/Model/Ground.gltf") -- 62
ground.position = Vec3(0, -0.72, 0) -- 63
view:addChild(ground) -- 64
local rearDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 66
rearDuck.position = Vec3(0.55, 0, -0.9) -- 67
rearDuck.scale = Vec3(0.88, 0.88, 0.88) -- 68
rearDuck:getMaterial(0).baseColor = Color(4284012173) -- 69
view:addChild(rearDuck) -- 70
local frontDuck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 72
frontDuck.position = Vec3(-0.55, 0, 1) -- 73
frontDuck.scale = Vec3(0.88, 0.88, 0.88) -- 74
frontDuck:getMaterial(0).baseColor = Color(4294934352) -- 75
view:addChild(frontDuck) -- 76
local function panel(color) -- 78
	if color == nil then -- 78
		color = Color(4280577021) -- 78
	end -- 78
	local node = DrawNode() -- 79
	node:drawPolygon( -- 80
		{ -- 80
			Vec2(0, 0), -- 81
			Vec2(logicalSize.width, 0), -- 82
			Vec2(logicalSize.width, logicalSize.height), -- 83
			Vec2(0, logicalSize.height) -- 84
		}, -- 84
		color, -- 85
		4, -- 85
		Color(4290633982) -- 85
	) -- 85
	return node -- 86
end -- 78
local function dot(pos, radius, color) -- 89
	local node = DrawNode() -- 90
	node:drawDot(pos, radius, color) -- 91
	return node -- 92
end -- 89
local function textLabel(text, size) -- 95
	if size == nil then -- 95
		size = 28 -- 95
	end -- 95
	local label = Label("sarasa-mono-sc-regular", size) -- 96
	label.text = text -- 97
	label.color = Color(4294967295) -- 98
	return label -- 99
end -- 95
local function unavailable(name) -- 102
	local root = Node() -- 103
	root:addChild(dot( -- 104
		Vec2(160, 100), -- 104
		55, -- 104
		Color(4285298045) -- 104
	)) -- 104
	local label = textLabel(name .. "\nresource unavailable", 20) -- 105
	label.position = Vec2(160, 100) -- 106
	root:addChild(label) -- 107
	return root -- 108
end -- 102
local function centered(node, position) -- 111
	if position == nil then -- 111
		position = Vec2(160, 100) -- 111
	end -- 111
	node.position = position -- 112
	return node -- 113
end -- 111
local scenarios = { -- 124
	{ -- 125
		name = "Single / DrawNode", -- 126
		coverage = "DrawNode shape renderer; direct backend", -- 127
		expectedTexture = false, -- 128
		build = function() return dot( -- 129
			Vec2(160, 100), -- 129
			64, -- 129
			Color(4294950411) -- 129
		) end -- 129
	}, -- 129
	{ -- 131
		name = "Single / Sprite", -- 132
		coverage = "Sprite texture renderer; direct backend", -- 133
		expectedTexture = false, -- 134
		build = function() -- 135
			local sprite = Sprite("Image/icon.png") -- 136
			if not sprite then -- 136
				return nil -- 137
			end -- 137
			sprite.position = Vec2(160, 100) -- 138
			sprite.scaleX = 0.65 -- 139
			sprite.scaleY = 0.65 -- 140
			return sprite -- 141
		end -- 135
	}, -- 135
	{ -- 144
		name = "Single / Label", -- 145
		coverage = "Label glyph batching and font texture", -- 146
		expectedTexture = true, -- 147
		manualCheck = "The text must read LEFT to RIGHT without horizontal mirroring.", -- 148
		build = function() return centered(textLabel("LEFT  Surface3D  RIGHT\nLabel", 24)) end -- 149
	}, -- 149
	{ -- 151
		name = "Single / Line", -- 152
		coverage = "Line vertex renderer", -- 153
		expectedTexture = true, -- 154
		build = function() return Line( -- 155
			{ -- 155
				Vec2(50, 35), -- 156
				Vec2(270, 35), -- 156
				Vec2(70, 165), -- 156
				Vec2(160, 55), -- 157
				Vec2(250, 165), -- 157
				Vec2(50, 35) -- 157
			}, -- 157
			Color(4294950411) -- 158
		) end -- 158
	}, -- 158
	{ -- 160
		name = "Single / Grid", -- 161
		coverage = "Grid textured mesh with deformed vertices", -- 162
		expectedTexture = true, -- 163
		build = function() -- 164
			local grid = Grid("Image/icon.png", 4, 3) -- 165
			grid.position = Vec2(85, 25) -- 166
			grid.scaleX = 0.58 -- 167
			grid.scaleY = 0.58 -- 168
			local pos = grid:getPos(2, 1) -- 169
			grid:setPos( -- 170
				2, -- 170
				1, -- 170
				pos:add(Vec2(24, 18)), -- 170
				0.15 -- 170
			) -- 170
			grid:setColor( -- 171
				2, -- 171
				1, -- 171
				Color(4294950411) -- 171
			) -- 171
			return grid -- 172
		end -- 164
	}, -- 164
	{ -- 175
		name = "Single / ClipNode", -- 176
		coverage = "ClipNode stencil writes isolated in RenderTarget", -- 177
		expectedTexture = true, -- 178
		build = function() -- 179
			local stencil = dot( -- 180
				Vec2(160, 100), -- 180
				70, -- 180
				Color(4294967295) -- 180
			) -- 180
			local clip = ClipNode(stencil) -- 181
			clip:addChild(panel(Color(4293278022))) -- 182
			return clip -- 183
		end -- 179
	}, -- 179
	{ -- 186
		name = "Container / Node", -- 187
		coverage = "Generic Node container with transformed children", -- 188
		expectedTexture = true, -- 189
		build = function() -- 190
			local root = Node() -- 191
			local child = dot( -- 192
				Vec2.zero, -- 192
				44, -- 192
				Color(4289222135) -- 192
			) -- 192
			child.position = Vec2(160, 100) -- 193
			child.angle = 18 -- 194
			root:addChild(child) -- 195
			return root -- 196
		end -- 190
	}, -- 190
	{ -- 199
		name = "Container / AlignNode", -- 200
		coverage = "AlignNode layout container and layout callback", -- 201
		expectedTexture = true, -- 202
		build = function() -- 203
			local align = AlignNode(false) -- 204
			align.size = logicalSize -- 205
			align:css("width: 320; height: 200; justify-content: center; align-items: center") -- 206
			local marker = dot( -- 207
				Vec2.zero, -- 207
				48, -- 207
				Color(4280468830) -- 207
			) -- 207
			align:addChild(marker) -- 208
			return align -- 209
		end -- 203
	}, -- 203
	{ -- 212
		name = "Container / Menu", -- 213
		coverage = "Menu interaction container inside a Surface3D subtree", -- 214
		expectedTexture = true, -- 215
		build = function() -- 216
			local menu = Menu(320, 200) -- 217
			menu.position = Vec2(160, 100) -- 218
			menu:addChild(dot( -- 219
				Vec2.zero, -- 219
				52, -- 219
				Color(4294538006) -- 219
			)) -- 219
			return menu -- 220
		end -- 216
	}, -- 216
	{ -- 223
		name = "Resource / Particle", -- 224
		coverage = "Particle renderer, scheduler and dynamic vertex count", -- 225
		expectedTexture = true, -- 226
		build = function() -- 227
			local particle = Particle("Particle/fire.par") -- 228
			if not particle then -- 228
				return nil -- 229
			end -- 229
			particle.position = Vec2(160, 55) -- 230
			particle:start() -- 231
			return particle -- 232
		end -- 227
	}, -- 227
	{ -- 235
		name = "Resource / Model", -- 236
		coverage = "Dora 2D Model playable and animation slots", -- 237
		expectedTexture = true, -- 238
		build = function() -- 239
			local model = Model("Model/xiaoli.model") -- 240
			if not model then -- 240
				return nil -- 241
			end -- 241
			model.position = Vec2(160, 45) -- 242
			model.scaleX = 0.48 -- 243
			model.scaleY = 0.48 -- 244
			local animations = Model:getAnimations("Model/xiaoli.model") -- 245
			if #animations > 0 then -- 245
				model:play(animations[1], true) -- 246
			end -- 246
			return model -- 247
		end -- 239
	}, -- 239
	{ -- 250
		name = "Resource / Playable", -- 251
		coverage = "Playable factory dispatch to Dora Model", -- 252
		expectedTexture = true, -- 253
		build = function() -- 254
			local playable = Playable("model:Model/xiaoli.model") -- 255
			if not playable then -- 255
				return nil -- 256
			end -- 256
			playable.position = Vec2(160, 45) -- 257
			playable.scaleX = 0.48 -- 258
			playable.scaleY = 0.48 -- 259
			return playable -- 260
		end -- 254
	}, -- 254
	{ -- 263
		name = "Resource / Spine", -- 264
		coverage = "Spine mesh animation", -- 265
		expectedTexture = true, -- 266
		build = function() -- 267
			local spine = Spine("Spine/moling") -- 268
			if not spine then -- 268
				return nil -- 269
			end -- 269
			spine.position = Vec2(160, 20) -- 270
			spine.scaleX = 0.45 -- 271
			spine.scaleY = 0.45 -- 272
			local animations = Spine:getAnimations("Spine/moling") -- 273
			if #animations > 0 then -- 273
				spine:play(animations[1], true) -- 274
			end -- 274
			return spine -- 275
		end -- 267
	}, -- 267
	{ -- 278
		name = "Resource / DragonBone", -- 279
		coverage = "DragonBone mesh animation", -- 280
		expectedTexture = true, -- 281
		build = function() -- 282
			local bone = DragonBone("DragonBones/NewDragon") -- 283
			if not bone then -- 283
				return nil -- 284
			end -- 284
			bone.position = Vec2(160, 15) -- 285
			bone.scaleX = 0.32 -- 286
			bone.scaleY = 0.32 -- 287
			local animations = DragonBone:getAnimations("DragonBones/NewDragon") -- 288
			if #animations > 0 then -- 288
				bone:play(animations[1], true) -- 289
			end -- 289
			return bone -- 290
		end -- 282
	}, -- 282
	{ -- 293
		name = "Resource / TileNode", -- 294
		coverage = "TMX TileNode renderer and multi-texture batching", -- 295
		expectedTexture = true, -- 296
		build = function() -- 297
			local tile = TileNode("TMX/platform.tmx") -- 298
			if not tile then -- 298
				return nil -- 299
			end -- 299
			tile.position = Vec2(30, 15) -- 300
			tile.scaleX = 0.22 -- 301
			tile.scaleY = 0.22 -- 302
			return tile -- 303
		end -- 297
	}, -- 297
	{ -- 306
		name = "Resource / EffekNode", -- 307
		coverage = "Effekseer standalone render pass", -- 308
		expectedTexture = true, -- 309
		manualCheck = "The lightning effect animates near the panel center; use Rebuild to replay it.", -- 310
		build = function() -- 311
			local effect = EffekNode() -- 312
			effect.position = Vec2(160, 100) -- 313
			effect.scaleX = 10 -- 314
			effect.scaleY = 10 -- 315
			effect:play("Particle/effek/sword_lightning.efkefc") -- 316
			return effect -- 317
		end -- 311
	}, -- 311
	{ -- 320
		name = "Resource / VGNode", -- 321
		coverage = "NanoVG framebuffer surface", -- 322
		expectedTexture = true, -- 323
		build = function() -- 324
			local vg = VGNode(320, 200, 1) -- 325
			vg:render(function() -- 326
				nvg.BeginPath() -- 327
				nvg.RoundedRect( -- 328
					35, -- 328
					35, -- 328
					250, -- 328
					130, -- 328
					24 -- 328
				) -- 328
				nvg.FillColor(Color(4279548070)) -- 329
				nvg.Fill() -- 330
				nvg.ClosePath() -- 331
			end) -- 326
			return vg -- 333
		end -- 324
	}, -- 324
	{ -- 336
		name = "Resource / VideoNode", -- 337
		coverage = "VideoNode dynamic Sprite texture (optional test asset)", -- 338
		expectedTexture = true, -- 339
		build = function() -- 340
			local video = VideoNode("../random/test_640x360.h264", true) -- 341
			if not video then -- 341
				return unavailable("VideoNode") -- 342
			end -- 342
			video.position = Vec2(160, 100) -- 343
			video.scaleX = 0.5 -- 344
			video.scaleY = 0.5 -- 345
			return video -- 346
		end -- 340
	}, -- 340
	{ -- 349
		name = "Resource / TIC80Node", -- 350
		coverage = "TIC80Node dynamic Sprite texture (optional test cart)", -- 351
		expectedTexture = true, -- 352
		build = function() -- 353
			local tic = TIC80Node("../random/cart.tic") -- 354
			if not tic then -- 354
				return unavailable("TIC80Node") -- 355
			end -- 355
			tic.position = Vec2(160, 100) -- 356
			return tic -- 357
		end -- 353
	}, -- 353
	{ -- 360
		name = "Lifecycle / AudioSource", -- 361
		coverage = "AudioSource node lifecycle plus visual sibling", -- 362
		expectedTexture = true, -- 363
		build = function() -- 364
			local root = Node() -- 365
			local audio = AudioSource("Audio/di.wav", false) -- 366
			if audio then -- 366
				root:addChild(audio) -- 367
			end -- 367
			root:addChild(dot( -- 368
				Vec2(160, 100), -- 368
				54, -- 368
				Color(4279150057) -- 368
			)) -- 368
			root:addChild(centered( -- 369
				textLabel("AudioSource", 22), -- 369
				Vec2(160, 100) -- 369
			)) -- 369
			return root -- 370
		end -- 364
	}, -- 364
	{ -- 373
		name = "Physics / World + Body", -- 374
		coverage = "PhysicsWorld, Body and debug renderer", -- 375
		expectedTexture = true, -- 376
		build = function() -- 377
			local world = PhysicsWorld() -- 378
			world.showDebug = true -- 379
			local def = BodyDef() -- 380
			def.type = "Dynamic" -- 381
			def:attachDisk(42, 1, 0.4, 0.2) -- 382
			local body = Body( -- 383
				def, -- 383
				world, -- 383
				Vec2(160, 100) -- 383
			) -- 383
			world:addChild(body) -- 384
			return world -- 385
		end -- 377
	}, -- 377
	{ -- 388
		name = "Nested / View3D", -- 389
		coverage = "View3D nested inside the 2D subtree", -- 390
		expectedTexture = true, -- 391
		manualCheck = "Known failure under investigation: nested 3D content and blue panel should be visible", -- 392
		build = function() -- 393
			local nested = View3D() -- 394
			nested.size = logicalSize -- 395
			local duck = Model3D("Test/Model3D/Assets/Model/Duck.glb") -- 396
			duck.scale = Vec3(0.7, 0.7, 0.7) -- 397
			nested:addChild(duck) -- 398
			return nested -- 399
		end -- 393
	}, -- 393
	{ -- 402
		name = "Lifecycle / PhysicsWorld3D", -- 403
		coverage = "PhysicsWorld3D 2D host-node lifecycle inside the subtree", -- 404
		expectedTexture = true, -- 405
		build = function() -- 406
			local root = Node() -- 407
			local world = PhysicsWorld3D() -- 408
			world.gravity = Vec3(0, -9.81, 0) -- 409
			root:addChild(world) -- 410
			root:addChild(dot( -- 411
				Vec2(160, 100), -- 411
				54, -- 411
				Color(4286893078) -- 411
			)) -- 411
			root:addChild(centered( -- 412
				textLabel("PhysicsWorld3D", 21), -- 412
				Vec2(160, 100) -- 412
			)) -- 412
			return root -- 413
		end -- 406
	}, -- 406
	{ -- 416
		name = "Tree / Direct siblings", -- 417
		coverage = "Sprite + multiple DrawNode siblings without generic containers", -- 418
		expectedTexture = false, -- 419
		build = function() -- 420
			local sprite = Sprite("Image/icon.png") -- 421
			if not sprite then -- 421
				return nil -- 422
			end -- 422
			sprite.position = Vec2(160, 100) -- 423
			sprite.scaleX = 0.45 -- 424
			sprite.scaleY = 0.45 -- 425
			return sprite -- 426
		end -- 420
	}, -- 420
	{ -- 429
		name = "Tree / Generic nested", -- 430
		coverage = "Three-level Node tree with transforms, order and opacity", -- 431
		expectedTexture = true, -- 432
		build = function() -- 433
			local level1 = Node() -- 434
			level1.position = Vec2(160, 100) -- 435
			level1.angle = 12 -- 436
			local level2 = Node() -- 437
			level2.scaleX = 1.15 -- 438
			level2.scaleY = 0.85 -- 439
			local level3 = Node() -- 440
			level3.opacity = 0.82 -- 441
			level3:addChild(dot( -- 442
				Vec2(-42, 0), -- 442
				38, -- 442
				Color(4294950411) -- 442
			)) -- 442
			level3:addChild(dot( -- 443
				Vec2(42, 0), -- 443
				38, -- 443
				Color(4289222135) -- 443
			)) -- 443
			level2:addChild(level3) -- 444
			level1:addChild(level2) -- 445
			return level1 -- 446
		end -- 433
	}, -- 433
	{ -- 449
		name = "Tree / Mixed renderers", -- 450
		coverage = "DrawNode + Sprite + Label + Line + ClipNode in one tree", -- 451
		expectedTexture = true, -- 452
		build = function() -- 453
			local root = Node() -- 454
			root:addChild(dot( -- 455
				Vec2(65, 55), -- 455
				34, -- 455
				Color(4294950411) -- 455
			)) -- 455
			local sprite = Sprite("Image/icon.png") -- 456
			if sprite then -- 456
				sprite.position = Vec2(160, 100) -- 458
				sprite.scaleX = 0.32 -- 459
				sprite.scaleY = 0.32 -- 460
				root:addChild(sprite) -- 461
			end -- 461
			root:addChild(centered( -- 463
				textLabel("MIX", 28), -- 463
				Vec2(255, 145) -- 463
			)) -- 463
			root:addChild(Line( -- 464
				{ -- 464
					Vec2(25, 175), -- 464
					Vec2(295, 175) -- 464
				}, -- 464
				Color(4294967295) -- 464
			)) -- 464
			local clip = ClipNode(dot( -- 465
				Vec2(255, 55), -- 465
				32, -- 465
				Color(4294967295) -- 465
			)) -- 465
			clip:addChild(dot( -- 466
				Vec2(255, 55), -- 466
				55, -- 466
				Color(4293870660) -- 466
			)) -- 466
			root:addChild(clip) -- 467
			return root -- 468
		end -- 453
	}, -- 453
	{ -- 471
		name = "Tree / Grabber nested", -- 472
		coverage = "Generic tree owning its own Grabber render pass", -- 473
		expectedTexture = true, -- 474
		build = function() -- 475
			local root = Node() -- 476
			root.size = logicalSize -- 477
			root:addChild(dot( -- 478
				Vec2(120, 100), -- 478
				58, -- 478
				Color(4294538006) -- 478
			)) -- 478
			root:addChild(dot( -- 479
				Vec2(200, 100), -- 479
				58, -- 479
				Color(4279150057) -- 479
			)) -- 479
			root:grab(true) -- 480
			return root -- 481
		end -- 475
	}, -- 475
	{ -- 484
		name = "Tree / Dynamic churn", -- 485
		coverage = "Runtime-created and removed Node/ClipNode/Label/Sprite branches", -- 486
		expectedTexture = true, -- 487
		build = function() -- 488
			local root = Node() -- 489
			local elapsed = 1 -- 490
			local generation = 0 -- 491
			root:schedule(function(deltaTime) -- 492
				elapsed = elapsed + deltaTime -- 493
				if elapsed < 0.35 then -- 493
					return false -- 494
				end -- 494
				elapsed = 0 -- 495
				generation = generation + 1 -- 496
				root:removeAllChildren(true) -- 497
				do -- 497
					local i = 0 -- 498
					while i < 3 + generation % 4 do -- 498
						local branch = Node() -- 499
						branch.position = Vec2(45 + i * 48, 100 + i % 2 * 28) -- 500
						branch:addChild(dot( -- 501
							Vec2.zero, -- 501
							22, -- 501
							Color(i % 2 == 0 and 4280468830 or 4289222135) -- 501
						)) -- 501
						root:addChild(branch) -- 502
						i = i + 1 -- 498
					end -- 498
				end -- 498
				return false -- 504
			end) -- 492
			return root -- 506
		end -- 488
	} -- 488
} -- 488
local content = Node() -- 511
content.size = logicalSize -- 512
local surface = Surface3D( -- 513
	content, -- 513
	Size(4.8, 3), -- 513
	Size(640, 400) -- 513
) -- 513
if not surface then -- 513
	error("Surface3D creation failed") -- 514
end -- 514
surface.position = Vec3(0, 1.35, 0) -- 515
view:addChild(surface) -- 516
local currentScenario = 1 -- 518
local currentNode -- 519
local currentAvailable = true -- 520
local rebuildCount = 0 -- 521
local autoAdvance = false -- 522
local autoElapsed = 0 -- 523
local billboard = 1 -- 524
local function applyScenario(index) -- 526
	if currentNode then -- 526
		content:removeChild(currentNode, true) -- 528
		currentNode = nil -- 529
	end -- 529
	content:removeAllChildren(true) -- 531
	content:addChild(panel()) -- 532
	currentScenario = index -- 533
	local scenario = scenarios[currentScenario] -- 534
	currentNode = scenario:build() -- 535
	currentAvailable = currentNode ~= nil -- 536
	if currentNode then -- 536
		content:addChild(currentNode) -- 537
	end -- 537
	rebuildCount = rebuildCount + 1 -- 538
	print((("SURFACE_MATRIX scenario=" .. scenario.name) .. " rebuild=") .. tostring(rebuildCount)) -- 539
end -- 526
local function setBillboard(next) -- 542
	billboard = next -- 543
	surface.billboard = next == 2 and "Screen" or (next == 3 and "YAxis" or "None") -- 544
end -- 542
applyScenario(currentScenario) -- 547
print("SURFACE_3D_NODE_MATRIX_READY count=" .. tostring(#scenarios)) -- 548
threadLoop(function() -- 550
	frontDuck.angleY = frontDuck.angleY + App.deltaTime * 25 -- 551
	rearDuck.angleY = rearDuck.angleY - App.deltaTime * 18 -- 552
	if autoAdvance then -- 552
		autoElapsed = autoElapsed + App.deltaTime -- 554
		if autoElapsed >= 2.5 then -- 554
			autoElapsed = 0 -- 556
			applyScenario(currentScenario % #scenarios + 1) -- 557
		end -- 557
	end -- 557
	local scenario = scenarios[currentScenario] -- 561
	ImGui.SetNextWindowPos( -- 562
		Vec2(12, 12), -- 562
		"Always" -- 562
	) -- 562
	ImGui.SetNextWindowSize( -- 563
		Vec2(490, 0), -- 563
		"Always" -- 563
	) -- 563
	ImGui.SetNextWindowBgAlpha(0.9) -- 564
	ImGui.Begin( -- 565
		"Surface3D 2D Node Matrix", -- 565
		{"NoSavedSettings", "NoFocusOnAppearing"}, -- 565
		function() -- 565
			ImGui.Text(("Coverage: " .. tostring(#scenarios)) .. " scenarios") -- 566
			ImGui.TextWrapped(scenario.coverage) -- 567
			ImGui.Separator() -- 568
			local changed = false -- 570
			changed, currentScenario = ImGui.Combo( -- 571
				"2D node / tree", -- 571
				currentScenario, -- 571
				__TS__ArrayMap( -- 571
					scenarios, -- 571
					function(____, item) return item.name end -- 571
				) -- 571
			) -- 571
			if changed then -- 571
				applyScenario(currentScenario) -- 572
			end -- 572
			if ImGui.Button( -- 572
				"Previous", -- 574
				Vec2(145, 30) -- 574
			) then -- 574
				applyScenario((currentScenario + #scenarios - 2) % #scenarios + 1) -- 575
			end -- 575
			ImGui.SameLine() -- 577
			if ImGui.Button( -- 577
				"Rebuild", -- 578
				Vec2(145, 30) -- 578
			) then -- 578
				applyScenario(currentScenario) -- 578
			end -- 578
			ImGui.SameLine() -- 579
			if ImGui.Button( -- 579
				"Next", -- 580
				Vec2(145, 30) -- 580
			) then -- 580
				applyScenario(currentScenario % #scenarios + 1) -- 580
			end -- 580
			changed, autoAdvance = ImGui.Checkbox("Auto advance every 2.5s", autoAdvance) -- 582
			if changed then -- 582
				autoElapsed = 0 -- 583
			end -- 583
			changed, billboard = ImGui.Combo("Billboard", billboard, {"None", "Screen", "Y axis"}) -- 584
			if changed then -- 584
				setBillboard(billboard) -- 585
			end -- 585
			if ImGui.Button( -- 585
				"Rotate -30 deg", -- 587
				Vec2(215, 30) -- 587
			) then -- 587
				surface.angleY = surface.angleY - 30 -- 587
			end -- 587
			ImGui.SameLine() -- 588
			if ImGui.Button( -- 588
				"Rotate +30 deg", -- 589
				Vec2(215, 30) -- 589
			) then -- 589
				surface.angleY = surface.angleY + 30 -- 589
			end -- 589
			ImGui.Separator() -- 591
			local actualTexture = surface.usingTexture -- 592
			local backendMatches = actualTexture == scenario.expectedTexture -- 593
			ImGui.Text("Expected backend: " .. (scenario.expectedTexture and "texture" or "direct")) -- 594
			ImGui.Text("Actual backend: " .. (actualTexture and "texture" or "direct")) -- 595
			ImGui.Text("Resource/build: " .. (currentAvailable and "READY" or "UNAVAILABLE")) -- 596
			ImGui.Text("Backend selection: " .. (backendMatches and "PASS" or "UPDATING")) -- 597
			ImGui.TextWrapped("Manual check: " .. (scenario.manualCheck or "node content remains visible inside the blue panel")) -- 598
			ImGui.Text((("Rebuilds: " .. tostring(rebuildCount)) .. "  Draw calls: ") .. tostring(view.stats.drawCalls)) -- 599
		end -- 565
	) -- 565
	return false -- 601
end) -- 550
return ____exports -- 550