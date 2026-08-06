#!/usr/bin/env node

import {createRequire} from "node:module";
import {readFileSync} from "node:fs";
import nodePath from "node:path";
import {doraSSRRoot} from "./TestPaths.mjs";

const require = createRequire(import.meta.url);
const ts = require(nodePath.join(doraSSRRoot, "Tools/dora-dora/node_modules/typescript"));
const readSource = path => readFileSync(path, "utf8").replace(/\r\n?/g, "\n");
const runtime = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveRuntime.cpp"));
const loveNode = readSource(nodePath.join(doraSSRRoot, "Source/Love/LoveNode.cpp"));

function upstreamMethods(path) {
	const source = readFileSync(nodePath.join(doraSSRRoot, "Source/3rdParty/Love/src/modules", path), "utf8");
	const text = source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
	return new Set([...text.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,\s*w_/g)].map(value => value[1]));
}

function upstreamGraphicsMethods(type) {
	return upstreamMethods(`graphics/wrap_${type}.cpp`);
}

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

assert(runtime.includes("struct DoraHandleObject : ::love::Object"),
	"Dora backend handles must share the Love Object-backed handle wrapper");
for (const type of ["Image", "Canvas", "Cursor", "Font", "Shader", "AudioSource",
	"Video", "RecordingDevice", "PhysicsWorld", "PhysicsBody", "PhysicsShape",
	"PhysicsFixture", "PhysicsJoint"]) {
	assert(new RegExp(`struct ${type}Userdata final\\s*\\n\\s*: DoraHandleObject<`).test(runtime),
		`${type} userdata bypasses the shared Dora handle wrapper`);
}
assert(!/int LoveRuntime::[A-Za-z0-9_]+GC\s*\(/.test(runtime),
	"legacy per-type GC callbacks must not coexist with Love's common Object runtime");
assert(!/->~[A-Za-z0-9_]+Userdata\s*\(/.test(runtime),
	"Love userdata must not be destroyed manually outside Object::release");
assert(runtime.includes("void adoptDoraHandle(Handle valueHandle) noexcept")
	&& runtime.includes("void invalidateDoraHandle() noexcept")
	&& runtime.includes("void replaceDoraHandle(Handle valueHandle) noexcept")
	&& runtime.includes("(runtime->*Retain)(handle)")
	&& runtime.includes("(runtime->*Forget)(handle)"),
	"Dora handle adoption, invalidation, and replacement must stay inside the shared wrapper");

assert(runtime.includes("void pushNewDoraHandleObject(lua_State *state, ::love::Type &type, Object *object)")
	&& runtime.includes("::love::luax_pushtype(state, type, object);")
	&& runtime.includes("object->release();"),
	"new Dora handle wrappers must hand their constructor reference to Love's Lua Proxy");
const doraHandleAllocations = [...runtime.matchAll(
	/auto \*(\w+) = new (Image|Canvas|Cursor|Font|Shader|AudioSource|Video|RecordingDevice|PhysicsWorld|PhysicsBody|PhysicsShape|PhysicsFixture|PhysicsJoint)Userdata\b/g)];
assert(doraHandleAllocations.length === 31,
	`expected 31 Dora handle wrapper allocation paths, found ${doraHandleAllocations.length}`);
for (const allocation of doraHandleAllocations) {
	const [_, variable, type] = allocation;
	const tail = runtime.slice(allocation.index, allocation.index + 1200);
	const proxyHandoff = new RegExp(`pushNewDoraHandleObject\\(state, [^;]+, ${variable}\\);`).test(tail);
	const nativeHandoff = type === "Font"
		&& tail.includes(`_graphicsFontObject.set(${variable}, ::love::Acquire::NORETAIN);`);
	assert(proxyHandoff || nativeHandoff,
		`${type} wrapper allocation '${variable}' does not transfer its initial native reference`);
}
assert(!/luax_pushtype\([^;]+(?:Image|Canvas|Cursor|Font|Shader|AudioSource|Video|RecordingDevice|Physics(?:World|Body|Shape|Fixture|Joint))(?:Userdata::type|LoveType)[^;]*\);\s*\w+->release\(\);/.test(runtime),
	"Dora handle Proxy ownership handoff must use pushNewDoraHandleObject instead of an open-coded pair");

for (const [set, retain] of [
	["_imageHandles", "retainLoveImageHandle"],
	["_canvasHandles", "retainLoveCanvasHandle"],
	["_fontHandles", "retainLoveFontHandle"],
	["_shaderHandles", "retainLoveShaderHandle"],
	["_audioHandles", "retainLoveAudioSourceHandle"],
	["_mouseCursorHandles", "retainLoveCursorHandle"],
	["_recordingHandles", "retainLoveRecordingHandle"],
	["_physicsWorldHandles", "retainLovePhysicsWorldHandle"],
	["_physicsBodyHandles", "retainLovePhysicsBodyHandle"],
	["_physicsShapeHandles", "retainLovePhysicsShapeHandle"],
	["_physicsFixtureHandles", "retainLovePhysicsFixtureHandle"],
	["_physicsJointHandles", "retainLovePhysicsJointHandle"],
]) {
	assert(runtime.split(`${set}.insert(`).length - 1 === 1
		&& runtime.includes(`void LoveRuntime::${retain}(`),
		`${set} ownership adoption bypasses the shared Dora handle wrapper`);
}
assert(loveNode.includes("format == bgfx::TextureFormat::ETC2A1")
	&& loveNode.includes("BGFX_CAPS_FORMAT_TEXTURE_2D_EMULATED")
	&& loveNode.split("isLoveCompressedTextureValid(").length - 1 === 4,
	"compressed image query and both creation paths must share the ETC2A1 emulation guard");

for (const [call, expected] of [
	["_graphicsBackend->releaseImage(", 1],
	["_graphicsBackend->releaseCanvas(", 1],
	["_graphicsBackend->releaseFont(", 1],
	["_graphicsBackend->releaseShader(", 1],
	["_audioBackend->releaseSource(", 1],
	["_audioBackend->stopRecording(", 1],
	["_mouseBackend->releaseCursor(", 1],
	["_physicsBackend->releaseWorld(", 1],
	["_physicsBackend->releaseBody(", 1],
	["_physicsBackend->releaseShape(", 1],
	["_physicsBackend->releaseFixture(", 1],
	["_physicsBackend->releaseJoint(", 1],
]) {
	assert(runtime.split(call).length - 1 === expected,
		`${call.slice(0, -1)} bypasses or duplicates the centralized Dora handle release path`);
}

for (const functionName of ["physicsWorldDestroy", "physicsBodyDestroy",
	"physicsFixtureDestroy", "physicsJointDestroy", "recordingDeviceStop"]) {
	const start = runtime.indexOf(`int LoveRuntime::${functionName}(`);
	const end = runtime.indexOf("\nint LoveRuntime::", start + 1);
	assert(start >= 0 && runtime.slice(start, end < 0 ? runtime.length : end)
		.includes("releaseDoraHandle()"),
		`${functionName} bypasses the shared Dora handle wrapper`);
}

function functionBody(name) {
	const match = runtime.match(new RegExp(`void LoveRuntime::${name}\\(\\)\\n\\{([\\s\\S]*?)(?=\\nvoid LoveRuntime::)`));
	assert(match, `runtime registration function ${name} was not found`);
	return match[1];
}

function namesInRegistrationFunction(name) {
	const body = functionBody(name);
	const names = new Set([...body.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)]
		.map(value => value[1]).filter(value => !value.startsWith("__")));
	for (const match of body.matchAll(/lua_setfield\(_state,\s*-2,\s*"([A-Za-z_]\w*)"\)/g)) {
		if (!match[1].startsWith("__")) names.add(match[1]);
	}
	if (body.includes("addLoveObjectMethods") || body.includes("luax_register_type")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

function methodsInRegistrationArray(registrationName, arrayName) {
	const body = functionBody(registrationName);
	const match = body.match(new RegExp(`${arrayName}\\[\\]\\s*=\\s*\\{([\\s\\S]*?)\\n\\s*\\};`));
	assert(match, `${registrationName} registration array ${arrayName} was not found`);
	return new Set([
		...[...match[1].matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)]
			.map(value => value[1]).filter(value => !value.startsWith("__")),
		"type", "typeOf", "release",
	]);
}

function union(...sets) {
	return new Set(sets.flatMap(set => [...set]));
}

function moduleRegistrationNames(moduleName) {
	const body = functionBody("registerLoveModule");
	const marker = `lua_setfield(_state, -2, "${moduleName}");`;
	const end = body.indexOf(marker);
	assert(end >= 0, `runtime module registration ${moduleName} was not found`);
	const start = body.lastIndexOf("lua_newtable(_state);", end);
	assert(start >= 0, `runtime module table ${moduleName} was not found`);
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	for (const match of block.matchAll(/lua_setfield\(_state,\s*-[23],\s*"([A-Za-z_]\w*)"\)/g)) {
		if (!match[1].startsWith("_")) names.add(match[1]);
	}
	return names;
}

const runtimeModules = new Map([
	["Graphics", moduleRegistrationNames("graphics")],
	["ImageModule", moduleRegistrationNames("image")],
	["FontModule", moduleRegistrationNames("font")],
	["SoundModule", moduleRegistrationNames("sound")],
	["DataModule", moduleRegistrationNames("data")],
	["MathModule", moduleRegistrationNames("math")],
	["Window", moduleRegistrationNames("window")],
	["Event", moduleRegistrationNames("event")],
	["Filesystem", moduleRegistrationNames("filesystem")],
	["Keyboard", moduleRegistrationNames("keyboard")],
	["Mouse", moduleRegistrationNames("mouse")],
	["Touch", moduleRegistrationNames("touch")],
	["JoystickModule", moduleRegistrationNames("joystick")],
	["Timer", moduleRegistrationNames("timer")],
	["Audio", moduleRegistrationNames("audio")],
	["System", moduleRegistrationNames("system")],
	["ThreadModule", moduleRegistrationNames("thread")],
	["VideoModule", moduleRegistrationNames("video")],
	["Physics", moduleRegistrationNames("physics")],
]);
// Internal closure capture used by module-level RNG methods, not an upstream
// Love Lua API and intentionally absent from editor declarations.
runtimeModules.get("MathModule").delete("_getRandomGenerator");

const runtimeObjects = new Map([
	["Image", namesInRegistrationFunction("registerImageType")],
	["Canvas", namesInRegistrationFunction("registerCanvasType")],
	["ImageData", namesInRegistrationFunction("registerImageDataType")],
	["CompressedImageData", namesInRegistrationFunction("registerCompressedImageDataType")],
	["Rasterizer", namesInRegistrationFunction("registerRasterizerType")],
	["GlyphData", namesInRegistrationFunction("registerGlyphDataType")],
	["SoundData", namesInRegistrationFunction("registerSoundDataType")],
	["Decoder", namesInRegistrationFunction("registerDecoderType")],
	["RandomGenerator", namesInRegistrationFunction("registerRandomGeneratorType")],
	["Transform", namesInRegistrationFunction("registerTransformType")],
	["BezierCurve", namesInRegistrationFunction("registerBezierCurveType")],
	["ByteData", namesInRegistrationFunction("registerByteDataType")],
	["DataView", namesInRegistrationFunction("registerDataViewType")],
	["CompressedData", namesInRegistrationFunction("registerCompressedDataType")],
	["Quad", namesInRegistrationFunction("registerQuadType")],
	["Mesh", namesInRegistrationFunction("registerMeshType")],
	["SpriteBatch", namesInRegistrationFunction("registerSpriteBatchType")],
	["ParticleSystem", namesInRegistrationFunction("registerParticleSystemType")],
	["Text", namesInRegistrationFunction("registerTextType")],
	["Shader", namesInRegistrationFunction("registerShaderType")],
	["Font", namesInRegistrationFunction("registerFontType")],
	["Source", namesInRegistrationFunction("registerAudioSourceType")],
	["RecordingDevice", namesInRegistrationFunction("registerRecordingDeviceType")],
	["Cursor", namesInRegistrationFunction("registerCursorType")],
	["Joystick", namesInRegistrationFunction("registerJoystickType")],
	["File", namesInRegistrationFunction("registerFileType")],
	["FileData", namesInRegistrationFunction("registerFileDataType")],
]);

function methodsInMetatableBlock(registrationName, metatable, nextMetatable = null) {
	const body = functionBody(registrationName);
	const marker = `if (luaL_newmetatable(_state, ${metatable}))`;
	const start = body.indexOf(marker);
	assert(start >= 0, `${registrationName} registration ${metatable} was not found`);
	let end = nextMetatable
		? body.indexOf(`if (luaL_newmetatable(_state, ${nextMetatable}))`, start + marker.length)
		: body.length;
	if (end < 0) end = body.length;
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	if (block.includes("addLoveObjectMethods")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

runtimeObjects.set("VideoStream", methodsInRegistrationArray("registerVideoTypes", "streamFunctions"));
runtimeObjects.set("Video", methodsInRegistrationArray("registerVideoTypes", "videoFunctions"));

function threadMethods(metatable) {
	const body = functionBody("registerThreadTypes");
	const marker = `if (luaL_newmetatable(_state, ${metatable}))`;
	const start = body.indexOf(marker);
	assert(start >= 0, `thread registration ${metatable} was not found`);
	let end = body.indexOf("\n\tif (luaL_newmetatable", start + marker.length);
	if (end < 0) end = body.length;
	const block = body.slice(start, end);
	const names = new Set([...block.matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]));
	if (block.includes("addLoveObjectMethods")) {
		names.add("type");
		names.add("typeOf");
		names.add("release");
	}
	return names;
}

runtimeObjects.set("Thread", methodsInRegistrationArray("registerThreadTypes", "threadFunctions"));
runtimeObjects.set("Channel", methodsInRegistrationArray("registerThreadTypes", "channelFunctions"));

function physicsMethods(typeName) {
	const body = functionBody("registerPhysicsTypes");
	const match = body.match(new RegExp(`registerType\\(&${typeName},\\s*\\{([\\s\\S]*?)\\n\\s*\\}\\);`));
	assert(match, `physics registration ${typeName} was not found`);
	return new Set([
		...[...match[1].matchAll(/\{\s*"([A-Za-z_]\w*)"\s*,/g)].map(value => value[1]),
		"type", "typeOf", "release",
	]);
}

for (const [type, typeName] of [
	["World", "PhysicsWorldLoveType"], ["Body", "PhysicsBodyLoveType"],
	["Shape", "PhysicsShapeLoveType"], ["Fixture", "PhysicsFixtureLoveType"],
	["Joint", "PhysicsJointLoveType"], ["Contact", "PhysicsContactLoveType"],
]) runtimeObjects.set(type, physicsMethods(typeName));

const upstreamGraphicsModule = upstreamGraphicsMethods("Graphics");
upstreamGraphicsModule.delete("_setDefaultShaderCode");
const missingGraphicsModuleMethods = [...upstreamGraphicsModule]
	.filter(name => !runtimeModules.get("Graphics").has(name)).sort();
assert(missingGraphicsModuleMethods.length === 0,
	`runtime Graphics is missing Love 11.5 wrapper methods: ${missingGraphicsModuleMethods.join(", ")}`);

const upstreamTextureMethods = upstreamGraphicsMethods("Texture");
const upstreamGraphicsObjects = new Map([
	["Image", union(upstreamTextureMethods, upstreamGraphicsMethods("Image"))],
	["Canvas", union(upstreamTextureMethods, upstreamGraphicsMethods("Canvas"))],
	["Font", upstreamGraphicsMethods("Font")],
	["Mesh", upstreamGraphicsMethods("Mesh")],
	["ParticleSystem", upstreamGraphicsMethods("ParticleSystem")],
	["Quad", upstreamGraphicsMethods("Quad")],
	["Shader", upstreamGraphicsMethods("Shader")],
	["SpriteBatch", upstreamGraphicsMethods("SpriteBatch")],
	["Text", upstreamGraphicsMethods("Text")],
	["Video", upstreamGraphicsMethods("Video")],
]);
// Love's Lua wrapper exposes Video:setSource while the C wrapper names the
// implementation hook _setSource. Dora registers the public method directly.
upstreamGraphicsObjects.get("Video").delete("_setSource");
upstreamGraphicsObjects.get("Video").add("setSource");
let upstreamGraphicsMethodChecks = upstreamGraphicsModule.size;
for (const [type, expected] of upstreamGraphicsObjects) {
	const actual = runtimeObjects.get(type);
	assert(actual, `runtime Graphics object registration ${type} was not found`);
	const missing = [...expected].filter(name => !actual.has(name)).sort();
	assert(missing.length === 0,
		`runtime ${type} is missing Love 11.5 wrapper methods: ${missing.join(", ")}`);
	upstreamGraphicsMethodChecks += expected.size;
}

const upstreamModuleFiles = new Map([
	["Audio", "audio/wrap_Audio.cpp"],
	["DataModule", "data/wrap_DataModule.cpp"],
	["Event", "event/wrap_Event.cpp"],
	["Filesystem", "filesystem/wrap_Filesystem.cpp"],
	["FontModule", "font/wrap_Font.cpp"],
	["ImageModule", "image/wrap_Image.cpp"],
	["JoystickModule", "joystick/wrap_JoystickModule.cpp"],
	["Keyboard", "keyboard/wrap_Keyboard.cpp"],
	["MathModule", "math/wrap_Math.cpp"],
	["Mouse", "mouse/wrap_Mouse.cpp"],
	["SoundModule", "sound/wrap_Sound.cpp"],
	["System", "system/wrap_System.cpp"],
	["ThreadModule", "thread/wrap_ThreadModule.cpp"],
	["Timer", "timer/wrap_Timer.cpp"],
	["Touch", "touch/wrap_Touch.cpp"],
	["VideoModule", "video/wrap_Video.cpp"],
	["Window", "window/wrap_Window.cpp"],
]);

const upstreamObjectFiles = new Map([
	["RecordingDevice", ["audio/wrap_RecordingDevice.cpp"]],
	["Source", ["audio/wrap_Source.cpp"]],
	["ByteData", ["data/wrap_ByteData.cpp", "data/wrap_Data.cpp"]],
	["CompressedData", ["data/wrap_CompressedData.cpp", "data/wrap_Data.cpp"]],
	["DataView", ["data/wrap_DataView.cpp", "data/wrap_Data.cpp"]],
	["File", ["filesystem/wrap_File.cpp"]],
	["FileData", ["filesystem/wrap_FileData.cpp", "data/wrap_Data.cpp"]],
	["GlyphData", ["font/wrap_GlyphData.cpp", "data/wrap_Data.cpp"]],
	["Rasterizer", ["font/wrap_Rasterizer.cpp"]],
	["CompressedImageData", ["image/wrap_CompressedImageData.cpp", "data/wrap_Data.cpp"]],
	["ImageData", ["image/wrap_ImageData.cpp", "data/wrap_Data.cpp"]],
	["Joystick", ["joystick/wrap_Joystick.cpp"]],
	["BezierCurve", ["math/wrap_BezierCurve.cpp"]],
	["RandomGenerator", ["math/wrap_RandomGenerator.cpp"]],
	["Transform", ["math/wrap_Transform.cpp"]],
	["Cursor", ["mouse/wrap_Cursor.cpp"]],
	["Decoder", ["sound/wrap_Decoder.cpp"]],
	["SoundData", ["sound/wrap_SoundData.cpp", "data/wrap_Data.cpp"]],
	["Channel", ["thread/wrap_Channel.cpp"]],
	["Thread", ["thread/wrap_LuaThread.cpp"]],
	["VideoStream", ["video/wrap_VideoStream.cpp"]],
]);

const intentionalModuleGaps = new Map([
	["Filesystem", new Set(["areSymlinksEnabled", "getCRequirePath", "setCRequirePath", "setSymlinksEnabled"])],
	["Window", new Set(["close", "maximize", "minimize", "requestAttention", "restore", "setIcon", "setPosition", "showMessageBox"])],
]);
const internalUpstreamModuleMethods = new Map([
	["Event", new Set(["poll_i"])],
	["Filesystem", new Set(["_setAndroidSaveExternal", "init", "setFused", "setSource"])],
	["ImageModule", new Set(["newCubeFaces"])],
	["MathModule", new Set(["_getRandomGenerator"])],
]);

let upstreamCoreMethodChecks = 0;
for (const [type, path] of upstreamModuleFiles) {
	const expected = upstreamMethods(path);
	for (const name of expected) if (name.startsWith("_")) expected.delete(name);
	for (const name of internalUpstreamModuleMethods.get(type) ?? []) expected.delete(name);
	const actual = runtimeModules.get(type);
	assert(actual, `runtime module registration ${type} was not found`);
	const missing = new Set([...expected].filter(name => !actual.has(name)));
	const allowed = intentionalModuleGaps.get(type) ?? new Set();
	assert([...missing].sort().join(",") === [...allowed].sort().join(","),
		`runtime ${type} Love 11.5 module gaps changed: missing=[${[...missing].sort().join(", ")}], expected=[${[...allowed].sort().join(", ")}]`);
	upstreamCoreMethodChecks += expected.size;
}

for (const [type, paths] of upstreamObjectFiles) {
	const expected = union(...paths.map(upstreamMethods));
	for (const name of expected) if (name.startsWith("_")) expected.delete(name);
	const actual = runtimeObjects.get(type);
	assert(actual, `runtime object registration ${type} was not found`);
	const missing = [...expected].filter(name => !actual.has(name)).sort();
	assert(missing.length === 0,
		`runtime ${type} is missing Love 11.5 wrapper methods: ${missing.join(", ")}`);
	upstreamCoreMethodChecks += expected.size;
}

function parseTypeScriptDeclarations(text, fileName) {
	const source = ts.createSourceFile(fileName, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
	const own = new Map();
	const bases = new Map();
	function visit(node) {
		if (ts.isInterfaceDeclaration(node)) {
			const name = node.name.text;
			if (!own.has(name)) own.set(name, new Set());
			for (const member of node.members) {
				if ((ts.isMethodSignature(member) || ts.isPropertySignature(member)) && member.name) {
					const value = member.name.getText(source).replace(/^['"]|['"]$/g, "");
					if (/^[A-Za-z_]\w*$/.test(value) && (ts.isMethodSignature(member)
						|| member.type && ts.isFunctionTypeNode(member.type))) own.get(name).add(value);
				}
			}
			bases.set(name, (node.heritageClauses ?? []).flatMap(clause =>
				clause.types.map(type => type.expression.getText(source))));
		}
		ts.forEachChild(node, visit);
	}
	visit(source);
	const flattened = new Map();
	function methods(name, visiting = new Set()) {
		if (flattened.has(name)) return flattened.get(name);
		assert(!visiting.has(name), `${fileName} has cyclic interface inheritance at ${name}`);
		visiting.add(name);
		const result = new Set(own.get(name) ?? []);
		for (const base of bases.get(name) ?? []) for (const method of methods(base, visiting)) result.add(method);
		visiting.delete(name);
		flattened.set(name, result);
		return result;
	}
	for (const name of own.keys()) methods(name);
	return flattened;
}

function parseTealDeclarations(text, fileName) {
	const records = new Map();
	const stack = [];
	for (const [lineNumber, line] of text.split(/\r?\n/).entries()) {
		const record = line.match(/^(\s*)(?:local\s+)?record\s+([A-Za-z_]\w*)\s*$/);
		if (record) {
			const indent = record[1].replace(/\t/g, "    ").length;
			stack.push({indent, name: record[2]});
			if (!records.has(record[2])) records.set(record[2], new Set());
			continue;
		}
		const end = line.match(/^(\s*)end\s*$/);
		if (end && stack.length) {
			const indent = end[1].replace(/\t/g, "    ").length;
			if (indent === stack.at(-1).indent) stack.pop();
			continue;
		}
		if (!stack.length) continue;
		const field = line.match(/^\s*([A-Za-z_]\w*):\s*function\b/);
		if (field) records.get(stack.at(-1).name).add(field[1]);
		if (/^\s*[^-\s]/.test(line) && line.includes(": function") && !field)
			throw new Error(`${fileName}:${lineNumber + 1} has an unparsed function field`);
	}
	return records;
}

function compareSurface(label, runtimeSurface, declarations, aliases = new Map()) {
	const failures = [];
	let methodCount = 0;
	for (const [runtimeName, runtimeMethods] of runtimeSurface) {
		const declarationNames = aliases.get(runtimeName) ?? [runtimeName];
		const declared = union(...declarationNames.map(name => declarations.get(name) ?? new Set()));
		assert(declarationNames.some(name => declarations.has(name)),
			`${label} is missing declaration record ${declarationNames.join(" or ")}`);
		methodCount += runtimeMethods.size;
		const missing = [...runtimeMethods].filter(name => !declared.has(name)).sort();
		const phantom = [...declared].filter(name => !runtimeMethods.has(name)).sort();
		if (missing.length || phantom.length) failures.push(
			`${runtimeName}: missing=[${missing.join(", ")}] phantom=[${phantom.join(", ")}]`);
	}
	assert(failures.length === 0, `${label} API parity failed:\n${failures.join("\n")}`);
	return methodCount;
}

const objectAliases = new Map([
	["Shape", ["Shape", "CircleShape", "PolygonShape", "EdgeShape", "ChainShape"]],
	["Joint", ["Joint", "DistanceJoint", "RevoluteJoint", "PrismaticJoint", "WeldJoint",
		"FrictionJoint", "RopeJoint", "PulleyJoint", "WheelJoint", "MouseJoint", "MotorJoint", "GearJoint"]],
]);

const declarationFiles = [
	["English TypeScript", "Assets/Script/Lib/Dora/en/love.d.ts", parseTypeScriptDeclarations],
	["Chinese TypeScript", "Assets/Script/Lib/Dora/zh-Hans/love.d.ts", parseTypeScriptDeclarations],
	["English Teal", "Assets/Script/Lib/Dora/en/love.d.tl", parseTealDeclarations],
	["Chinese Teal", "Assets/Script/Lib/Dora/zh-Hans/love.d.tl", parseTealDeclarations],
];

let checkedMethods = 0;
for (const [label, path, parser] of declarationFiles) {
	const text = readFileSync(nodePath.join(doraSSRRoot, path), "utf8");
	const declarations = parser(text, path);
	checkedMethods += compareSurface(`${label} modules`, runtimeModules, declarations);
	checkedMethods += compareSurface(`${label} objects`, runtimeObjects, declarations, objectAliases);
}

console.log(`PASS: Love 11.5 wrapper parity (${upstreamGraphicsMethodChecks} Graphics + ${upstreamCoreMethodChecks} core method checks); runtime API parity across English/Chinese TypeScript/Teal declarations (${checkedMethods} method checks)`);
