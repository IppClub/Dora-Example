-- [ts]: Dora-Example/Test/Love/Fixtures/LanguageWorkflow/love-ts.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__StringSlice = ____lualib.__TS__StringSlice -- 1
local ____exports = {} -- 1
require("love") -- 1
local elapsed = 0 -- 3
if false then -- 3
	love.event.pump() -- 5
	local typedEventIterator = love.event.poll() -- 6
	local typedEvent = {typedEventIterator()} -- 7
	local typedWait = {love.event.wait()} -- 8
	local typedPush = love.event.push("typed", true, 7, "value") -- 9
	local typedRestart = love.event.quit("restart") -- 10
	love.event.clear() -- 11
	local ____ = typedRestart -- 11
	local typedOS = love.system.getOS() -- 13
	local typedProcessors = love.system.getProcessorCount() -- 14
	local typedPower = {love.system.getPowerInfo()} -- 15
	local typedURL = love.system.openURL("https://example.com") -- 16
	love.system.vibrate(0.25) -- 17
	local ____ = typedOS -- 17
	local ____ = typedProcessors -- 17
	local ____ = typedPower -- 17
	local ____ = typedURL -- 17
	local ____ = typedEvent -- 17
	local ____ = typedWait -- 17
	local ____ = typedPush -- 17
end -- 17
local typedFile = love.filesystem.newFile("typed.bin") -- 26
local typedFileData = love.filesystem.newFileData("abc", "typed.bin") -- 27
local legacyExists = love.filesystem.exists("typed.bin") -- 28
local legacySize = {love.filesystem.getSize("typed.bin")} -- 29
local ____ = legacyExists -- 29
local ____ = legacySize -- 29
local typedDecoder = love.sound.newDecoder(typedFileData, 4096) -- 32
local decodedChunk = typedDecoder:decode() -- 33
typedDecoder:seek(0) -- 34
local expandedDecoder = love.sound.newSoundData(typedDecoder) -- 35
local typedSource = love.audio.newSource( -- 36
	typedFileData:getFilename(), -- 36
	"static" -- 36
) -- 36
local typedQueueData = love.sound.newSoundData(64, 8000, 16, 1) -- 37
local typedQueue = love.audio.newQueueableSource(8000, 16, 1, 4) -- 38
local typedQueued = typedQueue:queue(typedQueueData) -- 39
local typedQueuedRegion = typedQueue:queue(typedQueueData, 0, 32) -- 40
local typedFreeBuffers = typedQueue:getFreeBufferCount() -- 41
local typedSourceClone = typedSource:clone() -- 42
local typedSourceDuration = typedSource:getDuration("seconds") -- 43
local typedSourceChannels = typedSource:getChannelCount() -- 44
local typedSourceChannelsDeprecated = typedSource:getChannels() -- 45
typedSource:setPosition(1, 2) -- 46
typedSource:setVelocity(3, 4, 5) -- 46
typedSource:setDirection(0, 0, -1) -- 46
typedSource:setRelative(true) -- 46
typedSource:setCone(1.5707963267948966, 3.141592653589793, 0.25, 0.5) -- 47
typedSource:setAirAbsorption(2) -- 47
typedSource:setVolumeLimits(0.1, 0.9) -- 47
typedSource:setAttenuationDistances(1, 1000) -- 48
typedSource:setRolloff(0.5) -- 48
local typedSourcePosition = {typedSource:getPosition()} -- 49
local typedSourceVelocity = {typedSource:getVelocity()} -- 50
local typedSourceDirection = {typedSource:getDirection()} -- 51
local typedSourceCone = {typedSource:getCone()} -- 52
local typedSourceAirAbsorption = typedSource:getAirAbsorption() -- 53
local typedSourceVolumeLimits = {typedSource:getVolumeLimits()} -- 54
local typedSourceDistances = {typedSource:getAttenuationDistances()} -- 55
local typedSourceRelative = typedSource:isRelative() -- 56
local typedSourceRolloff = typedSource:getRolloff() -- 57
local typedActiveSources = love.audio.getActiveSourceCount() -- 58
local typedActiveSourcesDeprecated = love.audio.getSourceCount() -- 59
love.audio.setPosition(10, 20) -- 60
love.audio.setVelocity(1, 2, 3) -- 60
love.audio.setOrientation( -- 61
	0, -- 61
	0, -- 61
	1, -- 61
	0, -- 61
	1, -- 61
	0 -- 61
) -- 61
love.audio.setDopplerScale(1.5) -- 62
local typedDopplerScale = love.audio.getDopplerScale() -- 63
love.audio.setDistanceModel("linearclamped") -- 64
local typedDistanceModel = love.audio.getDistanceModel() -- 65
local typedListenerPosition = {love.audio.getPosition()} -- 66
local typedListenerVelocity = {love.audio.getVelocity()} -- 67
local typedListenerOrientation = {love.audio.getOrientation()} -- 68
typedSource:seek(32, "samples") -- 69
local ____ = decodedChunk -- 69
local ____ = expandedDecoder -- 69
local ____ = typedSourceClone -- 69
local ____ = typedQueue -- 69
local ____ = typedQueued -- 69
local ____ = typedQueuedRegion -- 69
local ____ = typedFreeBuffers -- 69
local ____ = typedActiveSources -- 69
local ____ = typedActiveSourcesDeprecated -- 69
local ____ = typedListenerPosition -- 69
local ____ = typedListenerVelocity -- 69
local ____ = typedDopplerScale -- 69
local ____ = typedDistanceModel -- 69
local ____ = typedListenerOrientation -- 69
local ____ = typedSourceDuration -- 69
local ____ = typedSourceChannels -- 69
local ____ = typedSourceChannelsDeprecated -- 69
local ____ = typedSourcePosition -- 69
local ____ = typedSourceVelocity -- 69
local ____ = typedSourceDirection -- 69
local ____ = typedSourceCone -- 69
local ____ = typedSourceVolumeLimits -- 69
local ____ = typedSourceDistances -- 69
local ____ = typedSourceRelative -- 69
local ____ = typedSourceRolloff -- 69
local typedRandom = love.math.newRandomGenerator(1, 2) -- 95
local typedRandomValue = typedRandom:random(1, 6) -- 96
local typedRandomSeed = {typedRandom:getSeed()} -- 97
typedRandom:setState(typedRandom:getState()) -- 98
local typedTriangles = love.math.triangulate({ -- 99
	0, -- 99
	0, -- 99
	1, -- 99
	0, -- 99
	0, -- 99
	1 -- 99
}) -- 99
local typedColor = {love.math.colorToBytes(1, 0.5, 0)} -- 100
local typedNoise = love.math.noise(0.25, 0.5, 0.75) -- 101
local typedTransform = love.math.newTransform(1, 2) -- 102
local typedPoint = {typedTransform:transformPoint(3, 4)} -- 103
local typedCurve = love.math.newBezierCurve({ -- 104
	0, -- 104
	0, -- 104
	10, -- 104
	20, -- 104
	20, -- 104
	0 -- 104
}) -- 104
local typedCurvePoint = {typedCurve:evaluate(0.5)} -- 105
local typedByteData = love.data.newByteData("abcdef") -- 106
local typedDataView = love.data.newDataView(typedByteData, 1, 4) -- 107
local typedEncodedData = love.data.encode("data", "base64", typedDataView) -- 108
local typedCompressedData = love.data.compress("data", "lz4", typedEncodedData) -- 109
local typedHash = love.data.hash("sha256", typedEncodedData) -- 110
local typedDecompressedData = love.data.decompress("data", typedCompressedData) -- 111
local typedPackedData = love.data.pack("data", "<I2", 7) -- 112
local typedPackedSize = love.data.getPackedSize("<I2") -- 113
local ____ = typedRandomValue -- 113
local ____ = typedRandomSeed -- 113
local ____ = typedTriangles -- 113
local ____ = typedColor -- 113
local ____ = typedNoise -- 113
local ____ = typedPoint -- 113
local ____ = typedCurvePoint -- 113
local ____ = typedDecompressedData -- 113
local ____ = typedHash -- 113
local ____ = typedPackedData -- 113
local ____ = typedPackedSize -- 113
local requirePath = love.filesystem.getRequirePath() -- 125
love.filesystem.setRequirePath("custom/?.lua;" .. requirePath) -- 126
local typedImageData = love.image.newImageData(2, 2) -- 127
typedImageData:paste(typedImageData, 0, 0) -- 128
local typedPng = typedImageData:encode("png") -- 129
local ____ = typedPng -- 129
if false then -- 129
	local typedCompressedImage = love.image.newCompressedData(typedFileData) -- 132
	local typedCompressedFormat = typedCompressedImage:getFormat() -- 133
	local typedCompressedDimensions = {typedCompressedImage:getDimensions(1)} -- 134
	local typedIsCompressed = love.image.isCompressed(typedFileData) -- 135
	local typedCompressedTexture = love.graphics.newImage(typedCompressedImage, {mipmaps = true}) -- 136
	local ____ = typedCompressedFormat -- 136
	local ____ = typedCompressedDimensions -- 136
	local ____ = typedIsCompressed -- 136
	local ____ = typedCompressedTexture -- 136
end -- 136
local typedFont = love.graphics.newFont(18) -- 142
typedFont:setFallbacks(love.graphics.newFont(18)) -- 143
typedFont:setLineHeight(1.25) -- 144
local typedFontMetrics = { -- 145
	typedFont:getAscent(), -- 145
	typedFont:getDescent(), -- 145
	typedFont:getKerning("A", "V"), -- 145
	typedFont:getLineHeight() -- 145
} -- 145
local typedFontGlyphs = typedFont:hasGlyphs("Love", 65) -- 146
local ____ = typedFontMetrics -- 146
local ____ = typedFontGlyphs -- 146
local typedText = love.graphics.newText(typedFont, {{1, 0.5, 0, 1}, "typed", {0, 0.5, 1, 1}, " text"}) -- 149
local typedTextIndex = typedText:addf("justified text", 160, "justify", typedTransform) -- 152
local typedTextDimensions = {typedText:getDimensions(typedTextIndex)} -- 153
typedText:setFont(typedFont) -- 154
love.graphics.draw( -- 155
	typedText, -- 155
	10, -- 155
	20, -- 155
	0, -- 155
	1, -- 155
	1, -- 155
	0, -- 155
	0, -- 155
	0.1, -- 155
	0 -- 155
) -- 155
local ____ = typedTextDimensions -- 155
local typedBatchImage = love.graphics.newImage("pig.png") -- 157
local typedBatch = love.graphics.newSpriteBatch(typedBatchImage, 8, "dynamic") -- 158
local typedBatchIndex = typedBatch:add(4, 8) -- 159
typedBatch:set( -- 160
	typedBatchIndex, -- 160
	love.graphics.newQuad( -- 160
		0, -- 160
		0, -- 160
		8, -- 160
		8, -- 160
		typedBatchImage -- 160
	), -- 160
	12, -- 160
	16 -- 160
) -- 160
typedBatch:setColor({1, 0.5, 0.25, 1}) -- 161
typedBatch:setDrawRange(1, 1) -- 162
love.graphics.draw(typedBatch, 0, 0) -- 163
local typedParticles = love.graphics.newParticleSystem(typedBatchImage, 32) -- 164
typedParticles:setParticleLifetime(1, 2) -- 165
typedParticles:setEmissionRate(20) -- 166
typedParticles:setEmissionArea( -- 167
	"uniform", -- 167
	4, -- 167
	6, -- 167
	0, -- 167
	true -- 167
) -- 167
typedParticles:setSpeed(10, 20) -- 168
typedParticles:setLinearAcceleration(0, 10, 0, 20) -- 169
typedParticles:setSizes(1, 0.5, 0) -- 170
typedParticles:setColors({1, 0.5, 0, 1}, {0, 0, 1, 0}) -- 171
typedParticles:setQuads({love.graphics.newQuad( -- 172
	0, -- 172
	0, -- 172
	8, -- 172
	8, -- 172
	typedBatchImage -- 172
)}) -- 172
typedParticles:emit(4) -- 173
typedParticles:update(1 / 60) -- 174
local typedParticleLifetime = {typedParticles:getParticleLifetime()} -- 175
local typedParticleArea = {typedParticles:getEmissionArea()} -- 176
local typedParticleClone = typedParticles:clone() -- 177
love.graphics.draw(typedParticles, 0, 0) -- 178
local ____ = typedParticleLifetime -- 178
local ____ = typedParticleArea -- 178
local ____ = typedParticleClone -- 178
typedFile:open("w") -- 182
typedFile:write(typedFileData) -- 183
typedFile:close() -- 184
love.load = function() -- 186
	elapsed = 0 -- 187
	love.keyboard.setKeyRepeat(true) -- 188
	local repeatEnabled = love.keyboard.hasKeyRepeat() -- 189
	local scan = love.keyboard.getScancodeFromKey("a") -- 190
	local key = love.keyboard.getKeyFromScancode(scan) -- 191
	local scanDown = love.keyboard.isScancodeDown(scan) -- 192
	local screenKeyboard = love.keyboard.hasScreenKeyboard() -- 193
	love.keyboard.setTextInput( -- 194
		true, -- 194
		20, -- 194
		30, -- 194
		160, -- 194
		24 -- 194
	) -- 194
	local textInputActive = love.keyboard.hasTextInput() -- 195
	local ____ = repeatEnabled -- 195
	local ____ = key -- 195
	local ____ = scanDown -- 195
	local ____ = screenKeyboard -- 195
	local ____ = textInputActive -- 195
end -- 186
love.update = function(deltaTime) -- 199
	elapsed = elapsed + deltaTime -- 200
end -- 199
love.textedited = function(text, start, length) -- 203
	local selection = __TS__StringSlice(text, start, start + length) -- 204
	local ____ = selection -- 204
end -- 203
love.touchpressed = function(id) -- 208
	local position = {love.touch.getPosition(id)} -- 209
	local pressure = love.touch.getPressure(id) -- 210
	local ____ = position -- 210
	local ____ = pressure -- 210
end -- 208
love.gamepadpressed = function(joystick, button) -- 215
	local connected = joystick:isConnected() -- 216
	local down = joystick:isGamepadDown(button) -- 217
	local axis = joystick:getGamepadAxis("leftx") -- 218
	local ____ = connected -- 218
	local ____ = down -- 218
	local ____ = axis -- 218
end -- 215
local function checkCanvasTypes() -- 224
	local canvas = love.graphics.newCanvas(64, 32, { -- 225
		dpiscale = 1, -- 226
		msaa = 0, -- 227
		format = "rgba8", -- 228
		type = "2d", -- 229
		readable = true, -- 230
		mipmaps = "none" -- 231
	}) -- 231
	local depthStencilCanvas = love.graphics.newCanvas(64, 32, {format = "depth24stencil8", readable = false}) -- 233
	local dimensions = {canvas:getPixelDimensions()} -- 237
	local readback = canvas:newImageData( -- 238
		1, -- 238
		1, -- 238
		0, -- 238
		0, -- 238
		16, -- 238
		8 -- 238
	) -- 238
	canvas:setFilter("nearest") -- 239
	love.graphics.setCanvas(canvas) -- 240
	local current = love.graphics.getCanvas() -- 241
	local setup = {canvas} -- 242
	setup.depth = true -- 243
	setup.stencil = true -- 244
	setup.depthstencil = depthStencilCanvas -- 245
	love.graphics.setCanvas(setup) -- 246
	love.graphics.setCanvas() -- 247
	local quad = love.graphics.newQuad( -- 248
		0, -- 248
		0, -- 248
		16, -- 248
		16, -- 248
		canvas -- 248
	) -- 248
	love.graphics.draw(canvas, quad, 0, 0) -- 249
	local ____ = dimensions -- 249
	local ____ = readback -- 249
	local ____ = current -- 249
end -- 224
local function checkMeshTypes() -- 255
	local mesh = love.graphics.newMesh({{ -- 256
		0, -- 257
		0, -- 257
		0, -- 257
		0, -- 257
		255, -- 257
		255, -- 257
		255, -- 257
		255 -- 257
	}, { -- 257
		32, -- 258
		0, -- 258
		1, -- 258
		0, -- 258
		255, -- 258
		255, -- 258
		255, -- 258
		255 -- 258
	}, { -- 258
		0, -- 259
		32, -- 259
		0, -- 259
		1, -- 259
		255, -- 259
		255, -- 259
		255, -- 259
		255 -- 259
	}}, "triangles", "static") -- 259
	mesh:setVertexMap(1, 2, 3) -- 261
	mesh:setDrawRange(1, 3) -- 262
	local vertex = {mesh:getVertex(1)} -- 263
	local format = mesh:getVertexFormat() -- 264
	local count = mesh:getVertexCount() -- 265
	local packedFormat = {{"VertexPosition", "float", 2}, {"VertexColor", "byte", 4}} -- 266
	local packedMesh = love.graphics.newMesh(packedFormat, typedFileData, "triangles", "stream") -- 270
	packedMesh:setVertices(typedFileData, 1, 1) -- 271
	packedMesh:setVertexMap(typedFileData, "uint16", 1) -- 272
	mesh:attachAttribute("VertexPosition", packedMesh, "pervertex", "VertexPosition") -- 273
	mesh:setAttributeEnabled("VertexPosition", true) -- 274
	local positionEnabled = mesh:isAttributeEnabled("VertexPosition") -- 275
	local detached = mesh:detachAttribute("VertexPosition") -- 276
	love.graphics.setDepthMode("less", true) -- 277
	local depth = {love.graphics.getDepthMode()} -- 278
	love.graphics.setMeshCullMode("back") -- 279
	love.graphics.setFrontFaceWinding("ccw") -- 280
	love.graphics.draw(mesh, 10, 10) -- 281
	love.graphics.drawInstanced( -- 282
		mesh, -- 282
		2, -- 282
		10, -- 282
		10, -- 282
		0, -- 282
		1, -- 282
		1, -- 282
		0, -- 282
		0, -- 282
		0.1, -- 282
		0.2 -- 282
	) -- 282
	love.graphics.setDepthMode() -- 283
	local ____ = vertex -- 283
	local ____ = format -- 283
	local ____ = count -- 283
	local ____ = positionEnabled -- 283
	local ____ = detached -- 283
	local ____ = depth -- 283
end -- 255
local function checkShaderTypes() -- 292
	local shader = love.graphics.newShader("\n\t\textern vec3 tint;\n\t\tvec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {\n\t\t\treturn vec4(tint, 1.0) * color;\n\t\t}\n\t") -- 293
	shader:sendColor("tint", {1, 0.5, 0}) -- 299
	shader:send("tint", 1, 0.5, 0) -- 300
	shader:send("enabled", true) -- 301
	shader:send("weights", 0.25, 0.5, 1) -- 302
	shader:send("offsets", {2, -2}, {4, -4}) -- 303
	shader:send("gates", {true, false}, {false, true}) -- 304
	shader:send("basis", {1, 2, 3, 4}) -- 305
	shader:send("frames", "column", {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}) -- 306
	shader:send("packed", typedFileData, 0, 16) -- 307
	shader:send( -- 308
		"packedMatrix", -- 308
		"row", -- 308
		typedFileData, -- 308
		0, -- 308
		16 -- 308
	) -- 308
	shader:send( -- 309
		"packedMatrix", -- 309
		typedFileData, -- 309
		"column", -- 309
		0, -- 309
		16 -- 309
	) -- 309
	shader:sendColor("packedColor", typedFileData, 0, 16) -- 310
	shader:send( -- 311
		"mask", -- 311
		love.graphics.newImage("fixture.png") -- 311
	) -- 311
	shader:send( -- 312
		"overlay", -- 312
		love.graphics.newCanvas(8, 8) -- 312
	) -- 312
	shader:send( -- 313
		"layers", -- 313
		love.graphics.newImage("fixture.png"), -- 313
		love.graphics.newCanvas(8, 8) -- 313
	) -- 313
	local hasTint = shader:hasUniform("tint") -- 314
	local warnings = shader:getWarnings() -- 315
	local validation = {love.graphics.validateShader(false, typedFileData)} -- 316
	love.graphics.setShader(shader) -- 317
	local currentShader = love.graphics.getShader() -- 318
	love.graphics.setShader() -- 319
	local ____ = hasTint -- 319
	local ____ = warnings -- 319
	local ____ = validation -- 319
	local ____ = currentShader -- 319
end -- 292
local function checkPhysicsTypes() -- 326
	love.physics.setMeter(64) -- 327
	local meter = love.physics.getMeter() -- 328
	local world = love.physics.newWorld(0, 9.81 * meter, true) -- 329
	local body = love.physics.newBody(world, 100, 40, "dynamic") -- 330
	local circle = love.physics.newCircleShape(12) -- 331
	local rectangle = love.physics.newRectangleShape( -- 332
		0, -- 332
		0, -- 332
		80, -- 332
		16, -- 332
		0.25 -- 332
	) -- 332
	local polygon = love.physics.newPolygonShape({ -- 333
		0, -- 333
		0, -- 333
		20, -- 333
		0, -- 333
		10, -- 333
		15 -- 333
	}) -- 333
	local polygonVarargs = love.physics.newPolygonShape( -- 334
		0, -- 334
		0, -- 334
		12, -- 334
		0, -- 334
		6, -- 334
		9 -- 334
	) -- 334
	local edge = love.physics.newEdgeShape(-20, 0, 20, 0) -- 335
	local chain = love.physics.newChainShape(false, { -- 336
		-20, -- 336
		0, -- 336
		0, -- 336
		-10, -- 336
		20, -- 336
		0 -- 336
	}) -- 336
	local loopChain = love.physics.newChainShape( -- 337
		true, -- 337
		0, -- 337
		0, -- 337
		20, -- 337
		0, -- 337
		10, -- 337
		15 -- 337
	) -- 337
	local chainCount = chain:getVertexCount() -- 338
	local chainPoint = {loopChain:getPoint(4)} -- 339
	local edgePoints = {edge:getPoints()} -- 340
	local childEdge = chain:getChildEdge(1) -- 341
	local childPrevious = {childEdge:getPreviousVertex()} -- 342
	local childNext = {childEdge:getNextVertex()} -- 343
	edge:setPreviousVertex() -- 344
	edge:setNextVertex(30, 0) -- 344
	chain:setPreviousVertex(-30, 0) -- 345
	chain:setNextVertex() -- 345
	local polygonValid = polygon:validate() and polygonVarargs:validate() -- 346
	local fixture = love.physics.newFixture(body, circle, 1) -- 347
	fixture:setFriction(0.5) -- 348
	fixture:setRestitution(0.2) -- 348
	fixture:setSensor(false) -- 348
	fixture:setDensity(fixture:getDensity()) -- 349
	fixture:getType() -- 349
	fixture:getBody() -- 349
	fixture:getShape() -- 349
	fixture:testPoint(10, 20) -- 350
	fixture:rayCast( -- 350
		0, -- 350
		0, -- 350
		20, -- 350
		20, -- 350
		1 -- 350
	) -- 350
	fixture:getBoundingBox() -- 350
	fixture:getMassData() -- 350
	fixture:setFilterData(1, 65535, 0) -- 351
	fixture:getFilterData() -- 351
	fixture:setCategory(1, 3) -- 352
	fixture:getCategory() -- 352
	fixture:setMask({2, 4}) -- 352
	fixture:getMask() -- 352
	fixture:setGroupIndex(fixture:getGroupIndex()) -- 353
	fixture:setUserData({kind = "fixture"}) -- 353
	fixture:getUserData() -- 353
	body:setLinearVelocity(1, 2) -- 354
	body:applyLinearImpulse(3, 4) -- 354
	local position = {body:getPosition()} -- 355
	local points = {rectangle:getPoints()} -- 356
	local anchor = love.physics.newBody(world, 0, 0, "static") -- 357
	local joint = love.physics.newDistanceJoint( -- 358
		anchor, -- 358
		body, -- 358
		0, -- 358
		0, -- 358
		100, -- 358
		40, -- 358
		false -- 358
	) -- 358
	local revolute = love.physics.newRevoluteJoint( -- 359
		anchor, -- 359
		body, -- 359
		0, -- 359
		0, -- 359
		0, -- 359
		0, -- 359
		false, -- 359
		0.1 -- 359
	) -- 359
	revolute:setMotorEnabled(true) -- 360
	revolute:setMaxMotorTorque(100) -- 361
	revolute:setMotorSpeed(2) -- 362
	revolute:setLimits(-0.5, 0.5) -- 363
	revolute:setLimitsEnabled(true) -- 364
	local revoluteState = { -- 365
		revolute:getJointAngle(), -- 365
		revolute:getJointSpeed(), -- 365
		revolute:getMotorTorque(60), -- 365
		revolute:getReferenceAngle(), -- 365
		revolute:areLimitsEnabled() -- 365
	} -- 365
	local prismatic = love.physics.newPrismaticJoint( -- 366
		anchor, -- 366
		body, -- 366
		0, -- 366
		0, -- 366
		0, -- 366
		0, -- 366
		1, -- 366
		0, -- 366
		false, -- 366
		0.1 -- 366
	) -- 366
	prismatic:setMotorEnabled(true) -- 367
	prismatic:setMaxMotorForce(100) -- 368
	prismatic:setMotorSpeed(20) -- 369
	prismatic:setLimits(-10, 50) -- 370
	prismatic:setLimitsEnabled(true) -- 371
	local prismaticAxis = {prismatic:getAxis()} -- 372
	local prismaticState = { -- 373
		prismatic:getJointTranslation(), -- 373
		prismatic:getJointSpeed(), -- 373
		prismatic:getMotorForce(60), -- 373
		prismatic:getReferenceAngle(), -- 373
		prismatic:areLimitsEnabled() -- 373
	} -- 373
	local weld = love.physics.newWeldJoint( -- 374
		anchor, -- 374
		body, -- 374
		0, -- 374
		0, -- 374
		0, -- 374
		0, -- 374
		false, -- 374
		0.1 -- 374
	) -- 374
	weld:setFrequency(5) -- 375
	weld:setDampingRatio(0.6) -- 376
	local weldState = { -- 377
		weld:getFrequency(), -- 377
		weld:getDampingRatio(), -- 377
		weld:getReferenceAngle() -- 377
	} -- 377
	local friction = love.physics.newFrictionJoint( -- 378
		anchor, -- 378
		body, -- 378
		0, -- 378
		0, -- 378
		0, -- 378
		0, -- 378
		false -- 378
	) -- 378
	friction:setMaxForce(100) -- 379
	friction:setMaxTorque(1000) -- 380
	local frictionState = { -- 381
		friction:getMaxForce(), -- 381
		friction:getMaxTorque() -- 381
	} -- 381
	local rope = love.physics.newRopeJoint( -- 382
		anchor, -- 382
		body, -- 382
		0, -- 382
		0, -- 382
		100, -- 382
		0, -- 382
		80, -- 382
		false -- 382
	) -- 382
	rope:setMaxLength(rope:getMaxLength()) -- 383
	local ropeState = { -- 384
		rope:getType(), -- 384
		rope:getMaxLength() -- 384
	} -- 384
	local ____ = ropeState -- 384
	local pulley = love.physics.newPulleyJoint( -- 386
		anchor, -- 386
		body, -- 386
		0, -- 386
		0, -- 386
		100, -- 386
		0, -- 386
		0, -- 386
		40, -- 386
		100, -- 386
		60, -- 386
		2, -- 386
		true -- 386
	) -- 386
	local pulleyGround = {pulley:getGroundAnchors()} -- 387
	local pulleyState = { -- 388
		pulley:getLengthA(), -- 388
		pulley:getLengthB(), -- 388
		pulley:getRatio() -- 388
	} -- 388
	local ____ = pulleyGround -- 388
	local ____ = pulleyState -- 388
	local wheel = love.physics.newWheelJoint( -- 390
		anchor, -- 390
		body, -- 390
		0, -- 390
		0, -- 390
		0, -- 390
		20, -- 390
		0, -- 390
		1, -- 390
		false -- 390
	) -- 390
	wheel:setMotorEnabled(true) -- 391
	wheel:setMotorSpeed(2) -- 391
	wheel:setMaxMotorTorque(1000) -- 391
	wheel:setSpringFrequency(4) -- 392
	wheel:setSpringDampingRatio(0.5) -- 392
	local wheelAxis = {wheel:getAxis()} -- 393
	local wheelState = { -- 394
		wheel:getJointTranslation(), -- 394
		wheel:getJointSpeed(), -- 394
		wheel:isMotorEnabled(), -- 394
		wheel:getMotorSpeed(), -- 394
		wheel:getMaxMotorTorque(), -- 394
		wheel:getMotorTorque(60), -- 394
		wheel:getSpringFrequency(), -- 394
		wheel:getSpringDampingRatio() -- 394
	} -- 394
	local ____ = wheelAxis -- 394
	local ____ = wheelState -- 394
	local mouse = love.physics.newMouseJoint(body, 0, 0) -- 396
	mouse:setTarget(40, 20) -- 397
	mouse:setMaxForce(1000) -- 397
	mouse:setFrequency(5) -- 398
	mouse:setDampingRatio(0.7) -- 398
	local mouseTarget = {mouse:getTarget()} -- 399
	local mouseState = { -- 400
		mouse:getMaxForce(), -- 400
		mouse:getFrequency(), -- 400
		mouse:getDampingRatio() -- 400
	} -- 400
	local ____ = mouseTarget -- 400
	local ____ = mouseState -- 400
	local motor = love.physics.newMotorJoint(anchor, body, 0.4, true) -- 402
	motor:setLinearOffset(20, 10) -- 403
	motor:setAngularOffset(0.25) -- 403
	motor:setMaxForce(1000) -- 404
	motor:setMaxTorque(2000) -- 404
	motor:setCorrectionFactor(0.6) -- 404
	local motorOffset = {motor:getLinearOffset()} -- 405
	local motorState = { -- 406
		motor:getAngularOffset(), -- 406
		motor:getMaxForce(), -- 406
		motor:getMaxTorque(), -- 406
		motor:getCorrectionFactor() -- 406
	} -- 406
	local gear = love.physics.newGearJoint(revolute, prismatic, 2, true) -- 407
	gear:setRatio(-2) -- 408
	local gearJoints = {gear:getJoints()} -- 409
	local gearRatio = gear:getRatio() -- 410
	local ____ = motorOffset -- 410
	local ____ = motorState -- 410
	local ____ = gearJoints -- 410
	local ____ = gearRatio -- 410
	local bodies = {joint:getBodies()} -- 412
	local function beginContact(fixtureA, fixtureB, contact) -- 413
		local fixtures = {contact:getFixtures()} -- 414
		local children = {contact:getChildren()} -- 415
		local positions = {contact:getPositions()} -- 416
		local normal = {contact:getNormal()} -- 417
		contact:setFriction(contact:getFriction()) -- 418
		contact:setRestitution(contact:getRestitution()) -- 419
		contact:setTangentSpeed(contact:getTangentSpeed()) -- 420
		contact:setEnabled(contact:isEnabled()) -- 421
		local touching = contact:isTouching() -- 422
		local ____ = fixtureA -- 422
		local ____ = fixtureB -- 422
		local ____ = fixtures -- 422
		local ____ = children -- 422
		local ____ = positions -- 422
		local ____ = normal -- 422
		local ____ = touching -- 422
	end -- 413
	local function postSolve(fixtureA, fixtureB, contact, ...) -- 425
		local impulses = {...} -- 425
		local ____ = fixtureA -- 425
		local ____ = fixtureB -- 425
		local ____ = contact -- 425
		local ____ = impulses -- 425
	end -- 425
	world:setCallbacks(beginContact, nil, beginContact, postSolve) -- 428
	local callbacks = {world:getCallbacks()} -- 429
	world:queryBoundingBox( -- 431
		0, -- 431
		0, -- 431
		200, -- 431
		200, -- 431
		function(queriedFixture) return queriedFixture == fixture end -- 431
	) -- 431
	world:rayCast( -- 432
		0, -- 432
		0, -- 432
		200, -- 432
		200, -- 432
		function(hitFixture, x, y, normalX, normalY, fraction) -- 432
			local hit = hitFixture -- 433
			local ____ = hit -- 433
			local ____ = x -- 433
			local ____ = y -- 433
			local ____ = normalX -- 433
			local ____ = normalY -- 433
			return fraction -- 435
		end -- 432
	) -- 432
	world:update(1 / 60, 8, 3) -- 437
	local ____ = position -- 437
	local ____ = points -- 437
	local ____ = bodies -- 437
	local ____ = callbacks -- 437
	local ____ = revoluteState -- 437
	local ____ = prismaticAxis -- 437
	local ____ = prismaticState -- 437
	local ____ = weldState -- 437
	local ____ = frictionState -- 437
	local ____ = chainCount -- 437
	local ____ = chainPoint -- 437
	local ____ = edgePoints -- 437
	local ____ = childPrevious -- 437
	local ____ = childNext -- 437
	local ____ = polygonValid -- 437
end -- 326
if false then -- 326
	checkCanvasTypes() -- 443
	checkMeshTypes() -- 444
	checkShaderTypes() -- 445
	checkPhysicsTypes() -- 446
end -- 446
love.draw = function() -- 449
	local current = elapsed -- 450
	love.graphics.clear(0, 0, 0, 1) -- 451
	love.graphics.setColor(1, 0.5, 0.25, 1) -- 452
	love.graphics.stencil( -- 453
		function() return love.graphics.rectangle( -- 453
			"fill", -- 453
			0, -- 453
			0, -- 453
			32, -- 453
			32 -- 453
		) end, -- 453
		"replace", -- 453
		1 -- 453
	) -- 453
	love.graphics.setStencilTest("equal", 1) -- 454
	local stencilTest = {love.graphics.getStencilTest()} -- 455
	love.graphics.rectangle( -- 456
		"fill", -- 456
		10, -- 456
		20, -- 456
		100, -- 456
		50 -- 456
	) -- 456
	love.graphics.setStencilTest() -- 457
	local ____ = stencilTest -- 457
	local ____ = current -- 457
end -- 449
return ____exports -- 449