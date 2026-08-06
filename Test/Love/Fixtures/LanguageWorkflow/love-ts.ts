import "love";

let elapsed = 0;
if (false) {
	love.event.pump();
	const typedEventIterator: () => LuaMultiReturn<[string, ...unknown[]] | []> = love.event.poll();
	const typedEvent: LuaMultiReturn<[string, ...unknown[]] | []> = typedEventIterator();
	const typedWait: LuaMultiReturn<[string, ...unknown[]] | []> = love.event.wait();
	const typedPush: boolean = love.event.push("typed", true, 7, "value");
	const typedRestart: true = love.event.quit("restart");
	love.event.clear();
	void typedRestart;
	const typedOS: Love.OS = love.system.getOS();
	const typedProcessors: number = love.system.getProcessorCount();
	const typedPower: LuaMultiReturn<[Love.PowerState, number | undefined, number | undefined]> = love.system.getPowerInfo();
	const typedURL: boolean = love.system.openURL("https://example.com");
	love.system.vibrate(0.25);
	void typedOS;
	void typedProcessors;
	void typedPower;
	void typedURL;
	void typedEvent;
	void typedWait;
	void typedPush;
}
const typedFile: Love.File = love.filesystem.newFile("typed.bin");
const typedFileData: Love.FileData = love.filesystem.newFileData("abc", "typed.bin");
const legacyExists: boolean = love.filesystem.exists("typed.bin");
const legacySize: LuaMultiReturn<[number | undefined, string?]> = love.filesystem.getSize("typed.bin");
void legacyExists;
void legacySize;
const typedDecoder: Love.Decoder = love.sound.newDecoder(typedFileData, 4096);
const decodedChunk: Love.SoundData | undefined = typedDecoder.decode();
typedDecoder.seek(0);
const expandedDecoder: Love.SoundData = love.sound.newSoundData(typedDecoder);
const typedSource: Love.Source = love.audio.newSource(typedFileData.getFilename(), "static");
const typedQueueData: Love.SoundData = love.sound.newSoundData(64, 8000, 16, 1);
const typedQueue: Love.Source = love.audio.newQueueableSource(8000, 16, 1, 4);
const typedQueued: boolean = typedQueue.queue(typedQueueData);
const typedQueuedRegion: boolean = typedQueue.queue(typedQueueData, 0, 32);
const typedFreeBuffers: number = typedQueue.getFreeBufferCount();
const typedSourceClone: Love.Source = typedSource.clone();
const typedSourceDuration: number = typedSource.getDuration("seconds");
const typedSourceChannels: number = typedSource.getChannelCount();
const typedSourceChannelsDeprecated: number = typedSource.getChannels();
typedSource.setPosition(1, 2); typedSource.setVelocity(3, 4, 5); typedSource.setDirection(0, 0, -1); typedSource.setRelative(true);
typedSource.setCone(1.5707963267948966, 3.141592653589793, 0.25, 0.5); typedSource.setAirAbsorption(2); typedSource.setVolumeLimits(0.1, 0.9);
typedSource.setAttenuationDistances(1, 1000); typedSource.setRolloff(0.5);
const typedSourcePosition: LuaMultiReturn<[number, number, number]> = typedSource.getPosition();
const typedSourceVelocity: LuaMultiReturn<[number, number, number]> = typedSource.getVelocity();
const typedSourceDirection: LuaMultiReturn<[number, number, number]> = typedSource.getDirection();
const typedSourceCone: LuaMultiReturn<[number, number, number, number]> = typedSource.getCone();
const typedSourceAirAbsorption: number = typedSource.getAirAbsorption();
const typedSourceVolumeLimits: LuaMultiReturn<[number, number]> = typedSource.getVolumeLimits();
const typedSourceDistances: LuaMultiReturn<[number, number]> = typedSource.getAttenuationDistances();
const typedSourceRelative: boolean = typedSource.isRelative();
const typedSourceRolloff: number = typedSource.getRolloff();
const typedActiveSources: number = love.audio.getActiveSourceCount();
const typedActiveSourcesDeprecated: number = love.audio.getSourceCount();
love.audio.setPosition(10, 20); love.audio.setVelocity(1, 2, 3);
love.audio.setOrientation(0, 0, 1, 0, 1, 0);
love.audio.setDopplerScale(1.5);
const typedDopplerScale: number = love.audio.getDopplerScale();
love.audio.setDistanceModel("linearclamped");
const typedDistanceModel: Love.DistanceModel = love.audio.getDistanceModel();
const typedListenerPosition: LuaMultiReturn<[number, number, number]> = love.audio.getPosition();
const typedListenerVelocity: LuaMultiReturn<[number, number, number]> = love.audio.getVelocity();
const typedListenerOrientation: LuaMultiReturn<[number, number, number, number, number, number]> = love.audio.getOrientation();
typedSource.seek(32, "samples");
void decodedChunk;
void expandedDecoder;
void typedSourceClone;
void typedQueue;
void typedQueued;
void typedQueuedRegion;
void typedFreeBuffers;
void typedActiveSources;
void typedActiveSourcesDeprecated;
void typedListenerPosition;
void typedListenerVelocity;
void typedDopplerScale;
void typedDistanceModel;
void typedListenerOrientation;
void typedSourceDuration;
void typedSourceChannels;
void typedSourceChannelsDeprecated;
void typedSourcePosition;
void typedSourceVelocity;
void typedSourceDirection;
void typedSourceCone;
void typedSourceVolumeLimits;
void typedSourceDistances;
void typedSourceRelative;
void typedSourceRolloff;
const typedRandom: Love.RandomGenerator = love.math.newRandomGenerator(1, 2);
const typedRandomValue: number = typedRandom.random(1, 6);
const typedRandomSeed: LuaMultiReturn<[number, number]> = typedRandom.getSeed();
typedRandom.setState(typedRandom.getState());
const typedTriangles: number[][] = love.math.triangulate([0, 0, 1, 0, 0, 1]);
const typedColor: LuaMultiReturn<[number, number, number, number?]> = love.math.colorToBytes(1, 0.5, 0);
const typedNoise: number = love.math.noise(0.25, 0.5, 0.75);
const typedTransform: Love.Transform = love.math.newTransform(1, 2);
const typedPoint: LuaMultiReturn<[number, number]> = typedTransform.transformPoint(3, 4);
const typedCurve: Love.BezierCurve = love.math.newBezierCurve([0, 0, 10, 20, 20, 0]);
const typedCurvePoint: LuaMultiReturn<[number, number]> = typedCurve.evaluate(0.5);
const typedByteData: Love.ByteData = love.data.newByteData("abcdef");
const typedDataView: Love.DataView = love.data.newDataView(typedByteData, 1, 4);
const typedEncodedData: Love.ByteData = love.data.encode("data", "base64", typedDataView);
const typedCompressedData: Love.CompressedData = love.data.compress("data", "lz4", typedEncodedData);
const typedHash: string = love.data.hash("sha256", typedEncodedData);
const typedDecompressedData: Love.ByteData = love.data.decompress("data", typedCompressedData);
const typedPackedData: Love.ByteData = love.data.pack("data", "<I2", 7);
const typedPackedSize: number = love.data.getPackedSize("<I2");
void typedRandomValue;
void typedRandomSeed;
void typedTriangles;
void typedColor;
void typedNoise;
void typedPoint;
void typedCurvePoint;
void typedDecompressedData;
void typedHash;
void typedPackedData;
void typedPackedSize;
const requirePath: string = love.filesystem.getRequirePath();
love.filesystem.setRequirePath(`custom/?.lua;${requirePath}`);
const typedImageData: Love.ImageData = love.image.newImageData(2, 2);
typedImageData.paste(typedImageData, 0, 0);
const typedPng: Love.FileData = typedImageData.encode("png");
void typedPng;
if (false) {
	const typedCompressedImage: Love.CompressedImageData = love.image.newCompressedData(typedFileData);
	const typedCompressedFormat: Love.CompressedPixelFormat = typedCompressedImage.getFormat();
	const typedCompressedDimensions: LuaMultiReturn<[number, number]> = typedCompressedImage.getDimensions(1);
	const typedIsCompressed: boolean = love.image.isCompressed(typedFileData);
	const typedCompressedTexture: Love.Image = love.graphics.newImage(typedCompressedImage, {mipmaps: true});
	void typedCompressedFormat;
	void typedCompressedDimensions;
	void typedIsCompressed;
	void typedCompressedTexture;
}
const typedFont: Love.Font = love.graphics.newFont(18);
typedFont.setFallbacks(love.graphics.newFont(18));
typedFont.setLineHeight(1.25);
const typedFontMetrics: number[] = [typedFont.getAscent(), typedFont.getDescent(), typedFont.getKerning("A", "V"), typedFont.getLineHeight()];
const typedFontGlyphs: boolean = typedFont.hasGlyphs("Love", 65);
void typedFontMetrics;
void typedFontGlyphs;
const typedText: Love.Text = love.graphics.newText(typedFont, [
	[1, 0.5, 0, 1], "typed", [0, 0.5, 1, 1], " text",
]);
const typedTextIndex: number = typedText.addf("justified text", 160, "justify", typedTransform);
const typedTextDimensions: LuaMultiReturn<[number, number]> = typedText.getDimensions(typedTextIndex);
typedText.setFont(typedFont);
love.graphics.draw(typedText, 10, 20, 0, 1, 1, 0, 0, 0.1, 0);
void typedTextDimensions;
const typedBatchImage: Love.Image = love.graphics.newImage("pig.png");
const typedBatch: Love.SpriteBatch = love.graphics.newSpriteBatch(typedBatchImage, 8, "dynamic");
const typedBatchIndex: number = typedBatch.add(4, 8);
typedBatch.set(typedBatchIndex, love.graphics.newQuad(0, 0, 8, 8, typedBatchImage), 12, 16);
typedBatch.setColor([1, 0.5, 0.25, 1]);
typedBatch.setDrawRange(1, 1);
love.graphics.draw(typedBatch, 0, 0);
const typedParticles: Love.ParticleSystem = love.graphics.newParticleSystem(typedBatchImage, 32);
typedParticles.setParticleLifetime(1, 2);
typedParticles.setEmissionRate(20);
typedParticles.setEmissionArea("uniform", 4, 6, 0, true);
typedParticles.setSpeed(10, 20);
typedParticles.setLinearAcceleration(0, 10, 0, 20);
typedParticles.setSizes(1, 0.5, 0);
typedParticles.setColors([1, 0.5, 0, 1], [0, 0, 1, 0]);
typedParticles.setQuads([love.graphics.newQuad(0, 0, 8, 8, typedBatchImage)]);
typedParticles.emit(4);
typedParticles.update(1 / 60);
const typedParticleLifetime: LuaMultiReturn<[number, number]> = typedParticles.getParticleLifetime();
const typedParticleArea: LuaMultiReturn<[Love.ParticleAreaSpreadDistribution, number, number, number, boolean]> = typedParticles.getEmissionArea();
const typedParticleClone: Love.ParticleSystem = typedParticles.clone();
love.graphics.draw(typedParticles, 0, 0);
void typedParticleLifetime;
void typedParticleArea;
void typedParticleClone;
typedFile.open("w");
typedFile.write(typedFileData);
typedFile.close();

love.load = () => {
	elapsed = 0;
	love.keyboard.setKeyRepeat(true);
	const repeatEnabled: boolean = love.keyboard.hasKeyRepeat();
	const scan: string = love.keyboard.getScancodeFromKey("a");
	const key: string = love.keyboard.getKeyFromScancode(scan);
	const scanDown: boolean = love.keyboard.isScancodeDown(scan);
	const screenKeyboard: boolean = love.keyboard.hasScreenKeyboard();
	love.keyboard.setTextInput(true, 20, 30, 160, 24);
	const textInputActive: boolean = love.keyboard.hasTextInput();
	void repeatEnabled; void key; void scanDown; void screenKeyboard; void textInputActive;
};

love.update = deltaTime => {
	elapsed += deltaTime;
};

love.textedited = (text, start, length) => {
	const selection = text.slice(start, start + length);
	void selection;
};

love.touchpressed = id => {
	const position: LuaMultiReturn<[number, number]> = love.touch.getPosition(id);
	const pressure: number = love.touch.getPressure(id);
	void position;
	void pressure;
};

love.gamepadpressed = (joystick, button) => {
	const connected: boolean = joystick.isConnected();
	const down: boolean = joystick.isGamepadDown(button);
	const axis: number = joystick.getGamepadAxis("leftx");
	void connected;
	void down;
	void axis;
};

const checkCanvasTypes = () => {
	const canvas: Love.Canvas = love.graphics.newCanvas(64, 32, {
		dpiscale: 1,
		msaa: 0,
		format: "rgba8",
		type: "2d",
		readable: true,
		mipmaps: "none",
	});
	const depthStencilCanvas: Love.Canvas = love.graphics.newCanvas(64, 32, {
		format: "depth24stencil8",
		readable: false,
	});
	const dimensions: LuaMultiReturn<[number, number]> = canvas.getPixelDimensions();
	const readback: Love.ImageData = canvas.newImageData(1, 1, 0, 0, 16, 8);
	canvas.setFilter("nearest");
	love.graphics.setCanvas(canvas);
	const current = love.graphics.getCanvas();
	const setup = [canvas] as Love.CanvasSetup;
	setup.depth = true;
	setup.stencil = true;
	setup.depthstencil = depthStencilCanvas;
	love.graphics.setCanvas(setup);
	love.graphics.setCanvas();
	const quad = love.graphics.newQuad(0, 0, 16, 16, canvas);
	love.graphics.draw(canvas, quad, 0, 0);
	void dimensions;
	void readback;
	void current;
};

const checkMeshTypes = () => {
	const mesh: Love.Mesh = love.graphics.newMesh([
		[0, 0, 0, 0, 255, 255, 255, 255],
		[32, 0, 1, 0, 255, 255, 255, 255],
		[0, 32, 0, 1, 255, 255, 255, 255],
	], "triangles", "static");
	mesh.setVertexMap(1, 2, 3);
	mesh.setDrawRange(1, 3);
	const vertex: LuaMultiReturn<[number, ...number[]]> = mesh.getVertex(1);
	const format: Love.MeshVertexFormat[] = mesh.getVertexFormat();
	const count: number = mesh.getVertexCount();
	const packedFormat: Love.MeshVertexFormat[] = [
		["VertexPosition", "float", 2],
		["VertexColor", "byte", 4],
	];
	const packedMesh: Love.Mesh = love.graphics.newMesh(packedFormat, typedFileData, "triangles", "stream");
	packedMesh.setVertices(typedFileData, 1, 1);
	packedMesh.setVertexMap(typedFileData, "uint16", 1);
	mesh.attachAttribute("VertexPosition", packedMesh, "pervertex", "VertexPosition");
	mesh.setAttributeEnabled("VertexPosition", true);
	const positionEnabled: boolean = mesh.isAttributeEnabled("VertexPosition");
	const detached: boolean = mesh.detachAttribute("VertexPosition");
	love.graphics.setDepthMode("less", true);
	const depth: LuaMultiReturn<[Love.CompareMode, boolean]> = love.graphics.getDepthMode();
	love.graphics.setMeshCullMode("back");
	love.graphics.setFrontFaceWinding("ccw");
	love.graphics.draw(mesh, 10, 10);
	love.graphics.drawInstanced(mesh, 2, 10, 10, 0, 1, 1, 0, 0, 0.1, 0.2);
	love.graphics.setDepthMode();
	void vertex;
	void format;
	void count;
	void positionEnabled;
	void detached;
	void depth;
};

const checkShaderTypes = () => {
	const shader: Love.Shader = love.graphics.newShader(`
		extern vec3 tint;
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			return vec4(tint, 1.0) * color;
		}
	`);
	shader.sendColor("tint", [1, 0.5, 0]);
	shader.send("tint", 1, 0.5, 0);
	shader.send("enabled", true);
	shader.send("weights", 0.25, 0.5, 1);
	shader.send("offsets", [2, -2], [4, -4]);
	shader.send("gates", [true, false], [false, true]);
	shader.send("basis", [1, 2, 3, 4]);
	shader.send("frames", "column", [[1, 2, 3], [4, 5, 6], [7, 8, 9]]);
	shader.send("packed", typedFileData, 0, 16);
	shader.send("packedMatrix", "row", typedFileData, 0, 16);
	shader.send("packedMatrix", typedFileData, "column", 0, 16);
	shader.sendColor("packedColor", typedFileData, 0, 16);
	shader.send("mask", love.graphics.newImage("fixture.png"));
	shader.send("overlay", love.graphics.newCanvas(8, 8));
	shader.send("layers", love.graphics.newImage("fixture.png"), love.graphics.newCanvas(8, 8));
	const hasTint: boolean = shader.hasUniform("tint");
	const warnings: string = shader.getWarnings();
	const validation: LuaMultiReturn<[boolean, string?]> = love.graphics.validateShader(false, typedFileData);
	love.graphics.setShader(shader);
	const currentShader: Love.Shader | undefined = love.graphics.getShader();
	love.graphics.setShader();
	void hasTint;
	void warnings;
	void validation;
	void currentShader;
};

const checkPhysicsTypes = () => {
	love.physics.setMeter(64);
	const meter: number = love.physics.getMeter();
	const world: Love.World = love.physics.newWorld(0, 9.81 * meter, true);
	const body: Love.Body = love.physics.newBody(world, 100, 40, "dynamic");
	const circle: Love.CircleShape = love.physics.newCircleShape(12);
	const rectangle: Love.PolygonShape = love.physics.newRectangleShape(0, 0, 80, 16, 0.25);
	const polygon: Love.PolygonShape = love.physics.newPolygonShape([0, 0, 20, 0, 10, 15]);
	const polygonVarargs: Love.PolygonShape = love.physics.newPolygonShape(0, 0, 12, 0, 6, 9);
	const edge: Love.EdgeShape = love.physics.newEdgeShape(-20, 0, 20, 0);
	const chain: Love.ChainShape = love.physics.newChainShape(false, [-20, 0, 0, -10, 20, 0]);
	const loopChain: Love.ChainShape = love.physics.newChainShape(true, 0, 0, 20, 0, 10, 15);
	const chainCount: number = chain.getVertexCount();
	const chainPoint: LuaMultiReturn<[number, number]> = loopChain.getPoint(4);
	const edgePoints: LuaMultiReturn<[number, number, number, number]> = edge.getPoints();
	const childEdge: Love.EdgeShape = chain.getChildEdge(1);
	const childPrevious: LuaMultiReturn<[number, number] | []> = childEdge.getPreviousVertex();
	const childNext: LuaMultiReturn<[number, number] | []> = childEdge.getNextVertex();
	edge.setPreviousVertex(); edge.setNextVertex(30, 0);
	chain.setPreviousVertex(-30, 0); chain.setNextVertex();
	const polygonValid: boolean = polygon.validate() && polygonVarargs.validate();
	const fixture: Love.Fixture = love.physics.newFixture(body, circle, 1);
	fixture.setFriction(0.5); fixture.setRestitution(0.2); fixture.setSensor(false);
	fixture.setDensity(fixture.getDensity()); fixture.getType(); fixture.getBody(); fixture.getShape();
	fixture.testPoint(10, 20); fixture.rayCast(0, 0, 20, 20, 1); fixture.getBoundingBox(); fixture.getMassData();
	fixture.setFilterData(1, 65535, 0); fixture.getFilterData();
	fixture.setCategory(1, 3); fixture.getCategory(); fixture.setMask([2, 4]); fixture.getMask();
	fixture.setGroupIndex(fixture.getGroupIndex()); fixture.setUserData({kind: "fixture"}); fixture.getUserData();
	body.setLinearVelocity(1, 2); body.applyLinearImpulse(3, 4);
	const position: LuaMultiReturn<[number, number]> = body.getPosition();
	const points: LuaMultiReturn<number[]> = rectangle.getPoints();
	const anchor = love.physics.newBody(world, 0, 0, "static");
	const joint: Love.DistanceJoint = love.physics.newDistanceJoint(anchor, body, 0, 0, 100, 40, false);
	const revolute: Love.RevoluteJoint = love.physics.newRevoluteJoint(anchor, body, 0, 0, 0, 0, false, 0.1);
	revolute.setMotorEnabled(true);
	revolute.setMaxMotorTorque(100);
	revolute.setMotorSpeed(2);
	revolute.setLimits(-0.5, 0.5);
	revolute.setLimitsEnabled(true);
	const revoluteState = [revolute.getJointAngle(), revolute.getJointSpeed(), revolute.getMotorTorque(60), revolute.getReferenceAngle(), revolute.areLimitsEnabled()];
	const prismatic: Love.PrismaticJoint = love.physics.newPrismaticJoint(anchor, body, 0, 0, 0, 0, 1, 0, false, 0.1);
	prismatic.setMotorEnabled(true);
	prismatic.setMaxMotorForce(100);
	prismatic.setMotorSpeed(20);
	prismatic.setLimits(-10, 50);
	prismatic.setLimitsEnabled(true);
	const prismaticAxis: LuaMultiReturn<[number, number]> = prismatic.getAxis();
	const prismaticState = [prismatic.getJointTranslation(), prismatic.getJointSpeed(), prismatic.getMotorForce(60), prismatic.getReferenceAngle(), prismatic.areLimitsEnabled()];
	const weld: Love.WeldJoint = love.physics.newWeldJoint(anchor, body, 0, 0, 0, 0, false, 0.1);
	weld.setFrequency(5);
	weld.setDampingRatio(0.6);
	const weldState = [weld.getFrequency(), weld.getDampingRatio(), weld.getReferenceAngle()];
	const friction: Love.FrictionJoint = love.physics.newFrictionJoint(anchor, body, 0, 0, 0, 0, false);
	friction.setMaxForce(100);
	friction.setMaxTorque(1000);
	const frictionState = [friction.getMaxForce(), friction.getMaxTorque()];
	const rope: Love.RopeJoint = love.physics.newRopeJoint(anchor, body, 0, 0, 100, 0, 80, false);
	rope.setMaxLength(rope.getMaxLength());
	const ropeState = [rope.getType(), rope.getMaxLength()];
	void ropeState;
	const pulley: Love.PulleyJoint = love.physics.newPulleyJoint(anchor, body, 0, 0, 100, 0, 0, 40, 100, 60, 2, true);
	const pulleyGround: LuaMultiReturn<[number, number, number, number]> = pulley.getGroundAnchors();
	const pulleyState = [pulley.getLengthA(), pulley.getLengthB(), pulley.getRatio()];
	void pulleyGround; void pulleyState;
	const wheel: Love.WheelJoint = love.physics.newWheelJoint(anchor, body, 0, 0, 0, 20, 0, 1, false);
	wheel.setMotorEnabled(true); wheel.setMotorSpeed(2); wheel.setMaxMotorTorque(1000);
	wheel.setSpringFrequency(4); wheel.setSpringDampingRatio(0.5);
	const wheelAxis: LuaMultiReturn<[number, number]> = wheel.getAxis();
	const wheelState = [wheel.getJointTranslation(), wheel.getJointSpeed(), wheel.isMotorEnabled(), wheel.getMotorSpeed(), wheel.getMaxMotorTorque(), wheel.getMotorTorque(60), wheel.getSpringFrequency(), wheel.getSpringDampingRatio()];
	void wheelAxis; void wheelState;
	const mouse: Love.MouseJoint = love.physics.newMouseJoint(body, 0, 0);
	mouse.setTarget(40, 20); mouse.setMaxForce(1000);
	mouse.setFrequency(5); mouse.setDampingRatio(0.7);
	const mouseTarget: LuaMultiReturn<[number, number]> = mouse.getTarget();
	const mouseState = [mouse.getMaxForce(), mouse.getFrequency(), mouse.getDampingRatio()];
	void mouseTarget; void mouseState;
	const motor: Love.MotorJoint = love.physics.newMotorJoint(anchor, body, 0.4, true);
	motor.setLinearOffset(20, 10); motor.setAngularOffset(0.25);
	motor.setMaxForce(1000); motor.setMaxTorque(2000); motor.setCorrectionFactor(0.6);
	const motorOffset: LuaMultiReturn<[number, number]> = motor.getLinearOffset();
	const motorState = [motor.getAngularOffset(), motor.getMaxForce(), motor.getMaxTorque(), motor.getCorrectionFactor()];
	const gear: Love.GearJoint = love.physics.newGearJoint(revolute, prismatic, 2, true);
	gear.setRatio(-2);
	const gearJoints: LuaMultiReturn<[Love.RevoluteJoint | Love.PrismaticJoint, Love.RevoluteJoint | Love.PrismaticJoint]> = gear.getJoints();
	const gearRatio: number = gear.getRatio();
	void motorOffset; void motorState; void gearJoints; void gearRatio;
	const bodies: LuaMultiReturn<[Love.Body, Love.Body]> = joint.getBodies();
	const beginContact: Love.ContactCallback = (fixtureA, fixtureB, contact) => {
		const fixtures: LuaMultiReturn<[Love.Fixture, Love.Fixture]> = contact.getFixtures();
		const children: LuaMultiReturn<[number, number]> = contact.getChildren();
		const positions: LuaMultiReturn<number[]> = contact.getPositions();
		const normal: LuaMultiReturn<[number, number]> = contact.getNormal();
		contact.setFriction(contact.getFriction());
		contact.setRestitution(contact.getRestitution());
		contact.setTangentSpeed(contact.getTangentSpeed());
		contact.setEnabled(contact.isEnabled());
		const touching: boolean = contact.isTouching();
		void fixtureA; void fixtureB; void fixtures; void children; void positions; void normal; void touching;
	};
	const postSolve: Love.PostSolveCallback = (fixtureA, fixtureB, contact, ...impulses) => {
		void fixtureA; void fixtureB; void contact; void impulses;
	};
	world.setCallbacks(beginContact, undefined, beginContact, postSolve);
	const callbacks: LuaMultiReturn<[Love.ContactCallback | undefined, Love.ContactCallback | undefined,
		Love.ContactCallback | undefined, Love.PostSolveCallback | undefined]> = world.getCallbacks();
	world.queryBoundingBox(0, 0, 200, 200, queriedFixture => queriedFixture === fixture);
	world.rayCast(0, 0, 200, 200, (hitFixture, x, y, normalX, normalY, fraction) => {
		const hit: Love.Fixture = hitFixture;
		void hit; void x; void y; void normalX; void normalY;
		return fraction;
	});
	world.update(1 / 60, 8, 3);
	void position; void points; void bodies; void callbacks; void revoluteState; void prismaticAxis; void prismaticState; void weldState; void frictionState;
	void chainCount; void chainPoint; void edgePoints; void childPrevious; void childNext; void polygonValid;
};

if (false) {
	checkCanvasTypes();
	checkMeshTypes();
	checkShaderTypes();
	checkPhysicsTypes();
}

love.draw = () => {
	const current: number = elapsed;
	love.graphics.clear(0, 0, 0, 1);
	love.graphics.setColor(1, 0.5, 0.25, 1);
	love.graphics.stencil(() => love.graphics.rectangle("fill", 0, 0, 32, 32), "replace", 1);
	love.graphics.setStencilTest("equal", 1);
	const stencilTest: LuaMultiReturn<[Love.CompareMode, number]> = love.graphics.getStencilTest();
	love.graphics.rectangle("fill", 10, 20, 100, 50);
	love.graphics.setStencilTest();
	void stencilTest;
	void current;
};
