#!/usr/bin/env node

import process from "node:process";
import {fileURLToPath} from "node:url";

const baseUrl = (process.argv[2] ?? "http://127.0.0.1:8866").replace(/\/$/, "");
const fixtureRoot = fileURLToPath(new URL("./Fixtures/LanguageWorkflow", import.meta.url));

function assert(condition, message) {
	if (!condition) throw new Error(message);
}

async function post(path, body) {
	const response = await fetch(`${baseUrl}${path}`, {
		method: "POST",
		headers: {"Content-Type": "application/json"},
		body: JSON.stringify(body),
	});
	assert(response.ok, `${path} returned HTTP ${response.status}`);
	return response.json();
}

function hasSuggestion(response, name) {
	return response.success && response.suggestions?.some(([candidate]) => candidate === name);
}

for (const lang of ["tl", "lua"]) {
	const file = `${fixtureRoot}/love-service.${lang}`;
	const imported = 'local love = require("love")\n';

	const completion = await post("/complete", {
		lang,
		file,
		content: `${imported}love.graphics.`,
		line: "love.graphics.",
		row: 2,
	});
	assert(hasSuggestion(completion, "rectangle"), `${lang} Love completion did not include rectangle`);
	assert(hasSuggestion(completion, "getWidth"), `${lang} Love completion did not include getWidth`);
	assert(hasSuggestion(completion, "getSupported"), `${lang} Love completion did not include getSupported`);
	assert(hasSuggestion(completion, "getImageFormats"), `${lang} Love completion did not include getImageFormats`);
	assert(hasSuggestion(completion, "flushBatch"), `${lang} Love completion did not include flushBatch`);
	assert(hasSuggestion(completion, "setLineStyle"), `${lang} Love completion did not include setLineStyle`);
	assert(hasSuggestion(completion, "getLineJoin"), `${lang} Love completion did not include getLineJoin`);
	assert(hasSuggestion(completion, "setWireframe"), `${lang} Love completion did not include setWireframe`);
	assert(hasSuggestion(completion, "getStats"), `${lang} Love completion did not include getStats`);
	assert(hasSuggestion(completion, "newImageFont"), `${lang} Love completion did not include newImageFont`);
	assert(hasSuggestion(completion, "drawLayer"), `${lang} Love completion did not include drawLayer`);

	const fontCompletion = await post("/complete", {
		lang,
		file,
		content: `${imported}love.font.`,
		line: "love.font.",
		row: 2,
	});
	assert(hasSuggestion(fontCompletion, "newImageRasterizer"),
		`${lang} Love completion did not include newImageRasterizer`);
	assert(hasSuggestion(fontCompletion, "newBMFontRasterizer"),
		`${lang} Love completion did not include newBMFontRasterizer`);

	const audioCompletion = await post("/complete", {
		lang,
		file,
		content: `${imported}love.audio.`,
		line: "love.audio.",
		row: 2,
	});
	assert(hasSuggestion(audioCompletion, "setMixWithSystem"),
		`${lang} Love audio completion did not include setMixWithSystem`);

	const filesystemCompletion = await post("/complete", {
		lang,
		file,
		content: `${imported}love.filesystem.`,
		line: "love.filesystem.",
		row: 2,
	});
	assert(hasSuggestion(filesystemCompletion, "getExecutablePath"),
		`${lang} Love filesystem completion did not include getExecutablePath`);
	assert(hasSuggestion(filesystemCompletion, "exists")
		&& hasSuggestion(filesystemCompletion, "getSize"),
		`${lang} Love filesystem completion did not include deprecated compatibility queries`);
	const threadCompletion = await post("/complete", {
		lang,
		file,
		content: `${imported}love.thread.`,
		line: "love.thread.",
		row: 2,
	});
	assert(hasSuggestion(threadCompletion, "newThread") && hasSuggestion(threadCompletion, "getChannel"),
		`${lang} Love thread completion did not include newThread/getChannel`);
	const joystickCompletion = await post("/complete", {
		lang,
		file,
		content: `${imported}local pad = love.joystick.getJoysticks()[1]\npad:`,
		line: "pad:",
		row: 3,
	});
	assert(hasSuggestion(joystickCompletion, "setVibration"),
		`${lang} Love Joystick completion did not include setVibration`);
	assert(hasSuggestion(joystickCompletion, "getGamepadMapping"),
		`${lang} Love Joystick completion did not include getGamepadMapping`);
	assert(hasSuggestion(joystickCompletion, "release"),
		`${lang} Love Joystick completion did not include Object.release`);

	const inferred = await post("/infer", {
		lang,
		file,
		content: `${imported}local width = love.graphics.getWidth()\n`,
		line: "local width = love.graphics.getWidth()",
		row: 2,
	});
	assert(inferred.success, `${lang} Love inference failed`);
	assert(inferred.infered?.desc === "function(): number", `${lang} Love inference returned the wrong type`);
	assert(inferred.infered?.key?.endsWith("/love.d.tl"), `${lang} Love inference did not resolve love.d.tl`);

	const fontInferred = await post("/infer", {
		lang,
		file,
		content: `${imported}local rasterizer = love.font.newImageRasterizer\n`,
		line: "local rasterizer = love.font.newImageRasterizer",
		row: 2,
	});
	assert(fontInferred.success && fontInferred.infered?.desc?.includes("ImageData"),
		`${lang} Love font inference returned the wrong type`);

	const signature = await post("/signature", {
		lang,
		file,
		content: `${imported}love.graphics.rectangle("fill", 0, 0, 10, 10)\n`,
		line: 'love.graphics.rectangle("fill", 0, 0, 10, 10)',
		row: 2,
	});
	assert(signature.success, `${lang} Love signature lookup failed`);
	assert(signature.signatures?.[0]?.desc === "function(string, number, number, number, number)",
		`${lang} Love signature lost the compiler-provided function type`);

	const ordinaryFile = `${fixtureRoot}/ordinary-service.${lang}`;
	const ordinaryCompletion = await post("/complete", {
		lang,
		file: ordinaryFile,
		content: "local value = 1\nlove.graphics.",
		line: "love.graphics.",
		row: 2,
	});
	assert(!ordinaryCompletion.success, `${lang} completion leaked Love without require`);

	const ordinaryInference = await post("/infer", {
		lang,
		file: ordinaryFile,
		content: "local value = 1\nlocal width = love.graphics.getWidth()\n",
		line: "local width = love.graphics.getWidth()",
		row: 2,
	});
	assert(!ordinaryInference.success, `${lang} inference leaked Love without require`);

	const ordinarySignature = await post("/signature", {
		lang,
		file: ordinaryFile,
		content: 'local value = 1\nlove.graphics.rectangle("fill", 0, 0, 10, 10)\n',
		line: 'love.graphics.rectangle("fill", 0, 0, 10, 10)',
		row: 2,
	});
	assert(!ordinarySignature.success, `${lang} signature lookup leaked Love without require`);
}

for (const lang of ["tl", "lua"]) {
	const checked = await post("/check", {
		file: `${fixtureRoot}/love-service.${lang}`,
content: 'local love = require("love")\nlocal executable = love.filesystem.getExecutablePath()\nlocal legacy_exists = love.filesystem.exists("main.lua")\nlocal legacy_size, legacy_size_error = love.filesystem.getSize("main.lua")\nlocal atlas = love.image.newImageData(8, 2)\nlove.graphics.newImageFont(atlas, "A猫", 1, 2)\nlocal array_image = love.graphics.newArrayImage({atlas, atlas}, {mipmaps = false})\nlove.graphics.drawLayer(array_image, 2, 3, 4)\nlove.window.updateMode(640, 360)\nlove.graphics.getSupported()\nlove.graphics.getTextureTypes()\nlove.graphics.getImageFormats()\nlove.graphics.getRendererInfo()\nlove.graphics.getStats()\nlove.graphics.setLineStyle("rough")\nlove.graphics.setLineJoin("bevel")\nlove.graphics.discard({true, false}, true)\nlove.graphics.flushBatch()\nlove.audio.setMixWithSystem(true)\nlove.audio.setEffect("echo", {type = "echo", delay = 0.1})\nlocal source = love.audio.newSource("tone.wav", "static")\nsource:setFilter({type = "lowpass", highgain = 0.5})\nsource:setEffect("echo", {type = "lowpass", highgain = 0.5})\nlocal enabled, filter = source:getEffect("echo")\nlocal channel = love.thread.newChannel()\nlocal worker = love.thread.newThread("worker.lua")\nworker:start(channel)\nchannel:push("typed")\nlocal bytes = love.data.newByteData("typed")\nlocal is_data = bytes:typeOf("Data")\nlocal released = bytes:release()\nprint(executable, legacy_exists, legacy_size, legacy_size_error, enabled, filter, worker:isRunning(), channel:getCount(), is_data, released)\nlove.graphics.getWidth()\n',
	});
	assert(checked.success, `${lang} check did not resolve require(\"love\") through love.d.tl`);
}

const yueFile = `${fixtureRoot}/love-service.yue`;
const yueChecked = await post("/check", {
	file: yueFile,
	content: 'love = require "love"\nlove.filesystem.getExecutablePath!\nlove.graphics.getWidth!\n',
});
assert(yueChecked.success, "Yue check rejected a valid require(\"love\") program");

const yueCompletion = await post("/complete", {
	lang: "yue",
	file: yueFile,
	content: 'love = require "love"\nlove.graphics.',
	line: "love.graphics.",
	row: 2,
});
assert(hasSuggestion(yueCompletion, "rectangle") && hasSuggestion(yueCompletion, "getWidth"),
	"Yue Love completion did not resolve love.d.tl");

const yueFilesystemCompletion = await post("/complete", {
	lang: "yue",
	file: yueFile,
	content: 'love = require "love"\nlove.filesystem.',
	line: "love.filesystem.",
	row: 2,
});
assert(hasSuggestion(yueFilesystemCompletion, "getExecutablePath"),
	"Yue Love filesystem completion did not include getExecutablePath");
assert(hasSuggestion(yueFilesystemCompletion, "exists")
	&& hasSuggestion(yueFilesystemCompletion, "getSize"),
	"Yue Love filesystem completion did not include deprecated compatibility queries");

const yueInference = await post("/infer", {
	lang: "yue",
	file: yueFile,
	content: 'love = require "love"\nwidthGetter = love.graphics.getWidth\n',
	line: "widthGetter = love.graphics.getWidth",
	row: 2,
});
assert(yueInference.success && yueInference.infered?.desc === "function(): number" &&
	yueInference.infered?.key?.endsWith("/love.d.tl"),
	"Yue Love inference did not resolve the compiler type from love.d.tl");

const yueSignature = await post("/signature", {
	lang: "yue",
	file: yueFile,
	content: 'love = require "love"\nrectangle = love.graphics.rectangle\n',
	line: "rectangle = love.graphics.rectangle",
	row: 2,
});
assert(yueSignature.success &&
	yueSignature.signatures?.[0]?.desc === "function(string, number, number, number, number)",
	"Yue Love signature did not preserve the compiler-provided function type");

for (const [path, line, content] of [
	["/complete", "love.graphics.", "value = 1\nlove.graphics."],
	["/infer", "widthGetter = love.graphics.getWidth", "value = 1\nwidthGetter = love.graphics.getWidth\n"],
	["/signature", "rectangle = love.graphics.rectangle", "value = 1\nrectangle = love.graphics.rectangle\n"],
]) {
	const ordinary = await post(path, {
		lang: "yue",
		file: `${fixtureRoot}/ordinary-service.yue`,
		content,
		line,
		row: 2,
	});
	assert(!ordinary.success, `Yue ${path.slice(1)} leaked Love without require`);
}

const doraSignature = await post("/signature", {
	lang: "tl",
	file: `${fixtureRoot}/dora-signature.tl`,
	content: "local values = Dora.Array()\n",
	line: "local values = Dora.Array()",
	row: 1,
});
assert(doraSignature.success && doraSignature.signatures?.length === 2,
	"generic Teal signature wrapper lost Dora overloads");
assert(doraSignature.signatures[0].desc.includes("Array") && doraSignature.signatures[0].doc.length > 0,
	"generic Teal signature wrapper lost the compiler type or declaration docs");
assert(doraSignature.signatures[1].params?.some(({name}) => name.startsWith("items:")),
	"generic Teal signature wrapper lost documented parameters");

console.log("PASS: require-triggered Love Lua/Teal/Yue check, completion, inference, signature, and ordinary-file isolation");
