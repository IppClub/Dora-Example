#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {doraSourceRoot} from "./TestPaths.mjs";

const loveRoot = path.join(doraSourceRoot, "3rdParty/Love");

const expected = new Set([
	"DORA_SOURCE.md",
	"changes.txt",
	"license.txt",
	"readme.md",
	"xmake.lua",
	...[
		"Data.cpp", "Data.h", "Exception.cpp", "Exception.h", "Module.cpp", "Module.h",
		"Object.cpp", "Object.h", "Reference.cpp", "Reference.h", "Stream.cpp", "Stream.h",
		"StringMap.cpp", "StringMap.h", "config.h", "deprecation.cpp", "deprecation.h",
		"floattypes.cpp", "floattypes.h", "int.h", "runtime.cpp", "runtime.h", "types.cpp",
		"types.h",
	].map(file => `src/common/${file}`),
	...[
		"lz4.c", "lz4.h", "lz4hc.c", "lz4hc.h", "lz4opt.h",
	].map(file => `src/libraries/lz4/${file}`),
	...[
		"noise1234.cpp", "noise1234.h", "simplexnoise1234.cpp", "simplexnoise1234.h",
	].map(file => `src/libraries/noise1234/${file}`),
	"src/modules/audio/Filter.h",
	"src/modules/audio/Source.h",
	"src/modules/data/HashFunction.cpp",
	"src/modules/data/HashFunction.h",
	"src/modules/filesystem/File.cpp",
	"src/modules/filesystem/File.h",
	"src/modules/filesystem/FileData.cpp",
	"src/modules/filesystem/FileData.h",
	"src/modules/keyboard/Keyboard.cpp",
	"src/modules/keyboard/Keyboard.h",
	"src/modules/thread/Thread.h",
	"src/modules/thread/threads.cpp",
	"src/modules/thread/threads.h",
	"src/modules/video/VideoStream.cpp",
	"src/modules/video/VideoStream.h",
	"src/modules/video/theora/OggDemuxer.cpp",
	"src/modules/video/theora/OggDemuxer.h",
	"src/modules/video/theora/TheoraVideoStream.cpp",
	"src/modules/video/theora/TheoraVideoStream.h",
]);

for (const wrapper of [
	"audio/wrap_Audio.cpp", "audio/wrap_RecordingDevice.cpp", "audio/wrap_Source.cpp",
	"data/wrap_ByteData.cpp", "data/wrap_CompressedData.cpp", "data/wrap_Data.cpp",
	"data/wrap_DataModule.cpp", "data/wrap_DataView.cpp", "event/wrap_Event.cpp",
	"filesystem/wrap_File.cpp", "filesystem/wrap_FileData.cpp", "filesystem/wrap_Filesystem.cpp",
	"font/wrap_Font.cpp", "font/wrap_GlyphData.cpp", "font/wrap_Rasterizer.cpp",
	"image/wrap_CompressedImageData.cpp", "image/wrap_Image.cpp", "image/wrap_ImageData.cpp",
	"joystick/wrap_Joystick.cpp", "joystick/wrap_JoystickModule.cpp",
	"keyboard/wrap_Keyboard.cpp", "math/wrap_BezierCurve.cpp", "math/wrap_Math.cpp",
	"math/wrap_RandomGenerator.cpp", "math/wrap_Transform.cpp", "mouse/wrap_Cursor.cpp",
	"mouse/wrap_Mouse.cpp", "sound/wrap_Decoder.cpp", "sound/wrap_Sound.cpp",
	"sound/wrap_SoundData.cpp", "system/wrap_System.cpp", "thread/wrap_Channel.cpp",
	"thread/wrap_LuaThread.cpp", "thread/wrap_ThreadModule.cpp", "timer/wrap_Timer.cpp",
	"touch/wrap_Touch.cpp", "video/wrap_Video.cpp", "video/wrap_VideoStream.cpp",
	"window/wrap_Window.cpp",
]) expected.add(`src/modules/${wrapper}`);

for (const type of [
	"Canvas", "Font", "Graphics", "Image", "Mesh", "ParticleSystem", "Quad", "Shader",
	"SpriteBatch", "Text", "Texture", "Video",
]) expected.add(`src/modules/graphics/wrap_${type}.cpp`);

function collect(directory, prefix = "") {
	const result = [];
	for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
		if (entry.name === "Artifacts" || entry.name === "build" || entry.name === ".xmake")
			continue;
		const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
		const absolute = path.join(directory, entry.name);
		if (entry.isDirectory()) result.push(...collect(absolute, relative));
		else result.push(relative);
	}
	return result;
}

const actual = new Set(collect(loveRoot));
const missing = [...expected].filter(file => !actual.has(file)).sort();
const extra = [...actual].filter(file => !expected.has(file)).sort();
if (process.argv.includes("--prune")) {
	const license = path.join(loveRoot, "license.txt");
	if (!fs.existsSync(license) || !fs.readFileSync(license, "utf8").includes("LOVE Development Team"))
		throw new Error(`refusing to prune unexpected directory: ${loveRoot}`);
	if (missing.length)
		throw new Error(`refusing to prune an incomplete LOVE import:\n${missing.join("\n")}`);
	for (const file of extra) fs.rmSync(path.join(loveRoot, file));
	for (const directory of fs.readdirSync(loveRoot, {recursive: true, withFileTypes: true})
		.filter(entry => entry.isDirectory())
		.map(entry => path.join(entry.parentPath ?? entry.path, entry.name))
		.sort((a, b) => b.length - a.length)) {
		if (fs.existsSync(directory) && fs.readdirSync(directory).length === 0)
			fs.rmdirSync(directory);
	}
	console.log(`LOVE_UPSTREAM_SOURCE_PRUNE_PASS removed=${extra.length}`);
	process.exit(0);
}
if (missing.length || extra.length) {
	if (missing.length) console.error(`missing curated LOVE files:\n${missing.join("\n")}`);
	if (extra.length) console.error(`unexpected uncurated LOVE files:\n${extra.join("\n")}`);
	process.exit(1);
}

if ([...actual].some(file => file.includes("Box2D") || file.includes("modules/physics/"))) {
	throw new Error("LOVE Box2D/physics sources must not return to the curated Dora subset");
}

console.log(`LOVE_UPSTREAM_SOURCE_SUBSET_AUDIT_PASS files=${actual.size} runtime=57 wrappers=51 box2d=removed`);
